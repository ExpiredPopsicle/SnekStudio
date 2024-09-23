extends BasicSubWindow

func _get_app_root():
	return get_node("../../..")

func settings_changed_from_app():
	var app_root = _get_app_root()
	var settings_dict = app_root.serialize_settings(true, false)

func settings_changed_from_ui():
	var app_root = _get_app_root()
	var settings_dict = app_root.serialize_settings(true, false)

	# TODO: Apply settings?
	
	# Read settings back immediately.
	settings_changed_from_app()

# ------------------------------------------------------------------------------
# Signals from various widgets indicating something has changed

func _on_button_ok_pressed():
	settings_changed_from_ui()
	close_window()

func _on_button_apply_pressed():
	settings_changed_from_ui()

func _on_button_cancel_pressed():
	close_window()
	settings_changed_from_app()

func show_window():
	settings_changed_from_app()
	super.show_window()
