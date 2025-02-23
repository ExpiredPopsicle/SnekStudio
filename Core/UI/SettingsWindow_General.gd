extends BasicSubWindow

func _ready() -> void:
	register_serializable_subwindow()
	super._ready()

func settings_changed_from_app() -> void:
	var settings : Dictionary = _get_app_root().serialize_settings(true, false)

	var fov : float = settings["camera"]["fov"]
	%BasicSliderWithNumber_CameraFOV.set_value_no_signal(fov)

func settings_changed_from_ui() -> void:
	var app = _get_app_root()

	var settings_dict : Dictionary = _get_app_root().serialize_settings(true, false)

	settings_dict["camera"]["fov"] = %BasicSliderWithNumber_CameraFOV.value

	app.deserialize_settings(settings_dict)

# ------------------------------------------------------------------------------
# Signals from various widgets indicating something has changed

func _on_basic_slider_with_number_camera_fov_value_changed(_value: Variant) -> void:
	settings_changed_from_ui()
