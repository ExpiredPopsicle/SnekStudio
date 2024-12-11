#!/usr/bin/python3

import numpy
import math
import cv2

def make_frustum_matrix(left, right, bottom, top, near, far):

    mat = [

        # x_out =
        #   x_in * (2.0 * near) / (right - left) +
        #   z_in * (right + left) / (right - left)
        [(2.0 * near) / (right - left),
         0.0,
         (right + left) / (right - left),
         0.0],

        # y_out =
        #   y_in * (2.0 * near) / (top - bottom),
        #   z_in * (top + bottom) / (top - bottom)
        [0.0,
         (2.0 * near) / (top - bottom),
         (top + bottom) / (top - bottom),
         0.0],

        # z_out =
        #   z_in * -(far + near) / (far - near)
        #   1.0 * -(2.0 * far * near) / (far - near) # just an offset)
        [0.0,
         0.0,
         -(far + near) / (far - near),
         -(2.0 * far * near) / (far - near)],

        # w_out = -z_in
        [0.0,
         0.0,
         -1.0,
         0.0]
    ]

    return numpy.array(mat)

def make_rotation_matrix(axis, angle):
    pass
    # TODO

def xform(matrix, vec):
    vec_with_w = vec

    if vec.size == 3:
        vec_with_w = (vec[0], vec[1], vec[2], 1.0)
    elif vec_size == 4:
        vec_with_w = vec
    else:
        assert(0)

    out = matrix.dot(vec_with_w)

    if vec.size == 3:
        out = numpy.array(out[0:3]) / out[3]

    return out


def quaternion_to_matrix(quat):

    qx = quat[0]
    qy = quat[1]
    qz = quat[2]
    qw = quat[3]
    qx2 = qx * qx
    qy2 = qy * qy
    qz2 = qz * qz

    return numpy.array(
        ((
            (1.0 - 2.0 * qy2     - 2.0 * qz2),
            (      2.0 * qx * qy - 2.0 * qz * qw),
            (      2.0 * qx * qz + 2.0 * qy * qw)
        ), (
            (      2.0 * qx * qy + 2.0 * qz * qw),
            (1.0 - 2.0 * qx2     - 2.0 * qz2),
            (      2.0 * qy * qz - 2.0 * qx * qw),
        ), (
            (      2.0 * qx * qz - 2.0 * qy * qw),
            (      2.0 * qy * qz + 2.0 * qx * qw),
            (1.0 - 2.0 * qx2     - 2.0 * qy2)
        )))

def matrix_to_quaternion(mat):

    k = 1.0 - mat[0][0] + mat[1][1] + mat[2][2]
    if k <= 0.0:
        return numpy.array([0.0, 0.0, 0.0, 1.0])
    w = math.sqrt(k)
    w4 = 4.0 * w
    x = (mat[2][1] - mat[1][2]) / w4
    y = (mat[0][2] - mat[2][0]) / w4
    z = (mat[1][0] - mat[0][1]) / w4

    return numpy.array([x, y, z, w])

def quaternion_to_euler(q):

    # roll (x-axis rotation)
    sinr_cosp = 2.0 * (q[3] * q[0] + q[1] * q[2])
    cosr_cosp = 1.0 - 2.0 * (q[0] * q[0] + q[1] * q[1])

    pitch = math.atan2(sinr_cosp, cosr_cosp)

    # pitch (y-axis rotation)
    sinp = 2.0 * (q[3] * q[1] - q[2] * q[0])
    if abs(sinp) >= 1.0:
        yaw = math.copysign(M_PI / 2, sinp) # use 90 degrees if out of range
    else:
        yaw = math.asin(sinp)

    # yaw (z-axis rotation)
    siny_cosp = 2.0 * (q[3] * q[2] + q[0] * q[1])
    cosy_cosp = 1.0 - 2.0 * (q[1] * q[1] + q[2] * q[2])
    roll = math.atan2(siny_cosp, cosy_cosp)

    return (pitch, yaw, roll)

def quaternion_invert(x):
    return (x[0], x[1], x[2], -x[3])

def euler_to_quaternion(e):

    yaw   = e[2]
    pitch = e[1]
    roll  = e[0]

    cy = math.cos(yaw * 0.5);
    sy = math.sin(yaw * 0.5);
    cp = math.cos(pitch * 0.5);
    sp = math.sin(pitch * 0.5);
    cr = math.cos(roll * 0.5);
    sr = math.sin(roll * 0.5);

    q = numpy.array((
        sr * cp * cy - cr * sp * sy,
        cr * sp * cy + sr * cp * sy,
        cr * cp * sy - sr * sp * cy,
        cr * cp * cy + sr * sp * sy))

    return q;


# ----------------------------------------------------------------------
# Vector/Matrix/Transform conversions

camera_aspect_ratio = 4.0/3.0 # Logitech C920 default?

def ndc_to_viewspace(v, z_offset):

    # This (px, py) is pretty important and Google's
    # documentation didn't give much useful info about it.
    px = 0.5
    py = 0.5

    # These default to 1.0, 1.0 according to Google's docs. I
    # guess that's probably fine for default camera stuff.
    # fx = 1394.6027293299926
    # fy = 1394.6027293299926
    fx = 1.0
    fy = camera_aspect_ratio

    # Inverse equation from the section on NDC space here
    # https://google.github.io/mediapipe/solutions/objectron.html#coordinate-systems
    # https://web.archive.org/web/20220727063132/https://google.github.io/mediapipe/solutions/objectron.html#coordinate-systems
    # which describes going from camera coordinates to NDC
    # space. It's kinda ambiguous on terms, but this seems to
    # work to get view space coordinates.
    #
    # With this, coordinates seem to be evenly scaled (between
    # x/y and z) and in view space.
    #
    # Note: Some input axes were negated when we were making the
    # handedness consistent among all our math. -Kiri 2023-10-21
    z_scale = 1.0
    viewspace = numpy.array([0.0, 0.0, 0.0])
    viewspace[2] = 1.0 / (-v[2] + (1.0/z_offset) * z_scale)
    viewspace[0] = (v[0] - px) * viewspace[2] / fx
    viewspace[1] = (-v[1] - py) * viewspace[2] / fy

    return viewspace

def landmark_to_vector(landmark):
    return numpy.array((landmark.x, -landmark.y, -landmark.z))

def landmark_to_vector_old(landmark):
    return numpy.array((landmark.x, landmark.y, landmark.z))

# Figure out a depth value based on the distance between known
# normalized (clip-space) coordinates of landmarks, compared to what
# we would expect the average distance between those points to be.
def guess_depth_from_known_distance(landmarks, landmarks_world, index0, index1, distance):

    left_point_landmark = landmarks[index0]
    left_point = landmark_to_vector(left_point_landmark)

    right_point_landmark = landmarks[index1]
    right_point = landmark_to_vector(right_point_landmark)

    left_right_dist_clip = numpy.linalg.norm(
        numpy.array(
            (
                (left_point[0] - right_point[0]) * camera_aspect_ratio,
                (left_point[1] - right_point[1]),
                (left_point[2] - right_point[2]) # FIXME: Fudge factor
            )
        )
    )

    scale = left_right_dist_clip / distance

    return 1.0 / scale

# Attempt to figure out the hand origin in viewspace.
#
# hand_to_head_scale is a fudge value so that we can attempt to force
# the hand and head into the same scale range, roughly.
#
def get_hand_viewspace_origin(
        landmarks,
        world_landmarks,
        hand_to_head_scale=1.0,
        position_scale=numpy.array([7.0, 7.0, 3.5]),
        position_offset=numpy.array([0.0, -0.14, 0.0])):

    # Determine a fake Z by taking the average of three separate
    # measurements, to try to get the most accurate (or at least less
    # noisy) measurement we can.

    # See here for what the hard-coded point indices correspond to:
    # https://developers.google.com/mediapipe/solutions/vision/hand_landmarker


    # Table of known distances. Format is:
    #
    # [
    #   [ point_index1, point_index2, distance],
    #   ...
    # ]
    #
    # Distance is in meters. Probably some slack in the distance
    # values, because they effectively just become a weighted average
    # scaling value.
    #

    # # Old guessed distances.
    #
    # known_distances = \
    #     [ \
    #       # Wrist to tip of thumb.
    #       [  0,  1, 0.025 ],
    #       [  1,  2, 0.020 ],
    #       [  2,  3, 0.020 ],
    #       [  3,  4, 0.020 ],
    #       # Wrist to knuckles.
    #       [  0,  5, 0.089 ],
    #       [  0, 17, 0.076 ],
    #       # Knuckles to other knuckles.
    #       [  5,  9, 0.015 ],
    #       [  9, 13, 0.015 ],
    #       [ 13, 17, 0.015 ],
    #       # Index finger.
    #       [  5,  6, 0.015 ],
    #       [  6,  7, 0.015 ],
    #       [  7,  8, 0.015 ],
    #       # Middle finger.
    #       [  9, 10, 0.015 ],
    #       [ 10, 11, 0.015 ],
    #       [ 11, 12, 0.015 ],
    #       # Ring finger.
    #       [ 13, 14, 0.015 ],
    #       [ 14, 15, 0.015 ],
    #       [ 15, 16, 0.015 ],
    #       # Little finger.
    #       [ 17, 18, 0.012 ],
    #       [ 18, 19, 0.012 ],
    #       [ 19, 20, 0.012 ]
    #     ]

    # Values found through experimentation instead.
    known_distances = \
        [ \
          [ 0,  1, 0.053861],
          [ 1,  2, 0.057096],
          [ 2,  3, 0.048795],
          [ 3,  4, 0.039851],
          [ 0,  5, 0.152538],
          [ 0, 17, 0.138711],
          [ 5,  9, 0.029368],
          [ 9, 13, 0.027699],
          [13, 17, 0.032673]

          # FIXME: These correspond to finger section lengths. They're
          # commented out because closing my fist causes the depth
          # tracking to be disrupted. Should we include them, or find
          # a way to include them?

          # [ 5,  6, 0.066013],
          # [ 6,  7, 0.039947],
          # [ 7,  8, 0.034417],
          # [ 9, 10, 0.071065],
          # [10, 11, 0.043812],
          # [11, 12, 0.036768],
          # [13, 14, 0.066968],
          # [14, 15, 0.039825],
          # [15, 16, 0.035111],
          # [17, 18, 0.049567],
          # [18, 19, 0.031087],
          # [19, 20, 0.029160]
         ]

    # FIXME: Hardcoded fudge-factor
    for d in known_distances:
        d[2] = d[2] * 0.25

    # Iterate through known distances and add up the weighted average.
    fake_z_avg = 0.0
    total_avg_weight = 0.0
    for d in known_distances:
        pt0 = landmark_to_vector(landmarks[d[0]])
        pt1 = landmark_to_vector(landmarks[d[1]])

        # Figure out a weighted average based on how much the vector
        # is facing the camera Z axis. Stuff facing into the camera
        # has less accurate results, so weight it lower.
        normvec = (pt0 - pt1) / numpy.linalg.norm(pt0 - pt1)
        weight = numpy.clip(1.0 - 2.0 * abs(normvec[2]), 0.0, 1.0)

        # Add to the average.
        fake_z_avg += guess_depth_from_known_distance(
            landmarks, world_landmarks,
            d[0], d[1], d[2] / hand_to_head_scale) * weight
        total_avg_weight += weight

    if abs(total_avg_weight) < 0.000001:
        print("HEY THE THING HAPPENED", total_avg_weight)
        # FIXME: Fudge value because I'm tired of this thing throwing
        #   exceptions all the time. Do an actual fix later.
        total_avg_weight = 0.01

    # Finish the average.
    fake_z_avg = fake_z_avg / total_avg_weight

    # This is just centering the origin on the wrist. This is where
    # the origin is for other purposes here, so we'll use this.

    # wrist_point_ndc = landmark_to_vector_old(landmarks[0])
    # viewspace_origin = ndc_to_viewspace(wrist_point_ndc, -fake_z_avg)

    viewspace_origin = ndc_to_viewspace(
        landmark_to_vector(landmarks[0]),
        -fake_z_avg)

    # Apply calibration settings.
    viewspace_origin *= position_scale
    viewspace_origin += position_offset

    return viewspace_origin

def lerp(x, y, alpha):
    return x * alpha + y * (1.0-alpha)

def get_origin_from_mediapipe_transform_matrix(transform):
    # FIXME: This doesn't seem like the normal handedness conversion
    # that we do for other stuff. Is the matrix for heads different
    # from other coordinate spaces we've figured out? (This is
    # mirrored across the X axis.)
    return numpy.array([
        -transform[0][3],
        transform[1][3],
        transform[2][3]])

def quaternion_mirror_rotation_on_x_axis(quat):
    # FIXME: This is definitely messing with powers beyond my
    # comprehension, but I guess it works so that's neat.
    return numpy.array([quat[0], -quat[1], -quat[2], quat[3]])
