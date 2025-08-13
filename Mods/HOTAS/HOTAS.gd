extends Mod_Base

var last_input_stick : Vector3 = Vector3(0.0, 0.0, 0.0)

var last_input_throttle : float = 0.0

func _process(delta: float) -> void:

	#for device_index : int in Input.get_connected_joypads():
		#print(device_index)
		#print(Input.get_joy_name(device_index))
		#print(Input.get_joy_info(device_index))
		#
		##for k in range(0, 10):
			##print(k, ": ", Input.get_joy_axis(device_index, k))
#
		#var buttons : Array = []
		#for k in range(0, JOY_BUTTON_SDL_MAX):
			#buttons.push_back(Input.is_joy_button_pressed(device_index, k))
		#print(buttons)


	var tracker_dict : Dictionary = get_global_mod_data("trackers")
	var time = Time.get_unix_time_from_system() * 3;



	var device_index : int = 0
	var stick_pitch_axis : int = JoyAxis.JOY_AXIS_LEFT_Y
	var stick_roll_axis : int = JoyAxis.JOY_AXIS_LEFT_X
	var stick_yaw_axis : int = JoyAxis.JOY_AXIS_RIGHT_Y


	var throttle_axis : int = JoyAxis.JOY_AXIS_RIGHT_X
	var new_input_throttle = -Input.get_joy_axis(device_index, throttle_axis)
	var current_input_throttle : float = lerp(last_input_throttle, new_input_throttle, 0.5)

	last_input_throttle = current_input_throttle

	#$Throttle.transform.basis = Basis(Vector3(1.0, 0.0, 0.0), -0.5 +  cos(time) * 0.5)
	$Throttle.transform.basis = Basis.from_euler(Vector3(current_input_throttle, 0.0, 0.0))


	#last_input_stick
	var new_input_stick : Vector3 = Vector3(\
		-Input.get_joy_axis(device_index, stick_pitch_axis),\
		Input.get_joy_axis(device_index, stick_roll_axis),
		-Input.get_joy_axis(device_index, stick_yaw_axis))

	# FIXME: Hardcoded blend speed.
	var current_input_stick : Vector3 = lerp(last_input_stick, new_input_stick, 0.5)

	last_input_stick = current_input_stick

	$Stick.transform.basis = Basis.from_euler(
		Vector3(current_input_stick.x, current_input_stick.z, current_input_stick.y),
		EULER_ORDER_XZY)


	$FlightStick/AnimationTree.set("parameters/blend_position", Vector2(
		current_input_stick.y, current_input_stick.x))

	$Throttle2/AnimationTree.set("parameters/throttle_amount/blend_position", last_input_throttle);

	#$Stick.transform.basis = \
		#Basis(Vector3(1.0, 0.0, 0.0), cos(time) * 0.25) * \
		#Basis(Vector3(0.0, 0.0, 1.0), sin(time * 0.3) * 0.5)
	#%Hand_Right.transform.origin = Vector3(0.0, cos(time)* 0.2 + 0.2, 0.0)

	var hand_right : Node3D = $FlightStick.find_child("hand_right")
	var hand_left : Node3D = $Throttle2.find_child("hand_left")


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



	#if not tracker_dict["hand_left"]["active"]:
	#	tracker_dict["hand_left"]["transform"] = hand_right.global_transform
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

	#for k in range(0, JoyButton.JOY_BUTTON_SDL_MAX):
		#if Input.is_joy_button_pressed(0, k):
			#print("pressed: ", k)
	
	# FIXME: Hardcoded values.
	if Input.is_joy_button_pressed(device_index, 4):
		$Throttle2/ButtonAnimationPlayer.play("Button5")
	else:
		$Throttle2/ButtonAnimationPlayer.play("RESET")
