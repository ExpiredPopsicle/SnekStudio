extends Mod_Base
class_name Keybinds

# List of actions and keys, that will be imported to the input map...?
# [ 
#  { 
#   "key" : number_for_key_representation
#   "action_name" : "action_name_here"
#  }
#
@export var panel : Control = null

var key_actions : Array = []
var settings_ui : KeybindSettingUI

func _ready() -> void:
	_add_actions()
	
	# Remove the temp panel and attach the children to the 
	# settings window! This way we aren't messing around with
	# tracked settings, and instead are simply loading our own UI.
	remove_child(panel)
	
	var new_keybind_button : Button = Button.new()
	new_keybind_button.text = "New Keybind"
	get_settings_window().add_child(new_keybind_button)
	new_keybind_button.pressed.connect(_new_keybind)
	
	var first_child = panel.get_child(0)
	settings_ui = first_child
	panel.remove_child(settings_ui)
	get_settings_window().add_child(settings_ui)
	settings_ui.on_change_item.connect(on_ui_change_item)
	settings_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	

func _new_keybind() -> void:
	settings_ui.add_key_action(null)

func on_ui_change_item(action : int, item : Dictionary, old_item : Dictionary):
	if action == ChangeAction.ACTION_NAME or action == ChangeAction.KEY_BIND:
		# Updates should be fine as there is a reference to the item.
		# We only have to check if there isn't an item, then add an item.
		if action == ChangeAction.ACTION_NAME and _get_key_action_by_item(item) == null:
			key_actions.append(item)
			_create_action(item)
		else:
			_update_action(item, old_item)
	if action == ChangeAction.DELETE:
		# Remove the existing item from our key_actions.
		_remove_key_action_by_item(item)
		
		# Adjust our input map.
		var action_event_count = len(InputMap.action_get_events(item["action_name"]))
		if action_event_count <= 1:
			# Delete the entire action.
			print("Deleting the entire action for %s" % item["action_name"])
			InputMap.erase_action(item["action_name"])
		else:
			# Delete just our event.
			var key_event = _create_key_event(item["key"])
			if key_event != null:
				print("Deleting just our event for %s" % item["action_name"])
				InputMap.action_erase_event(item["action_name"], key_event)
		
	save_settings()
	
func _create_key_event(key : int) -> InputEventKey:
	if key == -1:
		return null
	var new_key_event = InputEventKey.new()
	new_key_event.physical_keycode = key
	return new_key_event
	
func _create_action(item : Dictionary) -> void:
	var action = item["action_name"]
	
	# Do not create empty.
	if action == "":
		return
		
	print("Creating new action and associated event %s" % action)
	var key_event = _create_key_event(item["key"])
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	else:
		# Clear existing events for the action
		InputMap.action_erase_events(action)
	
	# Always add the event to the action, if there is no action it was made.
	# existing events for the action have been cleared.	
	InputMap.action_add_event(action, key_event)
	
func _update_action(new_item : Dictionary, old_item : Dictionary) -> void:
	if new_item["action_name"] != old_item["action_name"]:
		print("New item action name (%s) is different from the old (%s)." % [new_item["action_name"], old_item["action_name"]])
		InputMap.erase_action(old_item["action_name"])
		_create_action(new_item)
	elif new_item["key"] != old_item["key"]:
		print("New item key is not the same as the old key.")
		if old_item["key"] != -1:
			print("Old item key is not unassigned. Removing the old item key event.")
			var old_key_event = _create_key_event(old_item["key"])
			InputMap.action_erase_event(new_item["action_name"], old_key_event)

		print("Adding event for the action name with the correct key.")
		
		# We only want to create a new key event if it wasn't reset.
		var new_key_event = _create_key_event(new_item["key"])
		if new_key_event != null:
			InputMap.action_add_event(new_item["action_name"], new_key_event)

func _input(event : InputEvent) -> void:
	if InputMap.has_action("ping") and event.is_action_pressed("ping"):
		print("pong!")
	#if event is InputEventKey:
		#print("Key pressed")
		##if event.physical_keycode in key_actions:
		#var value = _get_key_action_by_input(event.physical_keycode)
		#if value == null:
			#return
		#print(value["action_name"])
		
func _get_key_action_by_input(key : Key):
	for item in key_actions:
		if item["key"] == key:
			return item
	return null
	
func _get_key_action_by_item(item : Dictionary):
	for i in key_actions:
		if i["key"] == item["key"] and i["action_name"] == item["action_name"]:
			return i
	return null
	
func _update_key_action_by_item(item : Dictionary, new_item : Dictionary) -> bool:
	for i in key_actions:
		if i["key"] == item["key"] and i["action_name"] == item["action_name"]:
			i["key"] = new_item["key"]
			i["action_name"] = new_item["action_name"]
			return true
	return false

func _remove_key_action_by_item(item : Dictionary) -> bool:
	var index = key_actions.find(item)
	if index >= 0:
		key_actions.remove_at(index)
		return true
	return false

func _add_actions() -> void:
	for item in key_actions:
		_create_action(item)

func save_before(_settings_current : Dictionary):
	_settings_current["keybinds_key_actions"] = key_actions
	print("Saved key actions")
	
func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	print("Load after")
	
	if _settings_new.has("keybinds_key_actions"):
		key_actions = _settings_new["keybinds_key_actions"]
		print("Loaded key actions")
		# Try set initial, it will return if initial has already been set.
		settings_ui.set_initial_key_actions(key_actions)
		_add_actions()
