extends Mod_Base

var last_model_height: float = -1.0

func _process(delta: float) -> void:
	if last_model_height == -1.0:
		last_model_height = get_model_height_scale()
	else:
		var new_model_height: float = get_model_height_scale()

		var cameraboom: Node3D = get_app().get_cameraboom()
		cameraboom.transform.origin *= new_model_height / last_model_height
		cameraboom.zoom_camera(new_model_height / last_model_height)

		last_model_height = new_model_height
