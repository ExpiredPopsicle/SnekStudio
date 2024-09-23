extends Node3D

func set_camera_rotation(pitch : float, yaw : float):
	set_rotation_degrees(Vector3(pitch, yaw, 0.0))
	
func get_camera_pitch():
	return get_rotation_degrees()[0]
	
func get_camera_yaw():
	return get_rotation_degrees()[1]

func rotate_camera_relative(pitch : float, yaw : float):
	set_camera_rotation(
		get_camera_pitch() + pitch,
		get_camera_yaw() + yaw)

func pan_camera(horizontal : float, vertical : float):
	var right_global = Vector3(1.0, 0.0, 0.0).rotated(Vector3(0.0, 1.0, 0.0), get_camera_yaw() * PI / 180.0)
	var up_global = Vector3(0.0, 1.0, 0.0).rotated(Vector3(1.0, 0.0, 0.0), get_camera_pitch() * PI / 180.0)
	var zoom_scale = get_camera_distance()
	transform.origin += right_global * horizontal * zoom_scale
	transform.origin += up_global * vertical * zoom_scale

func get_camera_position():
	return transform.origin
	
func set_camera_position(pos):
	transform.origin = pos

func get_camera_distance():
	var camera_distance = $Camera3D.transform.origin[2]
	return camera_distance
	
func set_camera_distance(new_camera_distance):
	$Camera3D.transform.origin[2] = new_camera_distance
	
func zoom_camera(offset : float):
	var camera_distance = get_camera_distance()
	camera_distance -= offset
	if camera_distance < 0.01:
		camera_distance = 0.01
	set_camera_distance(camera_distance)


func get_camera():
	return $Camera3D

func save_settings():
	var output_dict = {}
	output_dict["yaw"] = get_camera_yaw()
	output_dict["pitch"] = get_camera_pitch()
	output_dict["distance"] = get_camera_distance()
	output_dict["position"] = [
		get_camera_position()[0],
		get_camera_position()[1],
		get_camera_position()[2]]
	return output_dict
	
func load_settings(settings_dict):
	set_camera_rotation(settings_dict["pitch"], settings_dict["yaw"])
	set_camera_distance(settings_dict["distance"])
	var new_camera_position = Vector3(
		settings_dict["position"][0],
		settings_dict["position"][1],
		settings_dict["position"][2])
	set_camera_position(new_camera_position)
	
func reset_to_default():
	transform = Transform3D(Basis(), Vector3(0.0, 1.7, 0.0))
	set_camera_distance(4.5)
	
	
	
	
	
	
