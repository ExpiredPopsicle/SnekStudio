extends Control
class_name ActionUI

@export var ui_item : Dictionary = {}
@export var currently_setting : bool = false

signal on_change_item(action : int, item : Dictionary, old_item : Dictionary)

func set_item(item : Dictionary) -> void:
	# Bind to the UI item.
	ui_item = item
	
	var action : String = item["action_name"]
	if item["key"] != -1:
		var key_code : Key = item["key"]
		#var has_mod : bool  = item["modifier"]
		#var mod_mask : int = item["modifier_mask"]
		#
		var input_event = InputEventKey.new()
		input_event.physical_keycode = key_code
		#input_event.get_modifiers_mask()
		#if has_mod:
			#if mod_mask & KeyModifierMask.KEY_CODE_MASK:
				#pass
		var display_bind = OS.get_keycode_string(
			DisplayServer.keyboard_get_label_from_physical(
				input_event.get_physical_keycode_with_modifiers()))
		
		%KeybindDisplay.text = display_bind
		
	%ActionNameTxt.text = action
	emit_signal("on_change_item", ChangeAction.INITIAL, item, {})

func blank_item() -> void:
	ui_item = {
		"key": -1,
		"action_name": ""
	}

func _on_action_name_txt_text_changed(new_text : String) -> void:
	var old_item = ui_item.duplicate()
	ui_item["action_name"] = new_text
	emit_signal("on_change_item", ChangeAction.ACTION_NAME, ui_item, old_item)


func _on_delete_btn_pressed() -> void:
	emit_signal("on_change_item", ChangeAction.DELETE, ui_item, {})
	queue_free()


func _on_reset_btn_pressed() -> void:
	var old_item = ui_item.duplicate()
	ui_item["key"] = -1
	emit_signal("on_change_item", ChangeAction.KEY_BIND, ui_item, old_item)
	%KeybindDisplay.text = "Empty"
