extends Mod_Base
class_name DisabledMod

var saved_settings: Dictionary = {}

func save_before(_settings_current : Dictionary):
	_settings_current["saved_settings"] = saved_settings

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	saved_settings = _settings_new["saved_settings"]

func _create_settings_window():
	var ui = load(
		get_script().resource_path.get_base_dir() + "/" +
		"UI/DisabledMod_Settings.tscn").instantiate()
	return ui

func update_settings_ui(_ui_window = null):
	var settings_window: Control = get_settings_window()
	var text_area: TextEdit = settings_window.get_node("VBoxContainer/SettingsJSONDisplay")
	text_area.set_text(JSON.stringify(saved_settings, "    "))
