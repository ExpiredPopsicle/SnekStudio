extends BasicSubWindow

@onready var option_button_res: OptionButton = $GridContainer/OptionButtonRes
@onready var check_button_custom_res: CheckButton = $GridContainer/CheckButtonCustomRes
@onready var vector_setting_widget: VectorSettingWidget = $GridContainer/HBoxContainer/VectorSettingWidget
@onready var option_button_msaa: OptionButton = $GridContainer/OptionButtonMSAA
@onready var option_button_filter: OptionButton = $GridContainer/OptionButtonFilter
@onready var option_button_debug_draw: OptionButton = $GridContainer/OptionButtonDebugDraw

func _ready() -> void:
	register_serializable_subwindow()
	super._ready()
	
	for dd in ClassDB.class_get_enum_constants("Viewport", "DebugDraw"):
		$GridContainer/OptionButtonDebugDraw.add_item(dd)

func show_window():
	super.show_window()
	settings_changed_from_app()

func settings_changed_from_app():
	var app = _get_app_root()
	var settings_dict = app.serialize_settings(true, false)
	if "subviewport_settings" in settings_dict:
		var subviewport_settings: Dictionary = settings_dict["subviewport_settings"]
		
		print("SUBVIEWPORT SETTINGS -------------")
		print(subviewport_settings)
		
		var chosen_res_options = ["Fit to window",
								"1152x648 (default)",
								"1280x720",
								"1440x900",
								"1920x1080"]
		
		var filter_options = ["Nearest",
							"Linear"]
		
		if "chosen_res" in subviewport_settings:
			option_button_res.selected = chosen_res_options.find(subviewport_settings["chosen_res"])
		if "custom_res_enabled" in subviewport_settings:
			check_button_custom_res.set_pressed_no_signal(subviewport_settings["custom_res_enabled"])
		if "custom_res_value" in subviewport_settings:
			var vec_string: String = subviewport_settings["custom_res_value"]
			var vec2 := Vector2i(vec_string.get_slice(",", 0).trim_prefix("(").to_int(),
								vec_string.get_slice(",", 1).trim_suffix(")").to_int())
			vector_setting_widget.set_value_no_signal(Vector3(float(vec2.x), float(vec2.y), 0.0))
		if "msaa" in subviewport_settings:
			option_button_msaa.selected = subviewport_settings["msaa"]
		if "filter" in subviewport_settings:
			option_button_filter.selected = filter_options.find(subviewport_settings["filter"])
		if "debug_draw" in subviewport_settings:
			option_button_debug_draw.selected = subviewport_settings["debug_draw"]

func update_to_app():
	var app = _get_app_root()
	
	var settings_dict = {}
	var subviewport_data = {}
	
	var chosen_res: String = option_button_res.get_item_text(option_button_res.get_selected_id())
	var custom_res_enabled: bool = check_button_custom_res.button_pressed
	var custom_res_value := Vector2i(int(vector_setting_widget.value.x),
									int(vector_setting_widget.value.y))
	var msaa: int = option_button_msaa.get_selected_id()
	var filter: String = option_button_filter.get_item_text(option_button_filter.get_selected_id())
	var debug_draw: int = option_button_debug_draw.get_selected_id()
	
	subviewport_data["chosen_res"] = chosen_res
	subviewport_data["custom_res_enabled"] = custom_res_enabled
	subviewport_data["custom_res_value"] = custom_res_value
	subviewport_data["msaa"] = msaa
	subviewport_data["filter"] = filter
	subviewport_data["debug_draw"] = debug_draw
	
	settings_dict["subviewport_settings"] = subviewport_data
	
	app.deserialize_settings(settings_dict)

func _any_value_changed(_value):
	update_to_app()

func _on_button_set_custom_res_pressed() -> void:
	update_to_app()
