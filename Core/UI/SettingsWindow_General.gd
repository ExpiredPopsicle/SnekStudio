extends BasicSubWindow

func _get_app_root():
	return get_node("../../..")

func settings_changed_from_app():
	pass

func settings_changed_from_ui():
	pass

# ------------------------------------------------------------------------------
# Signals from various widgets indicating something has changed

func _on_button_ok_pressed():
	close_window()

func _on_button_apply_pressed():
	pass

func _on_button_cancel_pressed():
	close_window()

func show_window():
	super.show_window()
