extends Mod_Base

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
var blend_shape_last_values = {}
var hand_rest_trackers = {}
var _init_complete = false

var frames_missing_before_spine_reset = 6.0
var blend_to_rest_speed = 4.5
var head_vertical_offset : float = -0.2
var hips_vertical_blend_speed : float = 6.0


# FIXME: Make this a dictionary (spine, left hand, right hand, etc)
var _ikchains = []

# Settings stuff
@export var mirror_mode : bool = true
@export var arm_rest_angle : float = 60
@export var arm_reset_time : float = 0.5
@export var arm_reset_speed : float = 0.1
@export var hand_tracking_enabed : bool = true
var use_vrm_basic_shapes = false
var use_mediapipe_shapes = true
var video_device = Array() # It's an array that we only ever put one thing in.

var blendshape_calibration = {}

var debug_visible_hand_trackers = false

# TODO: Add settings for these

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
var chest_yaw_scale : float = 0.25
var lean_scale : float = 2.0
var hip_adjustment_speed : float = 1.0

var blendshape_scale : float = 1.2
var blendshape_smoothing_scale : float = 0.05

var hand_position_scale : Vector3 = Vector3(7.0, 7.0, 3.5)
var hand_position_offset : Vector3 = Vector3(0.0, -0.14, 0.0)
var hand_to_head_scale : float = 2.0

const blendshape_names_mediapipe : PackedStringArray = [
	"_neutral",
	"browDownLeft",
	"browDownRight",
	"browInnerUp",
	"browOuterUpLeft",
	"browOuterUpRight",
	"cheekPuff",
	"cheekSquintLeft",
	"cheekSquintRight",
	"eyeBlinkLeft",
	"eyeBlinkRight",
	"eyeLookDownLeft",
	"eyeLookDownRight",
	"eyeLookInLeft",
	"eyeLookInRight",
	"eyeLookOutLeft",
	"eyeLookOutRight",
	"eyeLookUpLeft",
	"eyeLookUpRight",
	"eyeSquintLeft",
	"eyeSquintRight",
	"eyeWideLeft",
	"eyeWideRight",
	"jawForward",
	"jawLeft",
	"jawOpen",
	"jawRight",
	"mouthClose",
	"mouthDimpleLeft",
	"mouthDimpleRight",
	"mouthFrownLeft",
	"mouthFrownRight",
	"mouthFunnel",
	"mouthLeft",
	"mouthLowerDownLeft",
	"mouthLowerDownRight",
	"mouthPressLeft",
	"mouthPressRight",
	"mouthPucker",
	"mouthRight",
	"mouthRollLower",
	"mouthRollUpper",
	"mouthShrugLower",
	"mouthShrugUpper",
	"mouthSmileLeft",
	"mouthSmileRight",
	"mouthStretchLeft",
	"mouthStretchRight",
	"mouthUpperUpLeft",
	"mouthUpperUpRight",
	"noseSneerLeft",
	"noseSneerRight",
]

const blendshape_names_vrm1 : PackedStringArray = [
	"happy", "angry", "sad", "relaxed", "surprised",
	"aa", "ih", "ou", "ee", "oh",
	#"blink", # Disabled because we only use left/right.
	"blinkLeft", "blinkRight",
	"lookUp", "lookDown",
	"lookLeft", "lookRight",
	"neutral"
]

const blendshape_names_all : PackedStringArray = \
	blendshape_names_mediapipe + blendshape_names_vrm1

var blendshape_scales : Dictionary = {}
var blendshape_offsets : Dictionary = {}
var blendshape_smoothing : Dictionary = {}
var blendshape_progressbars : Dictionary = {}
var blendshape_progressbar_update_index : int = 0

var eyes_link_vertical : bool = false
var eyes_link_horizontal : bool = false
var eyes_link_blink : bool = false
var eyes_prevent_opposite_directions : bool = true

# Last packet we got, in case we need to process it again on a frame that
# received no data. (FIXME: hack)
var last_packet_received = null

func _get_property_list() -> Array[Dictionary]:

	var properties : Array[Dictionary] = []

	for blend_shape : String in blendshape_names_all:
		var new_entry_scale : Dictionary = {
			"name" : "blendshape_scale_" + blend_shape,
			"type" : TYPE_FLOAT
		}
		var new_entry_offset : Dictionary = {
			"name" : "blendshape_offset_" + blend_shape,
			"type" : TYPE_FLOAT
		}
		var new_entry_smoothing : Dictionary = {
			"name" : "blendshape_smoothing_" + blend_shape,
			"type" : TYPE_FLOAT
		}
		properties.append(new_entry_scale)
		properties.append(new_entry_offset)
		properties.append(new_entry_smoothing)

	return properties

func _get(property: StringName) -> Variant:

	if property.begins_with("blendshape_scale_"):
		var blendshape_name : String = property.substr(len("blendshape_scale_"))
		if blendshape_name in blendshape_names_all:
			if blendshape_name in blendshape_scales:
				return blendshape_scales[blendshape_name]
			else:
				return 1.0
		else:
			return null

	if property.begins_with("blendshape_offset_"):
		var blendshape_name : String = property.substr(len("blendshape_offset_"))
		if blendshape_name in blendshape_names_all:
			if blendshape_name in blendshape_offsets:
				return blendshape_offsets[blendshape_name]
			else:
				return 0.0
		else:
			return null

	if property.begins_with("blendshape_smoothing_"):
		var blendshape_name : String = property.substr(len("blendshape_smoothing_"))
		if blendshape_name in blendshape_names_all:
			if blendshape_name in blendshape_smoothing:
				return blendshape_smoothing[blendshape_name]
			else:
				return 0.0
		else:
			return null

	return null

func _set(property: StringName, value: Variant) -> bool:

	if property.begins_with("blendshape_smoothing_"):
		var blendshape_name : String = property.substr(len("blendshape_smoothing_"))
		if blendshape_name in blendshape_names_all:
			if value == 1.0:
				blendshape_smoothing.erase(blendshape_name)
			else:
				blendshape_smoothing[blendshape_name] = value
			return true
		else:
			return false

	if property.begins_with("blendshape_scale_"):
		var blendshape_name : String = property.substr(len("blendshape_scale_"))
		if blendshape_name in blendshape_names_all:
			if value == 1.0:
				blendshape_scales.erase(blendshape_name)
			else:
				blendshape_scales[blendshape_name] = value
			return true
		else:
			return false

	if property.begins_with("blendshape_offset_"):
		var blendshape_name : String = property.substr(len("blendshape_offset_"))
		if blendshape_name in blendshape_names_all:
			if value == 0.0:
				blendshape_offsets.erase(blendshape_name)
			else:
				blendshape_offsets[blendshape_name] = value
			return true
		else:
			return false

	return false

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
	add_tracked_setting("use_vrm_basic_shapes", "Use basic VRM shapes")
	add_tracked_setting("use_mediapipe_shapes", "Use MediaPipe shapes")
	add_tracked_setting("mirror_mode", "Mirror mode")
	add_tracked_setting("arm_rest_angle", "Arm rest angle", { "min" : 0.0, "max" : 180.0 })

	add_tracked_setting("tracking_pause", "Pause tracking")

	add_setting_group("advanced", "Advanced")

	add_tracked_setting(
		"eyes_prevent_opposite_directions", "Prevent eyes looking outwards", {},
		"advanced")
	add_tracked_setting(
		"eyes_link_vertical", "Link eyes vertical direction", {},
		"advanced")
	add_tracked_setting(
		"eyes_link_horizontal", "Link eyes horizontal direction", {},
		"advanced")
	add_tracked_setting(
		"eyes_link_blink", "Link eyes blinking", {},
		"advanced")

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
		"head_vertical_offset", "Head vertical offset",
		{ "min" : -1.0, "max" : 1.0 },
		"advanced")
	add_tracked_setting(
		"hips_vertical_blend_speed", "Hips vertical blend speed",
		{ "min" : 0.0, "max" : 20.0 },
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
		"chest_yaw_scale", "Chest Yaw Rotation Scale",
		{ "min" : -2.0, "max" : 2.0 },
		"advanced")

	add_tracked_setting(
		"lean_scale", "Lean Scale",
		{ "min" : -4.0, "max" : 4.0 },
		"advanced")

	add_tracked_setting(
		"hip_adjustment_speed", "Hip Adjustment Speed", { "min" : 0.0, "max" : 10.0 },
		"advanced")

	add_tracked_setting(
		"blendshape_scale", "Blend Shape Scale", { "min" : 0.0, "max" : 10.0 },
		"advanced")
	# FIXME: Setting disabled because it doesn't do anything until you actually
	#   set the per-shape smoothing scale, which doesn't make sense from a UI
	#   standpoint.
	#add_tracked_setting(
		#"blendshape_smoothing_scale", "Blend Shape Smoothing", { "min" : 0.0, "max" : 100.0 },
		#"advanced")

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

	add_setting_group("blendshapes_scale_offset", "Blendshape Tuning")

	for blendshape_name in blendshape_names_all:

		var label : Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = blendshape_name + " scale/offset/smoothing"
		# FIXME: Direct use of internal (indented private, not protected) variables.
		_settings_groups["blendshapes_scale_offset"].add_setting_control(label)

		var progressbar : ProgressBar = ProgressBar.new()
		progressbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progressbar.show_percentage = false
		progressbar.value = randf()
		progressbar.min_value = 0.0
		progressbar.max_value = 1.0
		progressbar.custom_minimum_size = Vector2(0, 32.0)
		# FIXME: Direct use of internal variables.
		_settings_groups["blendshapes_scale_offset"].add_setting_control(progressbar)

		# Mouth shapes start with scale doubled by default.
		if blendshape_name.begins_with("mouth") or blendshape_name.begins_with("jaw"):
			blendshape_scales[blendshape_name] = 2.0

		add_tracked_setting(
			"blendshape_scale_" + blendshape_name, "",  { "min" : 0.0, "max" : 5.0 },
			"blendshapes_scale_offset")
		add_tracked_setting(
			"blendshape_offset_" + blendshape_name, "",  { "min" : -2.0, "max" : 2.0 },
			"blendshapes_scale_offset")
		add_tracked_setting(
			"blendshape_smoothing_" + blendshape_name, "",  { "min" : 0.0, "max" : 10.0 },
			"blendshapes_scale_offset")

		blendshape_progressbars[blendshape_name] = progressbar

		# TODO: Link together left/right sides (optionally?)

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

	# FIXME: REMOVE THIS. It's just to work around an annoyance while I stream
	#   until the actual bug is fixed.
	var reset_pose_button : Button = Button.new()
	reset_pose_button.text = "Reset pose (FIXME!!!)"
	get_settings_window().add_child(reset_pose_button)
	reset_pose_button.pressed.connect(
		func():
			get_app().get_controller().reset_skeleton_to_rest_pose()
			get_app().get_controller().reset_blend_shapes()
			blend_shape_last_values = {}
	)

	_update_for_new_model_if_needed()

func save_before(_settings_current: Dictionary):
	_settings_current["blendshape_calibration"] = blendshape_calibration

## Convert a Vector3 to an array, for sending across an RPC call.
static func _vec3_to_array(vec : Vector3):
	return [vec[0], vec[1], vec[2]]

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

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	super.load_after(_settings_old, _settings_new)
	_update_arm_rest_positions()

	if _settings_new["chest_yaw_scale"] != _settings_old["chest_yaw_scale"]:
		_setup_ik_chains()

	_send_settings_to_tracker()

	var reset_blend_shapes = false
	if _settings_old["use_vrm_basic_shapes"] != _settings_new["use_vrm_basic_shapes"]:
		reset_blend_shapes = true
	if _settings_old["use_mediapipe_shapes"] != _settings_new["use_mediapipe_shapes"]:
		reset_blend_shapes = true
	if reset_blend_shapes:
		for k in blend_shape_last_values.keys():
			blend_shape_last_values[k] = 0.0
	
	if _settings_old["blendshape_calibration"] != _settings_new["blendshape_calibration"]:
		blendshape_calibration = _settings_new["blendshape_calibration"]

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

	start_tracker()

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

	_setup_ik_chains()
	_update_arm_rest_positions()
	
	_init_complete = true

func scene_shutdown():

	stop_tracker()

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

	_ikchains = []

	# Reset pose and blendshapes.
	get_app().get_controller().reset_skeleton_to_rest_pose()
	get_app().get_controller().reset_blend_shapes()
	blend_shape_last_values = {}

	_init_complete = false

# -----------------------------------------------------------------------------
# Post-load model setup.

func _update_arm_rest_positions():
	var skel : Skeleton3D = get_skeleton()
	
	if skel:
		
		for side in [ "Left", "Right" ]:
			
			var rotation_axis : Vector3 = Vector3(0.0, 0.0, 1.0)
			if side == "Left":
				rotation_axis *= -1

			# Rotate the shoulder down so the arm is resting at a specific angle
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

func _setup_ik_chains():

	# ORDER MATTERS ON THE CHAIN ARRAY. SPINE BEFORE ARMS BEFORE FINGERS.

	_ikchains = []
	
	var chain_spine : MediaPipeController_IKChain = MediaPipeController_IKChain.new()
	chain_spine.skeleton = get_skeleton()
	chain_spine.base_bone = "Hips"
	chain_spine.tip_bone = "Head"
	chain_spine.rotation_low = 0.0 * PI
	chain_spine.rotation_high = 2.0 * PI
	chain_spine.do_yaw = true
	chain_spine.main_axis_of_rotation = Vector3(1.0, 0.0, 0.0)
	chain_spine.secondary_axis_of_rotation = Vector3(0.0, 1.0, 0.0)
	chain_spine.pole_direction_target = Vector3(0.0, 0.0, 0.0) # No pole target
	chain_spine.tracker_object = $Head
	chain_spine.yaw_scale = chest_yaw_scale

	#chain_spine.do_rotate_to_match_tracker = false
	#chain_spine.do_point_tracker = false
	#chain_spine.do_pole_targets = false

	# FIXME: Add yaw scale as an option.
	_ikchains.append(chain_spine)

	var x_pole_dist = 10.0
	var z_pole_dist = 10.0
	var y_pole_dist = 5.0
	
	var arm_rotation_axis = Vector3(0.0, 1.0, 0.0).normalized()
	var finger_rotation_axis = Vector3(0.0, 0.0, 1.0).normalized()



	var hand_tracker_left : Node3D = $Hand_Left
	var hand_tracker_right : Node3D = $Hand_Right

	# FIXME: UGHHHGGHfgjkdnjvhndfvdfnvjkdfnjksdfn
	# FIXME: MIRROR MESS
	hand_tracker_left = $Hand_Right
	hand_tracker_right = $Hand_Left

	# Make sure finger landmarks exist already.
	_reset_hand_landmarks()



	for side in [ "Left", "Right" ]:

		var chain_hand = MediaPipeController_IKChain.new()
		chain_hand.skeleton = get_skeleton()
		chain_hand.base_bone = side + "UpperArm"
		chain_hand.tip_bone = side + "Hand"
		#chain_hand.tip_bone = side + "IndexProximal"
		chain_hand.rotation_low = 0.05 * PI
		chain_hand.rotation_high = 2.0 * 0.99 * PI
		chain_hand.do_yaw = false
		chain_hand.do_bone_roll = true
		chain_hand.secondary_axis_of_rotation = Vector3(0.0, 1.0, 0.0)

		if side == "Left":
			chain_hand.main_axis_of_rotation = -arm_rotation_axis
			chain_hand.pole_direction_target = Vector3(
				x_pole_dist, -y_pole_dist, -z_pole_dist)
			chain_hand.tracker_object = hand_tracker_left
		else:
			chain_hand.main_axis_of_rotation = arm_rotation_axis
			chain_hand.pole_direction_target = Vector3(
				-x_pole_dist, -y_pole_dist, -z_pole_dist)
			chain_hand.tracker_object = hand_tracker_right
			
		_ikchains.append(chain_hand)

	return

	# See here for where these numbers come from:
	#   https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker
	var fingertip_tracking_mappings = {
		"Index" : 8,
		"Middle" : 12,
		"Ring" : 16,
		"Little" : 20,
		"Thumb" : 4
	}

	for side in [ "Left", "Right" ]:

		var hand_tracker_object = hand_tracker_left
		if side == "Right":
			hand_tracker_object = hand_tracker_right

		for finger in [ "Index", "Middle", "Ring", "Little" ]:

			var chain_finger : MediaPipeController_IKChain = \
				MediaPipeController_IKChain.new()
			chain_finger.skeleton = get_skeleton()

			# Attempt to find finger root bone.
			chain_finger.base_bone = side + finger + "Proximal"
			if chain_finger.skeleton.find_bone(chain_finger.base_bone) == -1:
				# Finger missing entirely? Bail out.
				continue

			# Attempt to find finger most-distal bone.
			chain_finger.tip_bone = side + finger + "Distal"
			if chain_finger.skeleton.find_bone(chain_finger.tip_bone) == -1:
				chain_finger.tip_bone = side + finger + "Intermediate"
			if chain_finger.skeleton.find_bone(chain_finger.tip_bone) == -1:
				# Can't find needed bones. Bail.
				continue
			
			# Keep looking and see if we can find something beyond the most
			# distant bone.
			while true:
				var child_bones : PackedInt32Array = chain_finger.skeleton.get_bone_children(
					chain_finger.skeleton.find_bone(chain_finger.tip_bone))
				if child_bones.size() == 1:
					chain_finger.tip_bone = chain_finger.skeleton.get_bone_name(child_bones[0])
				else:
					break
			
			chain_finger.tracker_object = hand_tracker_object.get_child(
				fingertip_tracking_mappings[finger])
			if side == "Left":
				chain_finger.main_axis_of_rotation = -finger_rotation_axis
				chain_finger.secondary_axis_of_rotation = Vector3(0.0, 1.0, 0.0)
			else:
				chain_finger.main_axis_of_rotation = finger_rotation_axis
				chain_finger.secondary_axis_of_rotation = Vector3(0.0, 1.0, 0.0)

			chain_finger.rotation_low = 0.05 * PI
			chain_finger.rotation_high = 1.0 * 0.99 * PI
			chain_finger.do_yaw = false
			chain_finger.do_bone_roll = false
			chain_finger.do_rotate_to_match_tracker = false
			chain_finger.do_point_tracker = false
			
			chain_finger.do_pole_targets = false
			#chain_finger.pole_direction_target = Vector3(0.0, 10.0, 0.0)
			#chain_finger.pole_direction_rotation_object = hand_tracker_object
			_ikchains.append(chain_finger)


		var chain_thumb : MediaPipeController_IKChain = \
				MediaPipeController_IKChain.new()
		chain_thumb.skeleton = get_skeleton()

		# Attempt to find finger root bone.
		chain_thumb.base_bone = side + "ThumbMetacarpal"
		#chain_thumb.base_bone = side + "ThumbProximal"
		if chain_thumb.skeleton.find_bone(chain_thumb.base_bone) == -1:
			# Finger missing entirely? Bail out.
			continue

		print(chain_thumb.skeleton.get_concatenated_bone_names())

		# Attempt to find finger most-distal bone.
		chain_thumb.tip_bone = side + "ThumbDistal"
		if chain_thumb.skeleton.find_bone(chain_thumb.tip_bone) == -1:
			chain_thumb.tip_bone = side + "ThumbIntermediate"
		if chain_thumb.skeleton.find_bone(chain_thumb.tip_bone) == -1:
			chain_thumb.tip_bone = side + "ThumbProximal"
		if chain_thumb.skeleton.find_bone(chain_thumb.tip_bone) == -1:
			# Can't find needed bones. Bail.
			continue



		chain_thumb.tracker_object = hand_tracker_object.get_child(
			fingertip_tracking_mappings["Thumb"])
		if side == "Left":
			chain_thumb.main_axis_of_rotation = -finger_rotation_axis
		else:
			chain_thumb.main_axis_of_rotation = finger_rotation_axis

		chain_thumb.rotation_low = 0.05 * PI
		chain_thumb.rotation_high = 0.5 * 0.99 * PI
		chain_thumb.do_yaw = false
		chain_thumb.do_bone_roll = false
		chain_thumb.do_rotate_to_match_tracker = false
		chain_thumb.do_pole_targets = false
		_ikchains.append(chain_thumb)


func _update_for_new_model_if_needed():
	_setup_ik_chains()
	_update_arm_rest_positions()

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

# -----------------------------------------------------------------------------
# Tracker process interop.

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

func start_tracker():
	
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

func stop_tracker():

	tracker_python_process.call_rpc_sync(
		"stop_tracker", [])

	set_status("Stopped")




func mirror_parsed_data(parsed_data : Dictionary) -> Dictionary:

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

func _process_single_packet(model : Node3D, delta : float, parsed_data : Dictionary):

	if "status" in parsed_data:
		set_status(parsed_data["status"])
		return

	if "error" in parsed_data:
		set_status("Error: " + parsed_data["error"])
		return

	set_status("Receiving tracker data")

	# -----------------
	if mirror_mode:
		parsed_data = mirror_parsed_data(parsed_data)

	if parsed_data.has("blendshapes"):
		functions_blendshapes.apply_blendshape_scale(parsed_data["blendshapes"], blendshape_scale)

		# Apply blendshape scales to MediaPipe shapes.
		functions_blendshapes.apply_blendshape_scale_offset_dict(
			parsed_data["blendshapes"],
			blendshape_scales, blendshape_offsets)

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

		var shape_dict_new = {}

		# Eye fixups. We want to apply this before it gets sent into the
		# VRM conversion so it'll affect that.
		last_parsed_data["blendshapes"] = functions_blendshapes.fixup_eyes(
			last_parsed_data["blendshapes"], eyes_prevent_opposite_directions,
			eyes_link_vertical, eyes_link_horizontal,
			eyes_link_blink)

		# Merge in MediaPipe or basic VRM blendshapes per options.
		if use_vrm_basic_shapes:
			var vrm_shapes : Dictionary = functions_blendshapes.convert_mediapipe_shapes_to_vrm_standard( \
				last_parsed_data["blendshapes"])

			# Apply blendshape scales to basic VRM shapes.
			functions_blendshapes.apply_blendshape_scale_offset_dict(
				vrm_shapes, blendshape_scales, blendshape_offsets)
			shape_dict_new.merge(
				vrm_shapes,
				true)

		if use_mediapipe_shapes:
			shape_dict_new.merge(
				last_parsed_data["blendshapes"],
				true)

		# Update a few of the progress bars.
		var shape_keys : Array = blendshape_progressbars.keys()
		for i in range(0, 5):

			var shape_name : String = \
				shape_keys[blendshape_progressbar_update_index]

			if shape_name in shape_dict_new:
				blendshape_progressbars[shape_name].value = \
					shape_dict_new[shape_name]
			else:
				blendshape_progressbars[shape_name].value = 0.0

			blendshape_progressbar_update_index += 1
			blendshape_progressbar_update_index %= len(shape_keys)

		# Apply smoothing.
		# FIXME: Parameterize.
		shape_dict_new = functions_blendshapes.apply_smoothing(
			blend_shape_last_values, shape_dict_new,
			delta, blendshape_smoothing_scale, blendshape_smoothing)

		# Blend back to a rest position if we have lost tracking.
		if frames_missing_before_spine_reset < last_parsed_data["head_missing_time"]:
			shape_dict_new = functions_blendshapes.apply_rest_shapes(
				blend_shape_last_values, delta, blend_to_rest_speed)

		functions_blendshapes.apply_animations(
			model, shape_dict_new)

		blend_shape_last_values = shape_dict_new

func process_new_packets(model, delta):
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
			_process_single_packet(model, delta, parsed_data)

		if len(packet) > 0:
			if most_recent_packet != null:
				dropped_packets += 1
			most_recent_packet = packet
		else:
			break

	# FIXME: Kind of a hack. Reprocess last parsed data again so that smoothing
	#   can continue even in the lack of actual input.
	if not most_recent_packet and last_packet_received:
		_process_single_packet(model, delta, last_packet_received.duplicate(true))

	if dropped_packets > 0:
		if dropped_packets <= 2:
			print_log(["Dropped packets (within tolerance): ", dropped_packets])
		else:
			print_log(["Dropped packets (WARNING): ", dropped_packets])

# -----------------------------------------------------------------------------
# Actual update code.


func rotate_bone_in_global_space(
	skel : Skeleton3D,
	bone_index : int,
	axis : Vector3,
	angle : float,
	relative : bool = false):

	if axis.length() <= 0.0001:
		return

	var parent_bone_index = skel.get_bone_parent(bone_index)	
	var gs_rotation = Basis(axis.normalized(),  angle).get_rotation_quaternion()
	var gs_rotation_parent = skel.get_bone_global_rest(parent_bone_index).basis.get_rotation_quaternion()
	var gs_rotation_rest = skel.get_bone_global_rest(bone_index).basis.get_rotation_quaternion()
	var bs_rotation = gs_rotation_parent.inverse() * gs_rotation * gs_rotation_rest
	
	if relative:
		skel.set_bone_pose_rotation(
			bone_index,
			skel.get_bone_pose_rotation(bone_index) * bs_rotation)
	else:
		skel.set_bone_pose_rotation(
			bone_index,
			bs_rotation)

func handle_lean(skel : Skeleton3D, angle : float):

	var current_bone : int = skel.find_bone("Head")
	var hips_bone : int = skel.find_bone("Hips")
	var bone_count : int = 0
	
	while current_bone != hips_bone and current_bone != -1:
		bone_count += 1
		current_bone = skel.get_bone_parent(current_bone)
	
	angle /= float(bone_count)
	
	current_bone = skel.find_bone("Head")
	while current_bone != hips_bone and current_bone != -1:
		rotate_bone_in_global_space(skel, current_bone, Vector3(0.0, 0.0, 1.0), angle, true)
		current_bone = skel.get_bone_parent(current_bone)

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
		return
	

	# FIXME: Hack.
	# This just moves the body based on the head position.
	var head_pos = $Head.transform.origin
	var model_pos = model_root.transform.origin
	
	if true:
		model_root.transform.origin = model_pos.lerp(head_pos, delta * hip_adjustment_speed)
		#model_root.transform.origin = head_pos
		#model_root.transform.origin.y = model_y 
		#model_root.transform.origin.y = lerp(model_pos.y, head_pos.y - 1.9, 0.01)
		
		# FIXME: Another hack!
		var head_rest_transform = get_skeleton().get_bone_global_rest(
			get_skeleton().find_bone("Head"))
		#print(head_rest_transform.origin.y)
		
		# FIXME: Hard-coded fudge factor.
		# FIXME: Why can't we just map this directly again? It looks like we're shrugging when the arms get set up wrong or something.
		model_root.transform.origin.y = lerp(
			model_pos.y, head_pos.y - head_rest_transform.origin.y + head_vertical_offset,
			clamp(hips_vertical_blend_speed * delta, 0.0, 1.0))

	process_new_packets(model_root, delta)

	var delta_scale = delta * 60.0
	if delta_scale > 1.0:
		delta_scale = 1.0
	if delta_scale < 0.01:
		delta_scale = 0.01

	if last_parsed_data:
		var parsed_data = last_parsed_data

		# FIXME: Make these adjustable.
		var model_origin_offset = Vector3(0.0, 2.0, 0.0)
		var arbitrary_scale = 1.0
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

		tracker_left = $Hand_Right
		tracker_right = $Hand_Left

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
			if parsed_data[hand_score_str] < score_threshold or not hand_tracking_enabed: # FIXME: Wrong place for the enabled check?
				parsed_data[hand_score_str] = 0.0

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
				parsed_data[hand_score_str] = pow(parsed_data[hand_score_str], score_exponent)
			
				# TODO: Replace the tracker object with just a Transform3D.
				var target_origin = model_origin_offset + (Vector3(
					hand_origin_array[0],
					hand_origin_array[1],
					hand_origin_array[2]) * hand_origin_multiplier) * arbitrary_scale
				
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
				var swap_tracker = tracker_right
				if tracker_ob == swap_tracker:
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
				if tracker_ob == swap_tracker:
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
					head_origin_array[2]) * head_origin_multiplier) * arbitrary_scale,
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

		# ---------------------------------------------------------------------
		# IK stuff starts here

		# Arm IK.

		var x_pole_dist = 10.0
		var z_pole_dist = 10.0
		var y_pole_dist = 5.0

		# FIXME: MIRRORING MESS
		var tracker_to_use_right = tracker_right
		var tracker_to_use_left = tracker_left
		tracker_to_use_right = tracker_left
		tracker_to_use_left = tracker_right
		
		# FIXME: Hack hack hack hack hack hack
		for k in range(1, 3):

			var tracker_to_use = tracker_to_use_right
			var compensation_alpha_scale = 1.0
			var pole_target_x = x_pole_dist
			if k == 2: # FIXME: Hack.
				tracker_to_use = tracker_to_use_left
				compensation_alpha_scale *= -1.0
				pole_target_x = -x_pole_dist
		
			var tracker_local_position = \
				skel.get_global_transform().inverse() * tracker_to_use.get_global_transform()
			var base_bone_position = skel.get_bone_global_pose(
				skel.find_bone(_ikchains[k].base_bone)).origin
			#print(tracker_local_position.origin.x - bone_position.x)
			
			# See if we can raise the shoulders for when arms go too far up.
			if k == 1 or k == 2:
				var chest_pose = skel.get_bone_global_pose(skel.find_bone("Chest"))

				# FIXME: We really need to parameterize this all in a less
				# silly way.
				var rotation_scale = -1.0
				var shoulder_bone = "RightShoulder"
				if tracker_to_use == tracker_right:
					shoulder_bone = "LeftShoulder"
					rotation_scale = -rotation_scale
				
				# FIXME: MIRRORING MESS
				rotation_scale = -rotation_scale
				if shoulder_bone == "RightShoulder":
					shoulder_bone = "LeftShoulder"
				else:
					shoulder_bone = "RightShoulder"
				
				var shoulder_bone_index = skel.find_bone(shoulder_bone)
				var shoulder_pose = skel.get_bone_global_pose(shoulder_bone_index)
				var chest_pose_inv = chest_pose.inverse()
				var shoulder_y = (chest_pose_inv * shoulder_pose).origin.y
				var tracker_local_chest = chest_pose_inv * tracker_local_position
				if tracker_local_chest.origin.y > shoulder_y:
					#print(tracker_local_chest.origin.y - shoulder_y)
					skel.set_bone_pose_rotation(shoulder_bone_index, 
						Quaternion(Vector3(0.0, 0.0, 1.0), (tracker_local_chest.origin.y - shoulder_y) * 2.0 * rotation_scale) *
						skel.get_bone_rest(shoulder_bone_index).basis.get_rotation_quaternion())
				
			
			
			
			var pole_target_y = -y_pole_dist
			var pole_target_z = -z_pole_dist

			# Rotate pole target upwards when the arm reaches across the
			# chest.
			if (tracker_local_position.origin.x - base_bone_position.x) * compensation_alpha_scale < 0:
				var alpha = -(tracker_local_position.origin.x - base_bone_position.x) * 3.0 * compensation_alpha_scale
				#print(alpha)
				pole_target_y = lerp(-y_pole_dist, 0.0, alpha)
				pole_target_z = lerp(-z_pole_dist, 0.0, alpha)
			
			# Move pole target backwards when the arm is lowered.
			#
			# FIXME: Hardcoded values.
			var arm_below_factor = (tracker_local_position.origin.y - base_bone_position.y) + 0.25
			arm_below_factor *= 1.0
			if arm_below_factor < 0.0:
				var alpha = arm_below_factor
				# FIXME: Hardcoded values.
				pole_target_z = lerp(pole_target_z, 100.0, alpha)
				pole_target_x = lerp(pole_target_x, 100.0 * compensation_alpha_scale, alpha)

			
			_ikchains[k].pole_direction_target = Vector3(
				pole_target_x, pole_target_y, pole_target_z)


		# Do hand stuff.
		if do_hands:
	
			var hands = [ \
				[ "Left", hand_landmarks_left, tracker_right, Basis() ], # FIXME: Remove the last value.
				[ "Right", hand_landmarks_right, tracker_left, Basis() ]]  # FIXME: Remove the last value.

			for hand in hands:
				update_hand(hand, parsed_data, skel)




	# Solve all IK chains.
	for chain in _ikchains:
		chain.do_ik_chain()



	# Lean!
	var lean_check_axis : Vector3 = (skel.transform * skel.get_bone_global_pose(skel.find_bone("Hips"))).basis * Vector3(1.0, 0.0, 0.0)
	#print(lean_check_axis)
	lean_check_axis = lean_check_axis.normalized()
	#var head_offset : Vector3 = $Head.transform.origin - (skel.transform * skel.get_bone_global_pose(skel.find_bone("Head"))).origin
	var head_offset : Vector3 = $Head.transform.origin - model_root.transform.origin
	var lean_amount : float = sin(lean_check_axis.dot(head_offset))
	handle_lean(skel, lean_amount * lean_scale)



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


func update_hand(hand, parsed_data, skel : Skeleton3D):
	var mark_counter = 0

	var flipped_hand = "left"
	if hand[0] == "Left":
		flipped_hand = "right"

	var hand_landmark_rotation_to_use = hand[3]
	var hand_landmarks = hand[1]

	for mark in parsed_data["hand_landmarks_" + flipped_hand]:
		
		# FIXME: Remove this.
		## Add any missing landmarks
		#if len(hand_landmarks) < mark_counter + 1:
			#var new_mesh_instance = MeshInstance3D.new()
			#hand[2].add_child(new_mesh_instance)
			#hand_landmarks.append(new_mesh_instance)
		
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
		if flipped_hand == "right":
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



#					# First, we need to offset the metacarpal. We can't effectively change the
#					# origin of this through rotations without affecting other bones as well.
#					# Thankfully, we can just set it to the length of the rest offset times the 
#					# direction of the tracker.
#					var metacarpal_index = skel.find_bone(hand[0] + "ThumbMetacarpal")
#					var metacarpal_rest_origin = skel.get_bone_rest(metacarpal_index).origin
#					var metacarpal_tracker_delta_world = hand[1][1].global_transform.origin - hand[1][0].global_transform.origin
#					var metacarpal_tracker_delta_global = skel.transform.basis.inverse() * metacarpal_tracker_delta_world
#					var metacarpal_tracker_delta_bone = skel.get_bone_global_pose(metacarpal_index).basis.inverse() * metacarpal_tracker_delta_global
#					print(metacarpal_tracker_delta_bone)
#					skel.set_bone_pose_position( \
#						metacarpal_index,
#						metacarpal_rest_origin.length() * metacarpal_tracker_delta_bone.normalized())


	#return

	# FIXME: I have no idea what these columns mean anymore.
	var finger_bone_array = [
		[ "IndexProximal",      5,  6, "IndexIntermediate", "IndexProximal" ],
		[ "IndexIntermediate",  6,  7, "IndexDistal",       "IndexIntermediate" ],
		[ "IndexDistal",        7,  8, "IndexDistal",       "IndexIntermediate" ],
		
		[ "MiddleProximal",     9,  10, "MiddleIntermediate", "MiddleProximal" ],
		[ "MiddleIntermediate", 10, 11, "MiddleDistal", "MiddleIntermediate" ],
		[ "MiddleDistal",       11, 12, "MiddleDistal", "MiddleIntermediate" ],

		[ "RingProximal",       13, 14, "RingIntermediate", "RingProximal" ],
		[ "RingIntermediate",   14, 15, "RingDistal", "RingIntermediate" ],
		[ "RingDistal",         15, 16, "RingDistal", "RingIntermediate" ],

		[ "LittleProximal",     17, 18, "LittleIntermediate", "LittleProximal" ],
		[ "LittleIntermediate", 18, 19, "LittleDistal", "LittleIntermediate" ],
		[ "LittleDistal",       19, 20, "LittleDistal", "LittleIntermediate" ],

		# FIXME: Metacarpal *origin* needs to change relative to hand as well.
		[ "ThumbMetacarpal",    1,  2,  "ThumbProximal", "ThumbMetacarpal" ],
		[ "ThumbProximal",      2,  3,  "ThumbDistal", "ThumbProximal" ],
		[ "ThumbDistal",        3,  4,  "ThumbDistal", "ThumbProximal" ],
	]

	# FIXME: MIRROR MESS
	if hand_landmarks == hand_landmarks_left:
		hand_landmarks = hand_landmarks_right
	elif hand_landmarks == hand_landmarks_right:
		hand_landmarks = hand_landmarks_left
			
	if len(hand_landmarks) < 21:
		return
	
	#var hand_basis = skel.get_bone_global_pose(skel.find_bone("LeftHand")).basis
	for finger_bone in finger_bone_array:

		var finger_bone_to_modify = hand[0] + finger_bone[0]
		var finger_bone_reference_1 = hand[0] + finger_bone[3]
		var finger_bone_reference_2 = hand[0] + finger_bone[4]
	
		var test_bone_name = finger_bone_to_modify
		var test_bone_index = skel.find_bone(test_bone_name)

		if test_bone_index == -1:
			continue
		if skel.find_bone(finger_bone_reference_2) == -1:
			continue

		# Try to find missing "tip" bones like on Exo's model.
		if skel.find_bone(finger_bone_reference_1) == -1:
			var bone_index_before_missing : int = skel.find_bone(finger_bone_reference_2)
			var bone_children : PackedInt32Array = skel.get_bone_children(bone_index_before_missing)
			if len(bone_children) == 1:
				finger_bone_reference_1 = skel.get_bone_name(bone_children[0])
			else:
				continue



		skel.reset_bone_pose(test_bone_index)
			
		var test_bone_pt_2 = hand_landmarks[finger_bone[2]].global_transform.origin
		var test_bone_pt_1 = hand_landmarks[finger_bone[1]].global_transform.origin
		
		
		var skel_inverse = skel.transform.inverse()
		var test_bone_vec_global = (skel_inverse * test_bone_pt_2 - skel_inverse * test_bone_pt_1).normalized()

		var current_finger_vec_global = \
			(skel.get_bone_global_pose(skel.find_bone(finger_bone_reference_1)).origin -
			skel.get_bone_global_pose(skel.find_bone(finger_bone_reference_2)).origin).normalized()
		
		var angle_between = acos(test_bone_vec_global.dot(current_finger_vec_global))
		var rotation_axis_global = test_bone_vec_global.cross(current_finger_vec_global).normalized()
		
		var rotation_axis_local = \
			skel.get_bone_global_pose(skel.get_bone_parent(test_bone_index)).basis.inverse() * \
			rotation_axis_global

		var global_rotation_from_rest = skel.get_bone_global_rest(test_bone_index).basis * rotation_axis_local
		
		var hand_index = 0
		if flipped_hand == "left":
			hand_index = 1

		if hand_time_since_last_update[hand_index] > arm_reset_time:
			#skel.set_bone_pose_rotation(test_bone_index,
			#	skel.get_bone_pose(test_bone_index).basis.slerp(Basis(), arm_reset_speed))
			skel.set_bone_pose_rotation(test_bone_index, Basis())
		else:
			rotate_bone_in_global_space(skel, test_bone_index, global_rotation_from_rest, -angle_between)
		
