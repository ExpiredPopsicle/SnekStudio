extends Mod_Base

var last_model_height: float = -1.0

var adjust_zoom: bool = true
var adjust_position: bool = true

func _ready() -> void:
	add_tracked_setting("adjust_zoom", "Adjust Zoom");
	add_tracked_setting("adjust_position", "Adjust Position");

func _process(_delta: float) -> void:
	if last_model_height == -1.0:
		last_model_height = get_model_height_scale()
	else:
		var new_model_height: float = get_model_height_scale()

		var cameraboom: Node3D = get_app().get_cameraboom()
		if adjust_position:
			cameraboom.transform.origin *= new_model_height / last_model_height
		if adjust_zoom:
			cameraboom.zoom_camera(new_model_height / last_model_height)

		last_model_height = new_model_height
