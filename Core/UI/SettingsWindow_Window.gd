extends BasicSubWindow

func _ready() -> void:
	register_serializable_subwindow()
	%resolutionSet.pressed.connect((func (w, h: LineEdit):
		if w.text.is_valid_int() && h.text.is_valid_int():
			_get_app_root().confirm_window_size(Vector2i(int(w.text), int(h.text)))
			%width.remove_theme_color_override("font_color")
			%height.remove_theme_color_override("font_color")
		elif w.text == "" && h.text == "":
			_get_app_root().deserialize_settings({"window_size_set": false})
		else:
			%width.add_theme_color_override("font_color", Color(1, 0, 0))
			%height.add_theme_color_override("font_color", Color(1, 0, 0))
	).bind(%width, %height))
	
	super._ready()

func settings_changed_from_app():
	var app = _get_app_root()
	var settings_dict = app.serialize_settings(true, false)
	
	if "transparent_window" in settings_dict:
		%CheckBox_TransparentBackground.button_pressed = settings_dict["transparent_window"]	
	if "background_color" in settings_dict:
		%ColorPickerButton_BackgroundColor.color = Color.html(settings_dict["background_color"])
	if "hide_window_decorations" in settings_dict:
		%CheckBox_HideWindowDecorations.button_pressed = settings_dict["hide_window_decorations"]
	if "vsync_mode" in settings_dict:
		%OptionButton_VSyncMode.selected = settings_dict["vsync_mode"]
	if "window_size_set" in settings_dict:
		%Checkbox_FixedSize.button_pressed = settings_dict["window_size_set"]
	if "window_size" in settings_dict:
		%width.text = str(settings_dict["window_size"][0])
		%height.text = str(settings_dict["window_size"][1])

func show_window():
	super.show_window()
	settings_changed_from_app()	

func update_to_app():
	
	var app = _get_app_root()
	
	var settings_dict = {}

	settings_dict["transparent_window"] = %CheckBox_TransparentBackground.button_pressed
	settings_dict["background_color"] = %ColorPickerButton_BackgroundColor.color.to_html()
	settings_dict["hide_window_decorations"] = %CheckBox_HideWindowDecorations.button_pressed
	settings_dict["vsync_mode"] = %OptionButton_VSyncMode.selected
	settings_dict["window_size_set"] = %Checkbox_FixedSize.button_pressed
	
	app.deserialize_settings(settings_dict)

func _any_value_changed(_value):
	update_to_app()
