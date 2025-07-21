extends Mod_Base
class_name Mod_MediaPipeController

# Tracker process state and UDP connection info.
var udp_server = null
@export var udp_port_base : int = 7098
var _udp_port = udp_port_base # This will change dynamically based on port availability.

# NEW tracker stuff.
var tracker_python_process : KiriPythonWrapperInstance = null

# Current tracking state.
var last_parsed_data = {}
var hand_landmarks_left = []
var hand_landmarks_right = []
var hand_time_since_last_update = [0.0, 0.0]
var hand_time_since_last_missing = [0.0, 0.0]
var mirrored_last_frame = true

## Last values for each blendshape from the tracker, including things that we
## haven't received recent tracking data for.
var blend_shape_last_values = {}

var hand_rest_trackers = {}
var _init_complete = false

var frames_missing_before_spine_reset = 6.0
var blend_to_rest_speed = 4.5

# FIXME: Prune unused settings.

# Settings stuff
@export var mirror_mode : bool = true
@export var arm_rest_angle : float = 60
@export var arm_reset_time : float = 0.5
@export var arm_reset_speed : float = 0.1
@export var hand_tracking_enabed : bool = true

var video_device = Array() # It's an array that we only ever put one thing in.

var blendshape_calibration = {}

var debug_visible_hand_trackers = false

var do_ik_curve = true
var do_yaw_global = true
var do_point_tracker = true
var do_pole_targets = true
var do_rotate_to_match_tracker = true
var do_hands = true

# Temp variables for settings.
var _devices_by_list_entry = {}
var _devices_list = []

var functions_blendshapes = preload("MediaPipeController_BlendShapes.gd")

# FIXME: Make key for this configurable.
var tracking_pause = false

var hand_confidence_time_threshold = 1.0
var hand_count_change_time_threshold = 1.0

var hand_rotation_smoothing : float = 2.0
var hand_position_smoothing : float = 4.0

var hand_position_scale : Vector3 = Vector3(7.0, 7.0, 3.5)
var hand_position_offset : Vector3 = Vector3(0.0, -0.14, 0.0)
var hand_to_head_scale : float = 2.0

# Last packet we got, in case we need to process it again on a frame that
# received no data. (FIXME: hack)
var last_packet_received = null

# What we should show in the new error/warning reporting.
var _current_error_to_show : String = ""

#region Standard Interface Implementation

func _ready():

	var script_path : String = self.get_script().get_path()
	var script_dirname : String = script_path.get_base_dir()

	tracker_python_process = KiriPythonWrapperInstance.new( \
		script_dirname.path_join("/_tracker/Project/new_tracker.py"))

	tracker_python_process.set_cache_path(get_app().get_cache_location())

	print("Setting up Python...")
	if not tracker_python_process.setup_python(false):
		OS.alert("Something went wrong when setting up tracker dependencies!")

	# Start the Python tracker process just long enough to scan for video
	# devices. We won't be starting "for real" until we get to scene_init.
	tracker_python_process.start_process(false)
	_scan_video_devices()
	video_device = ["None"]
	add_tracked_setting(
		"video_device", "Video Device",
		{"values" : _devices_list,
		 "combobox" : true})
	tracker_python_process.stop_process()

	add_tracked_setting("hand_tracking_enabed", "Hand tracking enabled")
	add_tracked_setting("mirror_mode", "Mirror mode")
	add_tracked_setting("arm_rest_angle", "Arm rest angle", { "min" : 0.0, "max" : 180.0 })

	add_tracked_setting("tracking_pause", "Pause tracking")

	add_setting_group("advanced", "Advanced")


	add_tracked_setting(
		"hand_confidence_time_threshold", "Hand confidence time",
		{ "min" : 0.0, "max" : 20.0 },
		"advanced")
	add_tracked_setting(
		"hand_count_change_time_threshold", "Hand count change time",
		{ "min" : 0.0, "max" : 20.0 },
		"advanced")

	add_tracked_setting(
		"frames_missing_before_spine_reset", "Untracked frames before reset",
		{ "min" : -1.0, "max" : 120.0, "step" : 1.0 },
		"advanced")
	add_tracked_setting(
		"blend_to_rest_speed", "Blend back to rest pose speed",
		{ "min" : 0.0, "max" : 10.0, "step" : 0.1 },
		"advanced")


	add_tracked_setting(
		"hand_position_smoothing", "Hand Position Smoothing",
		{ "min" : 1.0, "max" : 5.0 },
		"advanced")
	add_tracked_setting(
		"hand_rotation_smoothing", "Hand Rotation Smoothing",
		{ "min" : 1.0, "max" : 5.0 },
		"advanced")



	add_tracked_setting(
		"hand_position_scale", "Hand Position Scale", {},
		"advanced")
	add_tracked_setting(
		"hand_position_offset", "Hand Position Offset", {},
		"advanced")
	add_tracked_setting(
		"hand_to_head_scale", "Hand to Head Position Scale", { "min" : 0.01, "max" : 10.0 },
		"advanced")

	add_tracked_setting(
		"debug_visible_hand_trackers", "Debug: Visible hand trackers", {},
		"advanced")

	#add_tracked_setting(
		#"hack_reset_hips_every_frame",
		#"Hack: Reset hips every frame (prevent drift)", {},
		#"advanced")
#
	#add_tracked_setting(
		#"hack_reset_shoulders_every_frame",
		#"Hack: Reset shoulders every frame (prevent shoulder drift)", {},
		#"advanced")

	hand_rest_trackers["Left"] = $LeftHandRestReference
	hand_rest_trackers["Right"] = $RightHandRestReference

	set_status("Waiting to start")

	update_settings_ui()

	var calibration_button : Button = Button.new()
	calibration_button.text = "Calibrate Face"
	get_settings_window().add_child(calibration_button)
	calibration_button.pressed.connect(_calibrate_face)

	var clear_calibration_button : Button = Button.new()
	clear_calibration_button.text = "Clear Calibration"
	get_settings_window().add_child(clear_calibration_button)
	clear_calibration_button.pressed.connect(func() : blendshape_calibration = {})

	_reinit()

func _reinit():
	_update_arm_rest_positions()
	_reset_hand_landmarks()

func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray = []

	if video_device == ["None"] or len(video_device) == 0:
		errors.append("No camera is currently selected.")

	if len(_current_error_to_show):
		errors.append(_current_error_to_show)

	if not check_mod_dependency("Mod_AnimationApplier", true):
		errors.append("No AnimationApplier detected, or detected before MediaPipeController. Blend shapes will not function as expected.")

	if not check_mod_dependency("Mod_PoseIK", true):
		errors.append("No PoseIK module detected after MediaPipeController. This is required to pose the model based on the MediaPipeController tracker data.")

	return errors

func save_before(_settings_current: Dictionary):
	_settings_current["blendshape_calibration"] = blendshape_calibration

## Convert a Vector3 to an array, for sending across an RPC call.
static func _vec3_to_array(vec : Vector3):
	return [vec[0], vec[1], vec[2]]

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	super.load_after(_settings_old, _settings_new)
	_update_arm_rest_positions()
	_send_settings_to_tracker()

	var reset_blend_shapes = false
	if reset_blend_shapes:
		for k in blend_shape_last_values.keys():
			blend_shape_last_values[k] = 0.0
	
	if _settings_old["blendshape_calibration"] != _settings_new["blendshape_calibration"]:
		blendshape_calibration = _settings_new["blendshape_calibration"]

	_reinit()

func scene_init():

	_start_process()

	# Find a port number that's open to use. Must be done before start_tracker.
	# OR call the set port number RPC after changing it.
	assert(!udp_server)
	udp_server = PacketPeerUDP.new()
	var udp_error = 1
	_udp_port = udp_port_base
	while udp_error != OK:
		udp_error = udp_server.bind(_udp_port, "127.0.0.1")
		if udp_error != OK:
			_udp_port += 1

	_start_tracker()

	blend_shape_last_values = {}
	last_parsed_data = {}

	# Move hand "rest" trackers into the scene.
	var root = get_skeleton().get_parent()
	var left_rest = $LeftHandRestReference
	var right_rest = $RightHandRestReference
	remove_child(left_rest)
	remove_child(right_rest)
	root.add_child(left_rest)
	root.add_child(right_rest)

	# Set the head tracker to match the model's head position.
	var head_bone_index = get_skeleton().find_bone("Head")
	$Head.global_transform = get_skeleton().get_bone_global_rest(
		head_bone_index)

	_reinit()

	_init_complete = true

func scene_shutdown():

	_stop_tracker()

	_stop_process()

	udp_server.close()
	udp_server = null

	var root = get_skeleton().get_parent()
	var left_rest = root.get_node("LeftHandRestReference")
	var right_rest = root.get_node("RightHandRestReference")

	root.remove_child(left_rest)
	root.remove_child(right_rest)
	add_child(left_rest)
	add_child(right_rest)

	# Reset pose and blendshapes.
	get_app().get_controller().reset_skeleton_to_rest_pose()
	get_app().get_controller().reset_blend_shapes()
	blend_shape_last_values = {}

	_init_complete = false

#endregion

#region Post-Load Model Setup

func _update_arm_rest_positions():
	var skel : Skeleton3D = get_skeleton()
	
	if skel:
		
		for side in [ "Left", "Right" ]:
			
			var rotation_axis : Vector3 = Vector3(0.0, 0.0, 1.0)
			if side == "Left":
				rotation_axis *= -1

			# Rotate the shoulder down so the arm is resting at a specific angle
			# on the Z axis.
			# on the Z axis.
			var shoulder_index = skel.find_bone(side + "Shoulder")
			var hand_index = skel.find_bone(side + "Hand")
			var shoulder_origin : Vector3 = skel.get_bone_global_rest(shoulder_index).origin
			var hand_origin : Vector3 = skel.get_bone_global_rest(hand_index).origin
			var rotation_basis = Basis(rotation_axis, deg_to_rad(arm_rest_angle))
			var new_offset : Vector3 = (hand_origin - shoulder_origin).rotated(
					rotation_axis, deg_to_rad(arm_rest_angle))
			hand_rest_trackers[side].transform.origin = shoulder_origin + new_offset
			hand_rest_trackers[side].transform.basis = rotation_basis

func _calibrate_face():
	var data = {}
	var start = Time.get_ticks_msec()
	blendshape_calibration = {}

	for key in blend_shape_last_values.keys():
		data[key] = []

	# Calibrate for 200 ms
	while Time.get_ticks_msec() < start + 200:
		for key in blend_shape_last_values:
			if blend_shape_last_values[key] > 0 && key.countn("eye") == 0:
				data[key].append(blend_shape_last_values[key])
		await get_tree().process_frame

	# Average data gathered
	for blendshape in data.keys():
		blendshape_calibration[blendshape] = (data[blendshape].reduce(func(accum, number): return accum + number, 0)) / 2.0

#endregion

#region Tracker Process Interop

func _scan_video_devices():

	var dl = tracker_python_process.call_rpc_sync(
		"enumerate_camera_devices", [])
	var device_list : Array = dl if dl is Array else []
	print(device_list)

	for device in device_list:
		var device_generated_name = "{name} ({backend}:{index})".format(device)
		print(device_generated_name)
		_devices_list.append(device_generated_name)
		_devices_by_list_entry[device_generated_name] = device

	# Create a fake "None" entry.
	_devices_list.insert(0, "None")
	_devices_by_list_entry["None"] = { "index" : -1 }

func _start_tracker():
	
	tracker_python_process.call_rpc_async(
		"set_udp_port_number", [_udp_port])

	tracker_python_process.call_rpc_async(
		"set_hand_confidence_time_threshold", [hand_confidence_time_threshold])

	var video_device_index_to_use = 0
	
	if len(video_device) > 0:
		if video_device[0] in _devices_by_list_entry:
			var actual_device_data = _devices_by_list_entry[video_device[0]]
			video_device_index_to_use = int(actual_device_data["index"])
	else:
		video_device_index_to_use = -1

	# FIXME: Replace this all with a single settings dict.
	tracker_python_process.call_rpc_async(
		"set_video_device_number", [video_device_index_to_use])
	tracker_python_process.call_rpc_async(
		"set_hand_count_change_time_threshold", [hand_count_change_time_threshold])

	tracker_python_process.call_rpc_async(
		"start_tracker", [])

func _stop_tracker():

	tracker_python_process.call_rpc_sync(
		"stop_tracker", [])

	set_status("Stopped")

func _send_settings_to_tracker():

	# Don't send these if the tracker process isn't running. We'll send them
	# after it starts, instead (called in _start_process).
	if tracker_python_process.get_status() != KiriPythonWrapperInstance.KiriPythonWrapperStatus.STATUS_RUNNING:
		return

	# Clear out video device setting if it doesn't exist in the list of video
	# devices.
	if len(video_device):
		if not video_device[0] in _devices_by_list_entry.keys():
			video_device.clear()

	# Set the video device.
	if len(video_device):
		var actual_device_data = _devices_by_list_entry[video_device[0]]
		tracker_python_process.call_rpc_async(
			"set_video_device_number", [actual_device_data["index"]])
	else:
		# If no camera selected, then select device -1.
		tracker_python_process.call_rpc_async(
			"set_video_device_number", [-1])

	tracker_python_process.call_rpc_async(
		"set_hand_confidence_time_threshold", [hand_confidence_time_threshold])
		
	tracker_python_process.call_rpc_async(
		"set_hand_count_change_time_threshold", [hand_count_change_time_threshold])

	# FIXME: Replace all of the above with this one call.
	tracker_python_process.call_rpc_async(
		"update_settings", [{
			"hand_position_scale"  : _vec3_to_array(hand_position_scale),
			"hand_position_offset" : _vec3_to_array(hand_position_offset),
			"hand_to_head_scale"   : hand_to_head_scale
		}])

#endregion

#region Update Code

static func _mirror_parsed_data(parsed_data : Dictionary) -> Dictionary:

	var new_parsed_data : Dictionary = parsed_data.duplicate(true)

	# Flip head rotation.
	new_parsed_data["head_quat"][1] *= -1
	new_parsed_data["head_quat"][2] *= -1

	# Flip head position
	new_parsed_data["head_origin"][0] *= -1

	# First, just swap the names.
	for hand_name in [ "left", "right" ]:
		var opposite_hand : String = "left"
		if hand_name == "left": 
			opposite_hand = "right"
		
		new_parsed_data["hand_" + hand_name + "_score"] = parsed_data["hand_" + opposite_hand + "_score"]
		new_parsed_data["hand_" + hand_name + "_rotation"] = parsed_data["hand_" + opposite_hand + "_rotation"]
		new_parsed_data["hand_" + hand_name + "_origin"] = parsed_data["hand_" + opposite_hand + "_origin"]
		new_parsed_data["hand_landmarks_" + hand_name] = parsed_data["hand_landmarks_" + opposite_hand]


	# Now, swap the values.
	for hand_name in [ "left", "right" ]:
		
		var hand_rotation_str = "hand_" + hand_name + "_rotation"
		var hand_origin_str = "hand_" + hand_name + "_origin"
		var hand_landmark_str = "hand_landmarks_" + hand_name 

		# Mirror origins.
		new_parsed_data[hand_origin_str][0] *= -1

		# Mirror the rotation by converting to a quaternion and flipping the
		# same way we flipped the head. Then just convert back.
		var rotation_basis_array = new_parsed_data[hand_rotation_str]
		var rotation_basis = Basis(
			Vector3(rotation_basis_array[0][0], rotation_basis_array[0][1], rotation_basis_array[0][2]),
			Vector3(rotation_basis_array[1][0], rotation_basis_array[1][1], rotation_basis_array[1][2]),
			Vector3(rotation_basis_array[2][0], rotation_basis_array[2][1], rotation_basis_array[2][2]))
		var new_rotation : Basis = (rotation_basis * Basis()).orthonormalized()
		var new_rot_quat = new_rotation.get_rotation_quaternion()
		new_rot_quat.y *= -1.0
		new_rot_quat.z *= -1.0
		new_rotation = Basis(new_rot_quat)
		new_parsed_data[hand_rotation_str] = [
			[new_rotation.x.x, new_rotation.x.y, new_rotation.x.z],
			[new_rotation.y.x, new_rotation.y.y, new_rotation.y.z],
			[new_rotation.z.x, new_rotation.z.y, new_rotation.z.z]]

		# Flip the landmark positions on both X and Z (horizontal and forward)
		# axes.
		for landmark_index in range(0, len(new_parsed_data[hand_landmark_str])):
			new_parsed_data[hand_landmark_str][landmark_index][1] *= -1
			new_parsed_data[hand_landmark_str][landmark_index][2] *= -1

	# Mirror blend shapes.
	if  parsed_data.has("blendshapes"):
		for shape_name : String in parsed_data["blendshapes"].keys():
			var new_string = shape_name
			if shape_name.contains("Left"):
				new_string = shape_name.replace("Left", "Right")
			elif shape_name.contains("Right"):
				new_string = shape_name.replace("Right", "Left")
			if new_string != shape_name:
				new_parsed_data["blendshapes"][new_string] = parsed_data["blendshapes"][shape_name]

	return new_parsed_data

func _process_single_packet(delta : float, parsed_data : Dictionary):

	if "status" in parsed_data:
		set_status(parsed_data["status"])
		return

	if "error" in parsed_data:
		_current_error_to_show = "Error: " + parsed_data["error"]
		set_status(_current_error_to_show)
		return

	set_status("Receiving tracker data")

	# -----------------
	if mirror_mode:
		parsed_data = _mirror_parsed_data(parsed_data)

	last_parsed_data["head_quat"] = parsed_data["head_quat"]
	last_parsed_data["head_origin"] = parsed_data["head_origin"]
	last_parsed_data["head_missing_time"] = parsed_data["head_missing_time"]

	for hand_name in [ "left", "right" ]:
		var hand_score_str = "hand_" + hand_name + "_score"
		var hand_rotation_str = "hand_" + hand_name + "_rotation"
		var hand_origin_str = "hand_" + hand_name + "_origin"
		var hand_landmark_str = "hand_landmarks_" + hand_name # FIXME: Make this consistent.
		# FIXME: Put all the hand stuff under one dictionary entry.

		if hand_score_str in parsed_data:

			var override_val : bool = false
			if not (hand_score_str in last_parsed_data):
				override_val = true
			elif last_parsed_data[hand_score_str] < parsed_data[hand_score_str]:
				override_val = true

			if override_val:
				last_parsed_data[hand_score_str] = parsed_data[hand_score_str]
				last_parsed_data[hand_rotation_str] = parsed_data[hand_rotation_str]
				last_parsed_data[hand_origin_str] = parsed_data[hand_origin_str]
				last_parsed_data[hand_landmark_str] = parsed_data[hand_landmark_str]

	if "blendshapes" in parsed_data:

		# Save the parsed data.
		last_parsed_data["blendshapes"] = parsed_data["blendshapes"]

		if blendshape_calibration != {}:
			for blendshape in last_parsed_data["blendshapes"]:
				if blendshape_calibration[blendshape]:
					last_parsed_data["blendshapes"][blendshape] -= blendshape_calibration[blendshape]

		var shape_dict_new : Dictionary = last_parsed_data["blendshapes"]

		# Blend back to a rest position if we have lost tracking.
		if frames_missing_before_spine_reset < last_parsed_data["head_missing_time"]:
			shape_dict_new = functions_blendshapes.apply_rest_shapes(
				blend_shape_last_values, delta, blend_to_rest_speed)

		blend_shape_last_values.merge(shape_dict_new, true)

	_current_error_to_show = ""

func _process_new_packets(delta):
	var most_recent_packet = null
	var dropped_packets = 0

	while true:
		var packet = udp_server.get_packet()
		
		# FIXME: Disallow packets from remote systems, unless allowed
		# explicitly.

		var packet_string = packet.get_string_from_utf8()
		var json = JSON.new()
		json.parse(packet_string)
		var parsed_data = json.data

		if parsed_data:
			last_packet_received = parsed_data.duplicate(true)
			_process_single_packet(delta, parsed_data)

		if len(packet) > 0:
			if most_recent_packet != null:
				dropped_packets += 1
			most_recent_packet = packet
		else:
			break

	if dropped_packets > 0:
		if dropped_packets <= 2:
			print_log(["Dropped packets (within tolerance): ", dropped_packets])
		else:
			print_log(["Dropped packets (WARNING): ", dropped_packets])

	# Write blendshapes (even if we didn't get any packets).
	var blend_shapes_to_apply : Dictionary = get_global_mod_data("BlendShapes")
	blend_shapes_to_apply.clear()
	blend_shapes_to_apply.merge(blend_shape_last_values, true)

func _start_process():
	tracker_python_process.start_process(false)
	_send_settings_to_tracker()

func _stop_process():
	tracker_python_process.stop_process()

func _process(delta):

	# Process RPC IO.
	if tracker_python_process:
		tracker_python_process.poll()

	var skel : Skeleton3D = get_app().get_skeleton()

	if not _init_complete:
		return
		
	if not udp_server:
		return

	var model_root = get_model()
	if not model_root:
		return

	# FIXME: Remove this. OffKai hack.
	if tracking_pause:

		# We still need to write out blendshapes for this.
		var blend_shapes_to_apply : Dictionary = get_global_mod_data("BlendShapes")
		blend_shapes_to_apply.clear()
		blend_shapes_to_apply.merge(blend_shape_last_values, true)

		# Bail out early.
		return

	_process_new_packets(delta)

	var delta_scale = delta * 60.0
	if delta_scale > 1.0:
		delta_scale = 1.0
	if delta_scale < 0.01:
		delta_scale = 0.01

	if last_parsed_data:
		var parsed_data = last_parsed_data

		# FIXME: Make these adjustable.
		var model_origin_offset = Vector3(0.0, 2.0, 0.0)
		var score_exponent = 1.5
		var score_threshold = 0.1
		var head_rotation_scale = 2.0

		# These are for transforming individual feature points from the
		# mediapipe hand coordinate into skeleton coordinates.
		var hand_origin_multiplier = Vector3(1.0, 1.0, 1.0)
		var head_origin_multiplier = Vector3(1.0, 1.0, 1.0)
		var head_quat_multiplier = [1.0, 1.0, 1.0, 1.0]

		var tracker_left = $Hand_Left
		var tracker_right = $Hand_Right
		
		# FIXME: MIRROR MESS (CLEAN THIS UP)
		hand_origin_multiplier = Vector3(-1.0, 1.0, 1.0)
		head_origin_multiplier = Vector3(-1.0, 1.0, 1.0)
		head_quat_multiplier = [1.0, -1.0, -1.0, 1.0]

		# -----------------------------------------------------------------------------------------
		# Hand packets

		# Pick hand rest references based on mirroring.
		var hand_rest_reference_left = hand_rest_trackers["Left"]
		var hand_rest_reference_right = hand_rest_trackers["Right"]

		# FIXME: Code smell. Replace with a function call.
		var per_hand_data = [
			{
				"side" : "Left",
				"tracker_object" : tracker_left,
				"rest_reference_object" : hand_rest_reference_left,
				"index" : 0
			}, {
				"side" : "Right",
			  	"tracker_object" : tracker_right,
				"rest_reference_object" : hand_rest_reference_right,
				"index" : 1
			}
		 ]

		for hand_data in per_hand_data:
			# FIXME: We moved this out of the main function here into another
			# function and just copied all the variables it used. We NEED to
			# clean that up.
			_update_hand_tracker(
				delta, hand_data, parsed_data, score_threshold,
				score_exponent, model_origin_offset, hand_origin_multiplier,
				skel, delta_scale);

		# -----------------------------------------------------------------------------------------
		# Head packets
		
		# FIXME: Hardcoded transform
		var head_origin_array = parsed_data["head_origin"]
		if parsed_data["head_missing_time"] <= frames_missing_before_spine_reset:
			$Head.transform.origin = $Head.transform.origin.lerp(
				model_origin_offset +
				(Vector3(
					head_origin_array[0],
					head_origin_array[1],
					head_origin_array[2]) * head_origin_multiplier),
					delta_scale * 0.5) # FIXME: Hardcoded smoothing.
			var head_quat_array = parsed_data["head_quat"]
			var head_euler = Basis(Quaternion(
				head_quat_array[0] * head_quat_multiplier[0],
				head_quat_array[1] * head_quat_multiplier[1],
				head_quat_array[2] * head_quat_multiplier[2],
				head_quat_array[3] * head_quat_multiplier[3])).get_euler()
			$Head.transform.basis = $Head.transform.basis.slerp(
				Basis.from_euler(head_euler * head_rotation_scale),
				delta_scale * 0.5) # FIXME: Hardcoded smoothing.
		else:

			# Haven't had face tracker data in a while? Just blend us back to a
			# rest position.
			var head_index : int = skel.find_bone("Head")
			var rest_global : Transform3D = skel.get_bone_rest(head_index)
			$Head.global_transform.basis = Basis(
				$Head.global_transform.basis.get_rotation_quaternion().slerp(
					rest_global.basis.get_rotation_quaternion(), blend_to_rest_speed * delta))


		var hands = [ \
			[ "Left", hand_landmarks_left, $Hand_Left, Basis() ], # FIXME: Remove the last value.
			[ "Right", hand_landmarks_right, $Hand_Right, Basis() ]]  # FIXME: Remove the last value.
		for hand in hands:
			_update_hand(hand, parsed_data, skel)

	# ---------------------------------------------------------------------------------------------
	# Send tracker data down the pipe.

	var trackers : Dictionary = get_global_mod_data("trackers")
	trackers["head"] = {
		"transform" : $Head.global_transform,
		"active" : true
	}

	trackers["hand_left"] = {
		"transform" : $Hand_Left.global_transform,
		"active" : hand_time_since_last_update[0] <= arm_reset_time
	}

	trackers["hand_right"] = {
		"transform" : $Hand_Right.global_transform,
		"active" : hand_time_since_last_update[1] <= arm_reset_time
	}

	# https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker
	var mediapipe_hand_landmark_names : Array = [
		"wrist",

		"thumb_cmc", # carpometacarpal
		"thumb_mcp", # metacarpal
		"thumb_ip", # interphalangeal
		"thumb_tip", # tip

		"index_finger_mcp",
		"index_finger_pip", # proximal something something
		"index_finger_dip", # distal something something
		"index_finger_tip",

		"middle_finger_mcp",
		"middle_finger_pip",
		"middle_finger_dip",
		"middle_finger_tip",

		"ring_finger_mcp",
		"ring_finger_pip",
		"ring_finger_dip",
		"ring_finger_tip",

		"pinky_finger_mcp",
		"pinky_finger_pip",
		"pinky_finger_dip",
		"pinky_finger_tip",
	]

	trackers["finger_positions"] = {}

	for side : String in [ "left", "right" ]:

		var tracker : Node3D;
		if side == "left":
			tracker = $Hand_Left
		else:
			tracker = $Hand_Right

		for landmark_index : int in range(0, len(mediapipe_hand_landmark_names)):
			if tracker.get_child_count() > landmark_index:
				var finger_tracker : Node3D = tracker.get_child(landmark_index)
				var landmark_name : String = side + "_" + mediapipe_hand_landmark_names[landmark_index]
				trackers["finger_positions"][landmark_name] = finger_tracker.global_transform.origin

#endregion

#region Hands

func _reset_hand_landmarks():

	for tracker : Node3D in [ $Hand_Left, $Hand_Right ]:
		
		# Make sure we have all the children.
		while tracker.get_child_count() < 21:
			var new_finger_tracker : MeshInstance3D = MeshInstance3D.new()
			tracker.add_child(new_finger_tracker)
			if tracker == $Hand_Left:
				hand_landmarks_left.append(new_finger_tracker)
			else:
				hand_landmarks_right.append(new_finger_tracker)

		# Set them visible or not.
		for finger_tracker : MeshInstance3D in tracker.get_children():
			if debug_visible_hand_trackers:
				if not finger_tracker.mesh:
					finger_tracker.mesh = SphereMesh.new()
					finger_tracker.mesh.radius = 0.004
					finger_tracker.mesh.height = finger_tracker.mesh.radius * 2.0
					finger_tracker.material_override = preload(
						"MediaPipeTrackerMaterial.tres")
			else:
				finger_tracker.mesh = null

	assert(len(hand_landmarks_left) == 21)
	assert(len(hand_landmarks_right) == 21)

func _update_hand(hand, parsed_data, skel : Skeleton3D):
	var mark_counter = 0

	var which_hand = hand[0].to_lower()

	var hand_landmark_rotation_to_use = hand[3]
	var hand_landmarks = hand[1]

	for mark in parsed_data["hand_landmarks_" + which_hand]:

		# Update debug visibility.
		for landmark in hand_landmarks:
			if landmark.mesh == null and debug_visible_hand_trackers:
				landmark.mesh = SphereMesh.new()
				landmark.mesh.radius = 0.004
				landmark.mesh.height = landmark.mesh.radius * 2.0
				landmark.material_override = preload(
					"MediaPipeTrackerMaterial.tres")
			elif landmark.mesh != null and (not debug_visible_hand_trackers):
				landmark.mesh = null

		var marker = hand_landmarks[mark_counter]
		var marker_old_worldspace = marker.global_transform.origin
		var marker_original_local = Vector3(mark[0], mark[1], mark[2]) # FIXME: Add a scaling value.

		# FIXME: WHY THE HECK DO WE HAVE TO DO DO THIS!?!?!?!?!?!?!?!?!?!?!?!?!!!??!?!?!?!?!?!
		if which_hand == "right":
			marker_original_local[0] *= -1
			marker_original_local[1] *= -1
			marker_original_local[2] *= -1
	
		var marker_new_local = hand_landmark_rotation_to_use * \
			marker_original_local
		var marker_new_worldspace = marker.get_parent().transform * marker_new_local
		
#						marker.transform.origin = \
#							hand_landmark_rotation_to_use * \
#							(Vector3(mark[0], mark[1], mark[2]) * hand_landmark_position_multiplier)
		marker.global_transform.origin = lerp( \
			marker_old_worldspace, \
			marker_new_worldspace, \
			0.25) # FIXME: Hardcoded smoothing
		
		mark_counter += 1

	# FIXME: I have no idea what these columns mean anymore.
	var finger_bone_array_array = [
		[
			{
				"bone_name_current" : "IndexProximal",
				"landmark_index_start" : 5,
				"landmark_index_end"  : 6,
				"bone_name_next" : "IndexIntermediate",
				"bone_name_parent_of_next" : "IndexProximal"
			},
			{
				"bone_name_current" : "IndexIntermediate",
				"landmark_index_start" : 6,
				"landmark_index_end"  : 7,
				"bone_name_next" : "IndexDistal",
				"bone_name_parent_of_next" : "IndexIntermediate"
			},
			{
				"bone_name_current" : "IndexDistal",
				"landmark_index_start" : 7,
				"landmark_index_end"  : 8,
				"bone_name_next" : "IndexDistal",
				"bone_name_parent_of_next" : "IndexIntermediate"
			}
		],
		[
			{
				"bone_name_current" : "MiddleProximal",
				"landmark_index_start" : 9,
				"landmark_index_end"  : 10,
				"bone_name_next" : "MiddleIntermediate",
				"bone_name_parent_of_next" : "MiddleProximal"
			},
			{
				"bone_name_current" : "MiddleIntermediate",
				"landmark_index_start" : 10,
				"landmark_index_end"  : 11,
				"bone_name_next" : "MiddleDistal",
				"bone_name_parent_of_next" : "MiddleIntermediate"
			},
			{
				"bone_name_current" : "MiddleDistal",
				"landmark_index_start" : 11,
				"landmark_index_end"  : 12,
				"bone_name_next" : "MiddleDistal",
				"bone_name_parent_of_next" : "MiddleIntermediate"
			}
		],
		[
			{
				"bone_name_current" : "RingProximal",
				"landmark_index_start" : 13,
				"landmark_index_end"  : 14,
				"bone_name_next" : "RingIntermediate",
				"bone_name_parent_of_next" : "RingProximal"
			},
			{
				"bone_name_current" : "RingIntermediate",
				"landmark_index_start" : 14,
				"landmark_index_end"  : 15,
				"bone_name_next" : "RingDistal",
				"bone_name_parent_of_next" : "RingIntermediate"
			},
			{
				"bone_name_current" : "RingDistal",
				"landmark_index_start" : 15,
				"landmark_index_end"  : 16,
				"bone_name_next" : "RingDistal",
				"bone_name_parent_of_next" : "RingIntermediate"
			}
		],
		[
			{
				"bone_name_current" : "LittleProximal",
				"landmark_index_start" : 17,
				"landmark_index_end"  : 18,
				"bone_name_next" : "LittleIntermediate",
				"bone_name_parent_of_next" : "LittleProximal"
			},
			{
				"bone_name_current" : "LittleIntermediate",
				"landmark_index_start" : 18,
				"landmark_index_end"  : 19,
				"bone_name_next" : "LittleDistal",
				"bone_name_parent_of_next" : "LittleIntermediate"
			},
			{
				"bone_name_current" : "LittleDistal",
				"landmark_index_start" : 19,
				"landmark_index_end"  : 20,
				"bone_name_next" : "LittleDistal",
				"bone_name_parent_of_next" : "LittleIntermediate"
			}
		],
		[
			# FIXME: Metacarpal *origin* needs to change relative to hand as well.
			{
				"bone_name_current" : "ThumbMetacarpal",
				"landmark_index_start" : 1,
				"landmark_index_end"  : 2,
				"bone_name_next" : "ThumbProximal",
				"bone_name_parent_of_next" : "ThumbMetacarpal"
			},
			{
				"bone_name_current" : "ThumbProximal",
				"landmark_index_start" : 2,
				"landmark_index_end"  : 3,
				"bone_name_next" : "ThumbDistal",
				"bone_name_parent_of_next" : "ThumbProximal"
			},
			{
				"bone_name_current" : "ThumbDistal",
				"landmark_index_start" : 3,
				"landmark_index_end"  : 4,
				"bone_name_next" : "ThumbDistal",
				"bone_name_parent_of_next" : "ThumbProximal"
			},
		]
	]

func _update_hand_tracker(
	delta, hand_data, parsed_data, score_threshold, score_exponent,
	model_origin_offset, hand_origin_multiplier, skel,
	delta_scale):

	var time_since_last_update = hand_time_since_last_update[hand_data["index"]]
	var time_since_last_missing = hand_time_since_last_missing[hand_data["index"]]

	var hand_str = hand_data["side"]
	var hand_str_lower = hand_str.to_lower()
	var tracker_ob = hand_data["tracker_object"]

	var hand_score_str = "hand_" + hand_str_lower + "_score"
	var hand_origin_str = "hand_" + hand_str_lower + "_origin"
	var hand_rotation_str = "hand_" + hand_str_lower + "_rotation"
	
	var hand_origin_array = parsed_data[hand_origin_str]
	var hand_score = parsed_data[hand_score_str]

	# Apply thresholds to the confidence score.			
	if hand_score < score_threshold or not hand_tracking_enabed: # FIXME: Wrong place for the enabled check?
		hand_score = 0.0

	# Track time since last visible or not.
	if hand_score >= score_threshold:
		time_since_last_update = 0.0
		time_since_last_missing += delta
	else:
		time_since_last_update += delta
		time_since_last_missing = 0.0

	hand_time_since_last_update[hand_data["index"]] = time_since_last_update
	hand_time_since_last_missing[hand_data["index"]] = time_since_last_missing

	if time_since_last_update > arm_reset_time:
		
		var reference_ob = hand_data["rest_reference_object"]
		# Move hand to rest position.
		tracker_ob.global_transform.origin = tracker_ob.global_transform.origin.lerp(
			reference_ob.global_transform.origin, arm_reset_speed) # FIXME: Hardcoded value.
		
		var rot_quat1 = tracker_ob.global_transform.basis.get_rotation_quaternion()
		var rot_quat2 = reference_ob.global_transform.basis.get_rotation_quaternion()
		tracker_ob.global_transform.basis = Basis(rot_quat1.slerp(rot_quat2, arm_reset_speed)) # FIXME: Hardcoded value
		tracker_ob.global_transform.basis = tracker_ob.global_transform.basis.orthonormalized()

	elif time_since_last_missing > 0.1: # FIXME: Hardcoded value.

		# Stretch the last bit of the score out with an exponent.
		hand_score = pow(hand_score, score_exponent)
		parsed_data[hand_score_str] = hand_score
	
		# TODO: Replace the tracker object with just a Transform3D.
		var target_origin = model_origin_offset + (Vector3(
			hand_origin_array[0],
			hand_origin_array[1],
			hand_origin_array[2]) * hand_origin_multiplier)
		
		# Attempt to move hand in front of model. Reaching behind is
		# *usually* the results of bad data.
		#
		# FIXME: Ugly hack.
		#   If we're going to do this, we need to make sure we do it in the model's forward
		#   direction.
		#
		# FIXME: Hardcoded values all over this part.
		#
		var chest_transform_global_pose = skel.get_bone_global_pose(skel.find_bone("Chest"))
		var min_z = (skel.global_transform * chest_transform_global_pose).origin
		if target_origin.z < min_z.z + 0.2:
			target_origin.z = min_z.z + 0.2

		# Move tracker forward if we're reaching across the chest to see
		# if we can fix some clipping-into-chest problems.
		#
		# FIXME: Hardcoded values all over this part.
		#

		# FIXME: THIS IS BAD CODE AND YOU (KIRI) SHOULD FEEL BAD ABOUT IT.
		var tracker_in_chest_space = chest_transform_global_pose.inverse() * target_origin
		# FIXME: Hack for mirror.
		if hand_str_lower == "right":
			tracker_in_chest_space.x *= -1

		# Just clamp the overall reach, first.

		# Clamp tracker reach.
		# FIXME: Hardcoded value.
		if tracker_in_chest_space.x < -0.2:
			tracker_in_chest_space.x = -0.2

		# Now move forward.
		if tracker_in_chest_space.x < 0.0:
			# FIXME: Hardcoded scaling value.
			tracker_in_chest_space.z += -(tracker_in_chest_space.x - 0.1) * 0.2

		# FIXME: Hack for mirror.
		if hand_str_lower == "right":
			tracker_in_chest_space.x *= -1

		target_origin = chest_transform_global_pose * tracker_in_chest_space

		var rotation_basis_array = parsed_data[hand_rotation_str]

		var rotation_basis = Basis(
			Vector3(rotation_basis_array[0][0], rotation_basis_array[0][1], rotation_basis_array[0][2]),
			Vector3(rotation_basis_array[1][0], rotation_basis_array[1][1], rotation_basis_array[1][2]),
			Vector3(rotation_basis_array[2][0], rotation_basis_array[2][1], rotation_basis_array[2][2]))

		var new_rotation : Basis = (rotation_basis * Basis()).orthonormalized()

		# If we don't do this, the hands often don't rotate. !?!?!?!?!
		var new_rot_quat = new_rotation.get_rotation_quaternion()
		#new_rot_quat.y *= -1.0
		#new_rot_quat.z *= -1.0
		#new_rot_quat.w *= -1.0
		#new_rot_quat.x *= -1.0
		new_rotation = Basis(new_rot_quat)

		# Why do we have to go through the global transform? I guess we need like a "baked"
		# version of the transform that handles all of our weird axis flipping.
		
		var old_world_transform = tracker_ob.get_global_transform()

		#tracker_ob.transform.basis = new_rotation # Basis(new_rotation.orthonormalized().get_rotation_quaternion())
		
		# FIXME: Can't work due to variability in chest bone location?
		#   (problem with new model rigging that wasn't a problem with the old)
#				# Snap tracker to rest position if we're below a certain
#				# threshold
#				#
#				# FIXME: Hardcoded threshold.
#				if tracker_in_chest_space.y < 0.0:
#					var reference_ob = hand[3]
#					target_origin = reference_ob.global_transform.origin
#					#tracker_ob.transform.basis = reference_ob.transform.basis
#					new_rotation = reference_ob.transform.basis
			
		var lerp_scale = 1.0 / hand_position_smoothing
		tracker_ob.transform.origin = tracker_ob.transform.origin.lerp(
			target_origin,
			hand_score * delta_scale * lerp_scale)
		
		# FIXME: Hardcoded SLERP speed. Make configurable.
		tracker_ob.transform.basis = Basis(
			tracker_ob.transform.basis.orthonormalized().get_rotation_quaternion().slerp(
			new_rotation, 1.0 / hand_rotation_smoothing)) # Basis(new_rotation.orthonormalized().get_rotation_quaternion())
		
		var new_world_transform = tracker_ob.get_global_transform()
		
		# FIXME: Hardcoded smoothing value.
		var interped_transform = old_world_transform.interpolate_with(new_world_transform, 0.75)
		tracker_ob.global_transform.basis = interped_transform.basis

		#tracker_ob.transform.basis = new_rotation
		if tracker_ob.mesh:
			tracker_ob.mesh.material.albedo_color.a = 0.25 + hand_score * 0.75

#endregion
