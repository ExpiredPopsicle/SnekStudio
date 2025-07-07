extends Mod_Base



func _process(delta: float) -> void:
	var tracker_dict : Dictionary = get_global_mod_data("trackers")
	var time = Time.get_unix_time_from_system() * 3;

	$Throttle.transform.basis = Basis(Vector3(1.0, 0.0, 0.0), -0.5 +  cos(time) * 0.5)


	$Stick.transform.basis = \
		Basis(Vector3(1.0, 0.0, 0.0), cos(time) * 0.25) * \
		Basis(Vector3(0.0, 0.0, 1.0), sin(time * 0.3) * 0.5)



	tracker_dict["hand_left"]["transform"] = %Hand_Left.global_transform
	tracker_dict["hand_right"]["transform"] = %Hand_Right.global_transform
