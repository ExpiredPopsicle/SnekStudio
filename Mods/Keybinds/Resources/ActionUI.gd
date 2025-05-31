extends Control
class_name ActionUI

var ui_item : Dictionary = {}
var old_item : Dictionary = {}
var currently_setting : bool = false

signal on_change_item(action : int, item : Dictionary, old_item : Dictionary)

## Load the item to the UI elements.
## Keybind does not have to be set, but must be -1 if not set.
func set_item(item : Dictionary) -> void:
	# Bind to the UI item.
	ui_item = item

	var action : String = item["action_name"]
	if item["key"] != -1:
		_set_key_bind_display(item)

	%ActionNameTxt.text = action
	emit_signal("on_change_item", ChangeAction.INITIAL, item, {})

func _set_key_bind_display(item : Dictionary):
	var key_code : Key = item["key"]
	var alt_pressed = item.get("modifier_alt", false)
	var ctrl_pressed = item.get("modifier_ctrl", false)
	var meta_pressed = item.get("modifier_meta", false)
	
	var input_event = InputEventKey.new()
	input_event.physical_keycode = key_code
	input_event.alt_pressed = alt_pressed
	input_event.ctrl_pressed = ctrl_pressed
	input_event.meta_pressed = meta_pressed
	#input_event.get_modifiers_mask()
	#if has_mod:
		#if mod_mask & KeyModifierMask.KEY_CODE_MASK:
			#pass
	var display_bind = OS.get_keycode_string(
		DisplayServer.keyboard_get_label_from_physical(
			input_event.get_physical_keycode_with_modifiers()))

	%KeybindDisplay.text = display_bind

## Set the UI item to be blank.
func blank_item() -> void:
	ui_item = {
		"key": -1,
		"modifier_alt": false,
		"modifier_ctrl": false,
		"modifier_meta": false,
		"action_name": ""
	}

func _on_action_name_txt_text_changed(new_text : String) -> void:
	old_item = ui_item.duplicate()
	ui_item["action_name"] = new_text
	emit_signal("on_change_item", ChangeAction.ACTION_NAME, ui_item, old_item)

func _on_delete_btn_pressed() -> void:
	emit_signal("on_change_item", ChangeAction.DELETE, ui_item, {})
	queue_free()

func _on_reset_btn_pressed() -> void:
	old_item = ui_item.duplicate()
	ui_item["key"] = -1
	emit_signal("on_change_item", ChangeAction.KEY_BIND, ui_item, old_item)
	%KeybindDisplay.text = "Empty"

func _input(event : InputEvent):
	if currently_setting and event is InputEventKey:
		var key_event : InputEventKey = event
		if key_event.physical_keycode == KEY_CTRL \
			or key_event.physical_keycode == KEY_ALT \
			or key_event.physical_keycode == KEY_META:
			# Default, probably only has modifier applied.
			return
		currently_setting = false
		old_item = ui_item.duplicate()
		ui_item["key"] = event.physical_keycode
		ui_item["modifier_alt"] = event.alt_pressed
		ui_item["modifier_ctrl"] = event.ctrl_pressed
		ui_item["modifier_meta"] = event.meta_pressed
		%SetBtn.text = "Set"
		emit_signal("on_change_item", ChangeAction.KEY_BIND, ui_item, old_item)
		_set_key_bind_display(ui_item)

func _on_set_btn_pressed() -> void:
	currently_setting = true
	%SetBtn.text = "Press Keys"
