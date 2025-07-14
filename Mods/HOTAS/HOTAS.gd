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

	#$Stick.transform.basis = \
		#Basis(Vector3(1.0, 0.0, 0.0), cos(time) * 0.25) * \
		#Basis(Vector3(0.0, 0.0, 1.0), sin(time * 0.3) * 0.5)
	#%Hand_Right.transform.origin = Vector3(0.0, cos(time)* 0.2 + 0.2, 0.0)

	if not tracker_dict["hand_left"]["active"]:
		tracker_dict["hand_left"]["transform"] = %Hand_Left.global_transform
	if not tracker_dict["hand_right"]["active"]:
		tracker_dict["hand_right"]["transform"] = %Hand_Right.global_transform
