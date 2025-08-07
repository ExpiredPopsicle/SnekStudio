extends Node
class_name KeybindSettingUI

@export var base : PackedScene
@export var attached : Control
@export var has_set_initial : bool = false

signal on_change_item(action : int, item : Dictionary, old_item : Dictionary)

## Resets initial state and removes all UI items.
func reset() -> void:
	has_set_initial = false
	for child in attached.get_children():
		attached.remove_child(child)

## ONLY used for the first initial ready setup of key actions.
func set_initial_key_actions(new_key_actions : Array) -> void:
	if has_set_initial:
		return
	
	_build_ui(new_key_actions)
	has_set_initial = true

func _build_ui(key_actions : Array): 
	for item in key_actions:
		add_key_action(item)

## Create an action UI element for a particular item.
## If the item is null, it will create a blank item.
func add_key_action(item):
	var new_item : ActionUI = base.instantiate()
	new_item.on_change_item.connect(_on_change_item)
	if item != null:
		new_item.set_item(item)
	else:
		new_item.blank_item()
	new_item.visible = true
	attached.add_child(new_item)

func _on_change_item(action : int, item : Dictionary, old_item : Dictionary):
	emit_signal("on_change_item", action, item, old_item)
