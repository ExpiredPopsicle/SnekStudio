#!/usr/bin/python3

import mediapipe
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import os
# this has to be set before cv2 is imported
# https://github.com/opencv/opencv/issues/17687
os.environ["OPENCV_VIDEOIO_MSMF_ENABLE_HW_TRANSFORMS"] = "0"

import cv2
import time
import json
import threading
import numpy

import kiri_math
# FIXME: Just use kiri_math.lerp everywhere instead of this.
from kiri_math import lerp

import socket
import sys

import psutil

import random
import argparse
import re
import gc

import traceback

class MediaPipeTracker:

    def __init__(self):

        self.the_big_ugly_mutex = threading.Lock()

        self._tracker_worker_thread = None

        # We need these to avoid deadlocks. If we're queueing frames
        # faster than they can process, we'll hit a deadlock in
        # MediaPipe.
        self.frames_queued_face = 0
        self.frames_queued_hands = 0
        self.frames_queued_mutex = threading.Lock()
        self.should_quit_threads = False

        # Open the socket immediately so we can start sending error
        # and status stuff to the hosting application.
        self._udp_socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

        # FIXME: Make this editable.
        self.minimum_frame_time = 0.016

        self.udp_port_number = 7098

        self.video_device_index = -1
        self.video_device_capture = None

        self.landmarker = None
        # self.landmarker_pose = None
        self.landmarker_hands = None

        last_hand_data_template = {
            "position" : numpy.array([0.0, 0.0, 0.0]),
            "rotation_matrix" : numpy.array([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]),
            "rotation_quat" : [0.0, 0.0, 0.0, 1.0],
            "position_confidence" : 0.0,
            "position_confidence_time" : 0.0,
            "landmarks" : []
        }

        self.last_hand_data = {
            "left" : last_hand_data_template.copy(),
            "right" : last_hand_data_template.copy()
        }

        # FIXME: Arrange into dictionary.
        self.last_head_position = numpy.array([0.0, 0.0, 0.0])
        self.last_head_quat = numpy.array([0.0, 0.0, 0.0, 1.0])

        # FIXME: Seed with values?
        self.last_blendshapes = {}

        self.time_since_last_face_detection = 10.0

        # These are for more deadlock avoidance, so we can keep track
        # of how behind the hand tracker is.
        self._last_hand_result_timestamp = (time.time() * 1000)
        self._last_hand_detect_timestamp = (time.time() * 1000)

        # Higher = takes longer to establish confidence, but takes
        # longer to start tracking. A bit better at filtering out
        # the bad stuff, though.
        # FIXME: Make settable.
        self.confidence_time_threshold = 1.0

        # Time to wait before registering hands after we detected that
        # the number of hands has changed.
        self.time_since_hand_count_changed_threshold = 1.0

        self.hand_position_scale = numpy.array([7.0, 7.0, 3.5])
        self.hand_position_offset = numpy.array([0.0, -0.14, 0.0])
        self.hand_to_head_scale = 2.0

    def _close_video_device(self):

        with self.the_big_ugly_mutex:
            self.video_device_capture = None

    def _open_video_device(self):

        with self.the_big_ugly_mutex:

            if self.video_device_index == -1:
                self.video_device_capture = None
                return

            # Check to make sure we don't already have the device open.
            if self.video_device_capture != None:
                return

            # Try opening it!
            self._write_log("Opening a video device!")

            self.video_device_capture = cv2.VideoCapture(int(self.video_device_index))

            # Enforce low-res capture for performance reasons.
            try:
                self.video_device_capture.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                self.video_device_capture.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            except Exception as e:
                # Failed? Whatever. Just use the resolution it's stuck with.
                pass

            if self.video_device_capture.isOpened():
                self._write_log("Video device acquired")
            else:
                self.video_device_capture = None
                error_string = "Failed to open video device: %s" % str(self.video_device_index)
                self._write_log(error_string)
                self._send_error_packet(error_string)

    def _init_mediapipe(self):

        BaseOptions = mediapipe.tasks.BaseOptions
        FaceLandmarker = mediapipe.tasks.vision.FaceLandmarker
        FaceLandmarkerOptions = mediapipe.tasks.vision.FaceLandmarkerOptions
        FaceLandmarkerResult = mediapipe.tasks.vision.FaceLandmarkerResult
        HandLandmarkerOptions = mediapipe.tasks.vision.HandLandmarkerOptions
        HandLandmarkerResult = mediapipe.tasks.vision.HandLandmarkerResult
        VisionRunningMode = mediapipe.tasks.vision.RunningMode

        asset_path = os.path.abspath(os.path.dirname(__file__))

        face_landmarker_path = os.path.join(asset_path, "face_landmarker.task")
        # FIXME: Last minute breakages.
        # pose_landmarker_path = os.path.join(asset_path, "pose_landmarker.task")
        hand_landmarker_path = os.path.join(asset_path, "hand_landmarker.task")

        options = mediapipe.tasks.vision.FaceLandmarkerOptions(
            base_options = BaseOptions(model_asset_path = face_landmarker_path),
            running_mode = VisionRunningMode.LIVE_STREAM,
            output_face_blendshapes = True,
            output_facial_transformation_matrixes = True,
            result_callback = self._handle_result_face)

        # FIXME: Last minute breakages.
        # options_pose = mediapipe.tasks.vision.PoseLandmarkerOptions(
        #     base_options = BaseOptions(model_asset_path = pose_landmarker_path),
        #     running_mode = VisionRunningMode.LIVE_STREAM,
        #     output_segmentation_masks = False,
        #     result_callback = self._handle_result_pose)

        options_hands = mediapipe.tasks.vision.HandLandmarkerOptions(
            base_options = BaseOptions(model_asset_path = hand_landmarker_path),
            running_mode = VisionRunningMode.LIVE_STREAM,
            num_hands = 2,

            # FIXME: Make these adjustable.
            # Were working in the 4.1 version.
            min_hand_detection_confidence = 0.75,
            min_tracking_confidence = 0.75,
            min_hand_presence_confidence = 0.9,

            result_callback = self._handle_result_hands)

        self._shutdown_mediapipe()

        self._write_log("Init face landmarker...")
        self.landmarker = FaceLandmarker.create_from_options(options)

        # self._write_log("Init pose landmarker...")
        # self.landmarker_pose = vision.PoseLandmarker.create_from_options(options_pose)

        self._write_log("Init hand landmarker...")
        self.landmarker_hands = vision.HandLandmarker.create_from_options(options_hands)

        self._write_log("Init done")

    def _write_log(self, *args):
        try:
            print(*args)
        except Exception as e:
            # Concerning...
            pass
        try:
            self._send_status_packet(" ".join(str(s) for s in args))
        except Exception as e:
            pass

    def _send_status_packet(self, status_str):

        output_data = {
            "status" : status_str
        };
        output_data_json = json.dumps(output_data, indent=4).encode("utf-8")
        self._udp_socket.sendto(output_data_json, ("127.0.0.1", self.udp_port_number))

    def _send_error_packet(self, error_string):

        output_data = {
            "error" : error_string
        };
        output_data_json = json.dumps(output_data, indent=4).encode("utf-8")
        self._udp_socket.sendto(output_data_json, ("127.0.0.1", self.udp_port_number))

    # Create a face landmarker instance with the live stream mode:
    def _handle_result_face(
            self,
            result: mediapipe.tasks.vision.FaceLandmarkerResult,
            output_image: mediapipe.Image, timestamp_ms: int):

        for transform in result.facial_transformation_matrixes:
            self.time_since_last_face_detection = 0.0
            self.last_head_position = kiri_math.get_origin_from_mediapipe_transform_matrix(transform) / 100.0
            self.last_head_quat = kiri_math.quaternion_mirror_rotation_on_x_axis(
                kiri_math.matrix_to_quaternion(transform))

        for face in result.face_blendshapes:
            self.time_since_last_face_detection = 0.0
            for shape in face:

                # FIXME: Make this scaling value configurable. And
                # move it into Godot.
                self.last_blendshapes[shape.category_name] = shape.score # normalized

        with self.frames_queued_mutex:
            self.frames_queued_face -= 1

    # FIXME: If we ever come back to it, finish this.
    def _handle_result_pose(
            self,
            x, output_image: mediapipe.Image, timestamp_ms: int):
        for y in x.pose_world_landmarks:
            pass

    def _handle_result_hands(
            self,
            result: mediapipe.tasks.vision.HandLandmarkerResult,
            output_image: mediapipe.Image, timestamp_ms: int):

        self._last_hand_result_timestamp = timestamp_ms
        # self._write_log("HAND RESULTS: ", timestamp_ms)
        # return

        with self.frames_queued_mutex:
            self.frames_queued_hands -= 1

        # Check if hand count changed. Pause tracking for a moment if we
        # did.
        if self.last_hand_count != len(result.hand_landmarks):
            self.last_hand_count = len(result.hand_landmarks)
            self.time_since_hand_count_changed = 0.0
            self._write_log("Hand count changed.")
        else:
            self.time_since_hand_count_changed += 1.0
        if self.time_since_hand_count_changed < self.time_since_hand_count_changed_threshold:
            self._write_log("Waiting on hand count change.")
            return

        # Default confidence to zero in case we don't see any hand
        # tracking data for a hand.
        self.last_hand_data["right"]["position_confidence"] = 0.0
        self.last_hand_data["left"]["position_confidence"] = 0.0

        assert(
            len(result.hand_landmarks) == len(result.hand_world_landmarks) and
            len(result.hand_landmarks) == len(result.hand_landmarks))

        hands_seen = {
            "left" : False,
            "right" : False
        }

        for index in range(0, len(result.hand_landmarks)):

            hand_landmarks = result.hand_landmarks[index]
            hand_world_landmarks = result.hand_world_landmarks[index]
            handedness = result.handedness[index]

            vec_middle_of_knuckles = (
                kiri_math.landmark_to_vector(result.hand_world_landmarks[index][5]) + \
                kiri_math.landmark_to_vector(result.hand_world_landmarks[index][17])) / 2.0

            # This is really the hand "forward".
            vec_wrist_to_knuckles = \
                vec_middle_of_knuckles - \
                kiri_math.landmark_to_vector(result.hand_world_landmarks[index][0])
            vec_wrist_to_knuckles = \
                vec_wrist_to_knuckles / numpy.linalg.norm(vec_wrist_to_knuckles)

            # Direction of the knuckles (outer side towards thumb side)
            vec_knuckles_direction = \
                kiri_math.landmark_to_vector(result.hand_world_landmarks[index][5]) - \
                kiri_math.landmark_to_vector(result.hand_world_landmarks[index][17])
            vec_knuckles_direction = \
                vec_knuckles_direction / numpy.linalg.norm(vec_knuckles_direction)

            vec_up = numpy.cross(
                vec_wrist_to_knuckles,
                vec_knuckles_direction)

            vec_towards_thumb = numpy.cross(
                vec_wrist_to_knuckles,
                vec_up)

            # vec_wrist_to_knuckles = +x or -x, depending on hand
            # vec_up = +y
            # vec_towards_thumb = +z


            # ----------------------------------------------------------------------

            # TODO: Lerp hands back to rest position when not visible.
            #   Why? Because the last tracked position of a hand we
            #   haven't seen in a while is confusing our fallback
            #   left/right hand detection.

            # Get viewspace origin.
            hand_viewspace_origin = kiri_math.get_hand_viewspace_origin(
                hand_landmarks,
                hand_world_landmarks,
                #9/5) # FIXME: Hardcoded value. Add calibration.
                self.hand_to_head_scale,
                self.hand_position_scale,
                self.hand_position_offset)

            # Decide handedness
            handedness_decided = ""
            if len(handedness) > 0:

                if len(handedness) > 1:
                    assert(handedness[0].score > handedness[1].score)

                # FIXME: Hands appear to be swapped. That is, it's the
                # *camera's* right and left.

                # FIXME: Make this configurable!
                min_confidence_threshold = 0.85 #0.98: # Was .85

                if handedness[0].score >= min_confidence_threshold:

                    # Trust the handedness from the API.
                    if handedness[0].category_name == "Right":
                        handedness_decided = "right"

                    elif handedness[0].category_name == "Left":
                        handedness_decided = "left"

                    if len(handedness_decided):
                        # FIXME: Use actual time? Maybe frame counting is better.
                        self.last_hand_data[handedness_decided.lower()]["position_confidence_time"] += handedness[0].score

                else:

                    # Just reset confidence for whatever we think
                    # there's a chance that this is.
                    self.last_hand_data[handedness[0].category_name.lower()][
                        "position_confidence_time"] = 0.0

                    if self.debug_try_closest_hand_when_confidence_low:
                        # Don't trust the handedness from the API. Instead
                        # just find which hand was closest last frame.
                        if numpy.linalg.norm(self.last_hand_data["left"]["position"] - hand_viewspace_origin) < \
                           numpy.linalg.norm(self.last_hand_data["right"]["position"] - hand_viewspace_origin):
                            handedness_decided = "left"
                        else:
                            handedness_decided = "right"

            hands_seen[handedness_decided] = True

            # Flip some axes for different hands, because the thumb is
            # facing the opposite direction on the left hand, but we
            # still need the same coordinate space as the right hand.
            #
            # We're really just using vec_towards_thumb as a kind of
            # horizontal axis for the rotation matrixm, anyway.
            vec_horizontal = vec_towards_thumb
            if len(handedness) > 0 and handedness_decided == "left":
                vec_horizontal *= -1

            # General coordinate space wiggling.
            vec_up *= -1

            # Generate a hand rotation matrix.
            mat_hand_rotation = numpy.array([
                vec_wrist_to_knuckles  / numpy.linalg.norm(vec_wrist_to_knuckles),
                vec_up                 / numpy.linalg.norm(vec_up),
                vec_horizontal         / numpy.linalg.norm(vec_horizontal)
                ])

            # Convert all landmarks to hand-local space and add them to
            # the output list.
            wrist_position_local = \
                kiri_math.landmark_to_vector(result.hand_world_landmarks[index][0])
            output_hand_landmarks = []
            for i in range(0, len(result.hand_world_landmarks[index])):
                local_pos = (kiri_math.landmark_to_vector(result.hand_world_landmarks[index][i]) -
                         wrist_position_local)
                output_hand_landmarks.append(
                    mat_hand_rotation.dot(local_pos))

            # Set outputs.
            if len(handedness) > 0:

                # FIXME: Make settable.
                smoothness = 1.0

                if len(handedness_decided):

                    hand_to_change = self.last_hand_data[handedness_decided]
                    if hand_to_change["position_confidence_time"] >= self.confidence_time_threshold:

                        # # FIXME: Re-enable this, but make it settable how much effect it has.
                        # # Smooth out the depth value to reduce noise.
                        # last_hand_position_smooth_z = \
                        #     self.last_hand_data["right"]["position"][2] * 0.8 + hand_viewspace_origin[2] * 0.2
                        # hand_viewspace_origin[2] = last_hand_position_smooth_z

                        hand_to_change["position"] = \
                            lerp(
                                hand_viewspace_origin,
                                hand_to_change["position"],
                                handedness[0].score / smoothness)

                        hand_to_change["position"] = hand_viewspace_origin

                        hand_to_change["position_confidence"] = handedness[0].score
                        hand_to_change["rotation_matrix"] = mat_hand_rotation
                        hand_to_change["landmarks"] = output_hand_landmarks

        # Reset any hand that we haven't seen this frame.
        for hand in hands_seen.keys():
            if not hands_seen[hand]:
                self.last_hand_data[hand]["position_confidence_time"] = 0.0

    def _tracker_worker_thread_func(self):

        try:


            # Deadlock-avoidance.

            self._write_log("locking mutex before init mediapipe")
            with self.the_big_ugly_mutex:

                self._init_mediapipe()

                self._write_log("Initializing MediaPipe")

                # Re-init hand tracking data every time we restart the
                # tracker.
                for side in ["left", "right"]:
                    self.last_hand_data[side]["position"]             = numpy.array([0.0, 0.0, 0.0])
                    self.last_hand_data[side]["position_confidence"]  = 0.0
                    self.last_hand_data[side]["rotation_matrix"]      = numpy.array([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]])
                    self.last_hand_data[side]["landmarks"]            = []

                # We'll pause tracking if another hand has come on-screen, because it
                # can get confused between the two of them when one has the wrong
                # handedness (but we can't easily distinguish it yet from the one that's
                # already on-screen). FIXME: Do it with a distance-check?
                self.time_since_hand_count_changed = 0.0

                self.last_hand_count = 0

                self.debug_try_closest_hand_when_confidence_low = False

            input_image = None
            success = True
            start_time = time.time()
            frame_count = 0

            # We'll send this when we're panicking from too many frames queued, as
            # a last-ditch attempt to un-clog the queue before we get a deadlock
            # thanks to the MediaPipe bug.
            blank_image_cv2 = numpy.zeros((1,1,3), dtype=numpy.uint8)
            blank_image_mp = mediapipe.Image(
                mediapipe.ImageFormat.SRGB,
                data=blank_image_cv2)

            # Main capturing loop.
            last_frame_time = 0
            while not self.should_quit_threads:

                # Wait for the minimum frame time.
                time_to_sleep = self.minimum_frame_time - (time.time() - last_frame_time)
                if time_to_sleep > 0.0:
                    time.sleep(time_to_sleep)

                # If the video device got disconnected, reconnect it.
                try:
                    self._open_video_device()
                except Exception as e:
                    # We're going to ignore failures to open the
                    # device on this thread, so the thread keeps
                    # going, and the hosting application can still
                    # switch it on the main thread.
                    pass

                with self.the_big_ugly_mutex:

                    last_frame_time = time.time()
                    last_timestamp_used = int(time.time() * 1000)

                    # Capture a frame.
                    if self.video_device_capture:
                        success, image = self.video_device_capture.read()
                    else:
                        # No camera connected at the moment. Just feed in
                        # blank images.
                        success = True
                        image = blank_image_cv2.copy()

                    if success:

                        # Convert image to MediaPipe.
                        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
                        # FIXME: Find out why we do this. I think it was
                        # mentioned in the MediaPipe tutorial.
                        image.flags.writeable = False
                        mp_image = mediapipe.Image(
                            image_format=mediapipe.ImageFormat.SRGB,
                            data=image)

                        # Generate a timestamp to feed into the MediaPipe
                        # system. If we're still somehow inside the same
                        # millisecond as the last processed image, then skip
                        # this frame.
                        this_time = int(time.time() * 1000)
                        if this_time <= last_timestamp_used:
                            continue

                        # Check to see if we have too many face tracking
                        # frames queued.
                        need_reset = False
                        with self.frames_queued_mutex:
                            if self.frames_queued_face > 5:
                                need_reset = True
                            else:
                                self.frames_queued_face += 1

                        # This will get reset immediately if we detect
                        # a face. Otherwise it'll be how many frames
                        # since the last face detection.
                        self.time_since_last_face_detection += 1.0

                        # Reset if we have too face frames queued. Avoid a
                        # deadlock.
                        if need_reset:
                            # Deadlock-avoidance.
                            self.landmarker._runner.restart()
                            self.frames_queued_face = 0
                        else:
                            self.landmarker.detect_async(mp_image, this_time)

                        # Hands

                        # If the last result we got back was too much time
                        # since the last one we queued up, then wait until
                        # some amount of time (which we guess in the most
                        # convoluted way possible) has passed.
                        #
                        # FIXME: Make this less stupid. Make it make
                        # sense. Then apply it to the face tracking.
                        hand_landmarker_time_skew = self._last_hand_detect_timestamp - self._last_hand_result_timestamp
                        if hand_landmarker_time_skew > 50: # FIXME: Make configurable (milliseconds)
                            self._last_hand_result_timestamp += this_time - self._last_hand_detect_timestamp
                        else:
                            # Check to see if we have too many hand tracking
                            # frames queued.
                            need_reset = False
                            with self.frames_queued_mutex:
                                if self.frames_queued_face > 5:
                                    need_reset = True
                                else:
                                    self.frames_queued_hands += 1

                            # If we do have too many frames queued, just reset
                            # the tracker to avoid a deadlock.
                            if need_reset:
                                self.landmarker_hands._runner.restart()
                                self.frames_queued_hands = 0
                            else:
                                self.landmarker_hands.detect_async(mp_image, this_time)
                                self._last_hand_detect_timestamp = this_time

                        # Track the last timestamp because we have to keep
                        # these monotonically increasing and we can't send
                        # the same timestamp twice.
                        last_timestamp_used = this_time

                        # Generate the dictionary we're going to send back
                        # to SnekStudio.
                        output_data = {
                            "hand_left_origin" :
                                self.last_hand_data["left"]["position"].tolist(),
                            "hand_left_rotation" :
                                self.last_hand_data["left"]["rotation_matrix"].tolist(),
                            "hand_left_score" :
                                self.last_hand_data["left"]["position_confidence"],
                            "hand_right_origin" :
                                self.last_hand_data["right"]["position"].tolist(),
                            "hand_right_rotation" :
                                self.last_hand_data["right"]["rotation_matrix"].tolist(),
                            "hand_right_score" :
                                self.last_hand_data["right"]["position_confidence"],
                            "head_origin" :
                                self.last_head_position.tolist(),
                            "head_quat" :
                                self.last_head_quat.tolist(),
                            "blendshapes" : self.last_blendshapes,
                            "head_missing_time" : self.time_since_last_face_detection
                        }

                        output_landmarks_left = []
                        for k in self.last_hand_data["left"]["landmarks"]:
                            output_landmarks_left.append(k.tolist())

                        output_landmarks_right = []
                        for k in self.last_hand_data["right"]["landmarks"]:
                            output_landmarks_right.append(k.tolist())

                        output_data["hand_landmarks_left"] = output_landmarks_left
                        output_data["hand_landmarks_right"] = output_landmarks_right

                        output_data_json = json.dumps(output_data, indent=4).encode("utf-8")

                        with self.frames_queued_mutex:
                            status_packet_str = "Tracking data sending. (Queue: %2d hand, %2d face)" % (self.frames_queued_hands, self.frames_queued_face)

                        # FIXME: This is too spammy.
                        # self._write_log(status_packet_str)

                        # Output the packet.
                        if self.video_device_capture:
                            self._udp_socket.sendto(output_data_json, ("127.0.0.1", self.udp_port_number))

            self._write_log("Quitting")

        except Exception as e:

            exception_string_generator = traceback.TracebackException.from_exception(e)
            exception_string = "".join(exception_string_generator.format())
            self._write_log(exception_string)

    def start_tracker(self):

        if self._tracker_worker_thread:
            stop_tracker()

        assert(not self._tracker_worker_thread)
        self._write_log("Starting worker thread.")
        self._tracker_worker_thread = threading.Thread(
            target=self._tracker_worker_thread_func,
            daemon=True)
        self._tracker_worker_thread.start()
        self._write_log("Starting worker thread done.")

    def stop_tracker(self):

        assert(self._tracker_worker_thread)
        self.should_quit_threads = True
        self._write_log("Waiting for worker thread to join.")
        self._tracker_worker_thread.join()
        self._write_log("Worker thread joined.")
        self._tracker_worker_thread = None
        self.should_quit_threads = False


    # Set to -1 to just release all devices.
    #
    # FIXME: Merge into update_settings.
    def set_video_device_number(self, new_number):

        if self.video_device_index != new_number:
            with self.the_big_ugly_mutex:
                self.video_device_index = new_number
            self._close_video_device()
            self._open_video_device()

    # FIXME: Merge into update_settings.
    def set_udp_port_number(self, new_number):
        with self.the_big_ugly_mutex:
            self.udp_port_number = new_number

    # FIXME: Merge into update_settings.
    def set_hand_confidence_time_threshold(self, new_number):
        with self.the_big_ugly_mutex:
            self.confidence_time_threshold = new_number

    # FIXME: Merge into update_settings.
    def set_hand_count_change_time_threshold(self, new_number):
        with self.the_big_ugly_mutex:
            self.time_since_hand_count_changed_threshold = new_number

    def update_settings(self, new_settings_dict):

        if "hand_position_scale" in new_settings_dict:
            self.hand_position_scale = new_settings_dict["hand_position_scale"]
        if "hand_position_offset" in new_settings_dict:
            self.hand_position_offset = new_settings_dict["hand_position_offset"]
        if "hand_to_head_scale" in new_settings_dict:
            self.hand_to_head_scale = new_settings_dict["hand_to_head_scale"]

    def _shutdown_mediapipe(self):

        if self.landmarker:
            self.landmarker.close()
        # if self.landmarker_pose:
        #     self.landmarker_pose.close()
        if self.landmarker_hands:
            self.landmarker_hands.close()

        self.landmarker = None
        # self.landmarker_pose = None
        self.landmarker_hands = None

        # Grumblegrumblegrumble...
        gc.collect()

    def __del__(self):
        with self.the_big_ugly_mutex:
            self._close_video_device()
            self._shutdown_mediapipe()




# ----------------------------------------------------------------------
mediapipe_controller =  MediaPipeTracker()


# ----------------------------------------------------------------------
# External interface (called from Godot)

def start_tracker():
    global mediapipe_controller
    mediapipe_controller.start_tracker()

def stop_tracker():
    global mediapipe_controller
    mediapipe_controller.stop_tracker()

# Set to -1 to just release all devices.
#
# FIXME: Merge into update_settings.
def set_video_device_number(new_number):
    global mediapipe_controller
    mediapipe_controller.set_video_device_number(new_number)

# FIXME: Merge into update_settings.
def set_udp_port_number(new_number):
    global mediapipe_controller
    mediapipe_controller.set_udp_port_number(new_number)

# FIXME: Merge into update_settings.
def set_hand_confidence_time_threshold(new_number):
    global mediapipe_controller
    mediapipe_controller.set_hand_confidence_time_threshold(new_number)

# FIXME: Merge into update_settings.
def set_hand_count_change_time_threshold(new_number):
    global mediapipe_controller
    mediapipe_controller.set_hand_count_change_time_threshold(new_number)

def update_settings(new_settings_dict):
    global mediapipe_controller
    mediapipe_controller.update_settings(new_settings_dict)


def enumerate_camera_devices():

    from cv2_enumerate_cameras import enumerate_cameras

    capture_api_preference=cv2.CAP_ANY

    # Having issues with GSTREAMER sources, so let's just use V4L only.
    if sys.platform == "linux":
        capture_api_preference = cv2.CAP_V4L2

    # CAP_ANY provides a Direct Show(DSHOW) backend and a Media Foundation(MSMF) backend
    # MSMF is more modern and DSHOW maybe removed in any future version of windows so filter by MSMF
    if sys.platform == "win32":
        capture_api_preference = cv2.CAP_MSMF

    # On Linux, we sometimes see stuff showing up as just "video#", so
    # let's at least try to correlate paths and IDs from
    # /dev/v4l/by-id .
    path_to_name_mappings = {}
    if sys.platform == "linux":
        try:
            device_id_list = os.listdir("/dev/v4l/by-id")
            for device_id in device_id_list:
                full_link_path = os.path.join("/dev/v4l/by-id", device_id)
                actual_dev_file = os.path.abspath(os.path.join("/dev/v4l/by-id", os.readlink(full_link_path)))
                path_to_name_mappings[actual_dev_file] = device_id
        except IOError:
            pass

    all_camera_data = []
    cameras = enumerate_cameras(apiPreference=capture_api_preference)
    if sys.platform == "win32" and len(cameras) == 0:
        capture_api_preference = cv2.CAP_DSHOW
        cameras = enumerate_cameras(apiPreference=capture_api_preference)
    for camera_info in cameras:
        camera_name = camera_info.name

        if re.match("video[0-9]+", camera_info.name):
            if camera_info.path in path_to_name_mappings:
                camera_name = path_to_name_mappings[camera_info.path]

        # Figure out the backend.
        backend_index = camera_info.backend
        if sys.platform == "linux":
            # For some reason, in Linux the backend is stored in the
            # index and not the backend field.
            backend_index = camera_info.index - (camera_info.index % 100)
        backend_name = cv2.videoio_registry.getBackendName(backend_index)

        camera_data = {
            "name" : camera_name,
            "backend" : backend_name,
            "path" : camera_info.path,
            "index" : camera_info.index
        }

        if sys.platform == "linux":
            from linuxpy.video.device import Device, VideoCapture

            cap = cv2.VideoCapture(camera_info.index, capture_api_preference)
            works = False
            if cap.isOpened():
                ret, frame = cap.read()
                if ret and frame is not None:
                    works = True
            else:
                with Device(camera_info.path) as camera:
                    try:
                        for frame in camera:
                            pass
                    except OSError as e:
                        if e.errno == 16:
                            works = True
            cap.release()
            if works:
                all_camera_data.append(camera_data)
        else:
            all_camera_data.append(camera_data)

    return all_camera_data
