extends VBoxContainer

signal settings_modified

func wrap_signal():
	settings_modified.emit()

func _on_value_bit_only_redeem_toggled(_button_pressed):
	wrap_signal()

func _on_value_objects_per_bit_value_changed(_value):
	wrap_signal()

func _on_value_redeem_name_text_changed():
	wrap_signal()

func _on_value_count_mulitplier_value_changed(_value):
	wrap_signal()

func _on_value_throwable_list_multi_selected(_index, _selected):
	wrap_signal()
