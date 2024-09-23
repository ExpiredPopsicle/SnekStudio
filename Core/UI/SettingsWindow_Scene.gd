extends BasicSubWindow

func settings_changed_from_app():
	var app = _get_app_root()
	var settings_dict = app.serialize_settings(true, false)

func show_window():
	super.show_window()
	settings_changed_from_app()

func update_to_app():
	
	var app = _get_app_root()
	
	var settings_dict = {}

	app.deserialize_settings(settings_dict)

func _any_value_changed(_value):
	update_to_app()

func _handle_light_value_changed(value):

	_any_value_changed(value)
	
