extends BasicSubWindow

func _ready() -> void:
	register_serializable_subwindow()
	super._ready()

func settings_changed_from_app():
	var app = _get_app_root()
	var settings_dict = app.serialize_settings(true, false)
	
	if "hide_window_elements" in settings_dict:
		%OptionButton_HideWindowElements.selected = settings_dict["hide_window_elements"]
	if "background_color" in settings_dict:
		%ColorPickerButton_BackgroundColor.color = Color.html(settings_dict["background_color"])
	if "vsync_mode" in settings_dict:
		%OptionButton_VSyncMode.selected = settings_dict["vsync_mode"]

func show_window():
	super.show_window()
	settings_changed_from_app()	

func update_to_app():
	
	var app = _get_app_root()
	
	var settings_dict = {}

	settings_dict["hide_window_elements"] = %OptionButton_HideWindowElements.selected
	settings_dict["background_color"] = %ColorPickerButton_BackgroundColor.color.to_html()
	settings_dict["vsync_mode"] = %OptionButton_VSyncMode.selected
	
	app.deserialize_settings(settings_dict)

func _any_value_changed(_value):
	update_to_app()
