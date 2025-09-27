extends Mod_Base

var last_input_stick : Vector3 = Vector3(0.0, 0.0, 0.0)
var last_input_throttle : float = 0.0

## Distance between the two models.
var model_distance : float = 0.5

## Height of the models off the floor.
var model_height : float = 2.8

## Horizontal shift.
var model_xoffset : float = 0.0

## Depth shift.
var model_zoffset : float = 0.0

var _device_list : Array = []
var joystick_device : Array = [""]
var throttle_device : Array = [""]

var stick_x_axis : int = JoyAxis.JOY_AXIS_LEFT_X
var stick_y_axis : int = JoyAxis.JOY_AXIS_LEFT_Y
var throttle_axis : int = JoyAxis.JOY_AXIS_RIGHT_Y

func _ready() -> void:

	add_tracked_setting(
		"model_distance", "Distance between throttle and stick",
		{ "min" : 0.0, "max" : 5.0, "step" : 0.01 })
	add_tracked_setting(
		"model_height", "Height of the throttle and stick",
		{ "min" : 0.0, "max" : 10.0, "step" : 0.01 })
	add_tracked_setting(
		"model_xoffset", "Model X offset (left/right)",
		{ "min" : -10.0, "max" : 10.0, "step" : 0.01 })
	add_tracked_setting(
		"model_zoffset", "Model Z offset (forward/backward)",
		{ "min" : -10.0, "max" : 10.0, "step" : 0.01 })

	# Enumerate attached joystick devices.
	var connected_device_indices : Array = Input.get_connected_joypads()
	for device_index : int in connected_device_indices:
		_device_list.push_back(Input.get_joy_name(device_index))

	# Set devices as default if any are found.
	if len(_device_list):
		joystick_device = [_device_list[0]]
		throttle_device = [_device_list[0]]

	add_tracked_setting(
		"joystick_device", "Joystick Device",
		{"values" : _device_list,
		 "combobox" : true})

	add_tracked_setting(
		"throttle_device", "Throttle Device",
		{"values" : _device_list,
		 "combobox" : true})

	add_tracked_setting("stick_x_axis", "Stick X axis")
	add_tracked_setting("stick_y_axis", "Stick Y axis")
	add_tracked_setting("throttle_axis", "Throttle axis")

func _process(delta: float) -> void:

	$FlightStick.transform.origin.x = -model_distance / 2.0
	$Throttle2.transform.origin.x = model_distance / 2.0

	$FlightStick.transform.origin.y = model_height / 2.0
	$Throttle2.transform.origin.y = model_height / 2.0

	$FlightStick.transform.origin.x += model_xoffset
	$Throttle2.transform.origin.x += model_xoffset

	$FlightStick.transform.origin.z = model_zoffset
	$Throttle2.transform.origin.z = model_zoffset

	var tracker_dict : Dictionary = get_global_mod_data("trackers")
	var time = Time.get_unix_time_from_system() * 3;

	var device_index : int = _device_list.find(joystick_device[0])

	if device_index != -1:

		var new_input_throttle = -Input.get_joy_axis(device_index, throttle_axis)
		var current_input_throttle : float = lerp(last_input_throttle, new_input_throttle, 0.5)

		last_input_throttle = current_input_throttle

		$Throttle.transform.basis = Basis.from_euler(Vector3(current_input_throttle, 0.0, 0.0))

		var new_input_stick : Vector3 = Vector3(\
			-Input.get_joy_axis(device_index, stick_y_axis),\
			Input.get_joy_axis(device_index, stick_x_axis), 0.0)

		# FIXME: Hardcoded blend speed.
		var current_input_stick : Vector3 = lerp(last_input_stick, new_input_stick, 0.5)

		last_input_stick = current_input_stick

		$FlightStick/AnimationTree.set(
			"parameters/blend_position",
			Vector2(current_input_stick.y, current_input_stick.x))

		$Throttle2/AnimationTree.set(
			"parameters/throttle_amount/blend_position",
			last_input_throttle);

		var hand_right : Node3D = $FlightStick.find_child("hand_right")
		var hand_left : Node3D = $Throttle2.find_child("hand_left")

		# FIXME: De-duplicate this array from all over the place.
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

		for side in ["left", "right"]:
			if not tracker_dict["hand_" + side]["active"]:
				
				var hand_tracker : Node3D = hand_right
				if side == "left":
					hand_tracker = hand_left
				
				tracker_dict["hand_" + side]["active"] = true
				tracker_dict["hand_" + side]["transform"] = hand_tracker.global_transform

				for tracker_name in mediapipe_hand_landmark_names:
					var controller_node : Node3D = $FlightStick
					if side == "left":
						controller_node = $Throttle2
					var tracker_node : Node3D = controller_node.find_child(tracker_name)
					if tracker_node:
						tracker_dict["finger_positions"][side + "_" + tracker_name] = tracker_node.global_transform.origin
