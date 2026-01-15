extends Mod_Base
class_name Keybinds

@export var panel : Control = null

# List of actions and keys, that will be imported to the input map
# [ 
#  { 
#   "key" : number_for_key_representation
#   "action_name" : "action_name_here"
#  }
# ]
var key_actions : Array = []
var settings_ui : KeybindSettingUI
var KEYBIND_PREFIX : String = "kb_"

func _ready() -> void:
	# Alert all mods that rely on keybinds of the prefix we are using.
	var global_dict = get_global_mod_data("Keybinds")
	if not global_dict.has("prefix"):
		global_dict["prefix"] = KEYBIND_PREFIX
	else:
		KEYBIND_PREFIX = global_dict["prefix"]

	# Not essential, but allows us to reference it in other mods quickly.
	send_global_mod_message("Keybinds", global_dict)

	# Remove the temp panel and attach the children to the 
	# settings window! This way we aren't messing around with
	# tracked settings, and instead are simply loading our own UI.
	remove_child(panel)

	var new_keybind_button : Button = Button.new()
	new_keybind_button.text = "New Keybind"
	get_settings_window().add_child(new_keybind_button)
	new_keybind_button.pressed.connect(_new_keybind)

	var load_default_button : Button = Button.new()
	load_default_button.text = "Reset Keybinds"
	get_settings_window().add_child(load_default_button)
	load_default_button.pressed.connect(_load_default)

	var first_child = panel.get_child(0)
	settings_ui = first_child
	panel.remove_child(settings_ui)
	get_settings_window().add_child(settings_ui)
	settings_ui.on_change_item.connect(on_ui_change_item)
	settings_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Always make sure we remove previous actions in case there's a double-up.
	_remove_actions()

func _new_keybind() -> void:
	settings_ui.add_key_action(null)

func on_ui_change_item(action : int, item : Dictionary, old_item : Dictionary):
	if action == ChangeAction.ACTION_NAME or action == ChangeAction.KEY_BIND:
		# Updates should be fine as there is a reference to the item.
		# We only have to check if there isn't an item, then add an item.
		if action == ChangeAction.ACTION_NAME \
		   and item["action_name"] != "" \
		   and _get_key_action_by_item(item) == null:
			key_actions.append(item)
			_create_action(item)
		else:
			_update_action(item, old_item)
	if action == ChangeAction.DELETE:
		# Remove the existing item from our key_actions.
		_remove_key_action_by_item(item)

		# Adjust our input map.
		var action_event_count = len(InputMap.action_get_events(KEYBIND_PREFIX + item["action_name"]))
		if action_event_count <= 1:
			# Delete the entire action.
			print_log("Deleting the entire action for %s" % item["action_name"])
			InputMap.erase_action(KEYBIND_PREFIX + item["action_name"])
		else:
			# Delete just our event.
			var key_event = _create_key_event(item)
			if key_event != null:
				print_log("Deleting just our event for %s" % item["action_name"])
				InputMap.action_erase_event(KEYBIND_PREFIX + item["action_name"], key_event)

	save_settings()

func _create_key_event(item : Dictionary) -> InputEventKey:
	var key : int = item["key"]
	var alt_pressed : bool = item.get("modifier_alt", false)
	var ctrl_pressed : bool = item.get("modifier_ctrl", false)
	var meta_pressed : bool = item.get("modifier_meta", false)
	var shift_pressed : bool = item.get("modifier_shift", false)
	if key == -1:
		return null
	var new_key_event = InputEventKey.new()
	new_key_event.physical_keycode = key
	new_key_event.alt_pressed = alt_pressed
	new_key_event.ctrl_pressed = ctrl_pressed
	new_key_event.meta_pressed = meta_pressed
	new_key_event.shift_pressed = shift_pressed
	return new_key_event

func _create_action(item : Dictionary) -> void:
	var action = item["action_name"]

	# Do not create empty.
	if action == "":
		return

	print_log("Creating new action and associated event %s" % action)
	var key_event = _create_key_event(item)

	if not InputMap.has_action(KEYBIND_PREFIX + action):
		InputMap.add_action(KEYBIND_PREFIX + action)

	# Always add the event to the action, if there is no action it was made.
	# existing events for the action have been cleared.	
	if key_event != null:
		InputMap.action_add_event(KEYBIND_PREFIX + action, key_event)

func _update_action(new_item : Dictionary, old_item : Dictionary) -> void:
	var new_action = new_item["action_name"]
	var old_action = old_item["action_name"]
	var new_key = new_item["key"]
	var old_key = old_item["key"]

	if new_action != old_action:
		print_log("New item action name (%s) is different from the old (%s)." % 
					[new_action, old_action])
		var existing_events = InputMap.action_get_events(KEYBIND_PREFIX + old_action)
		if old_action != "" and len(existing_events) < 1:
			InputMap.erase_action(KEYBIND_PREFIX + old_action)
		_create_action(new_item)
	elif new_key != old_key \
		 or new_item["modifier_alt"] != old_item["modifier_alt"] \
		 or new_item["modifier_ctrl"] != old_item["modifier_ctrl"] \
		 or new_item["modifier_shift"] != old_item["modifier_shift"] \
		 or new_item["modifier_meta"] != old_item["modifier_meta"]:
		print_log("New item key is not the same as the old key.")
		if old_key != -1:
			print_log("Old item key is not unassigned. Removing the old item key event.")
			var old_key_event = _create_key_event(old_item)
			if new_action == "":
				# We need to cycle through all actions and events
				# and find where the key is used and remove it.
				for action_name in InputMap.get_actions():
					if not action_name.begins_with(KEYBIND_PREFIX):
						continue
					if not InputMap.event_is_action(old_key_event, action_name, true):
						continue
					print("Removing orphan event from %s action" % action_name)
					InputMap.action_erase_event(action_name, old_key_event)
			else:
				InputMap.action_erase_event(KEYBIND_PREFIX + new_action, old_key_event)

		print_log("Adding event for the action name with the correct key.")

		# We only want to create a new key event if it wasn't reset.
		var new_key_event = _create_key_event(new_item)
		if new_key_event != null and new_action != "":
			InputMap.action_add_event(KEYBIND_PREFIX + new_action, new_key_event)

func _input(event : InputEvent) -> void:
	for action in InputMap.get_actions():
		if event.is_action_pressed(action, false, true):
			send_global_mod_message("KeybindsActionPressed", 
			{
				"action": action.replace(KEYBIND_PREFIX, ""),
				 "event": event
			})
	# This is one way to do actions. The other is with global mod data.
	if InputMap.has_action(KEYBIND_PREFIX + "ping") \
		and event.is_action_pressed(KEYBIND_PREFIX + "ping", false, true):
		print_log("Input map pong!")
		set_status("Pong!")

	# The alternative approach is commented below.
	#func _handle_global_mod_message(key : String, values : Dictionary):
		#if key == "KeybindsActionPressed" and values["action"] == "ping":
			#print_log("Global mod message pong!")
			#set_status("Pong!")

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

func _create_initial_actions() -> void:
	key_actions = [
		{ 
			"key": KEY_P,
			"action_name": "ping",
			"modifier_alt": false,
			"modifier_ctrl": false,
			"modifier_meta": false,
			"modifier_shift": false
		},
		{ 
			"key": KEY_Y,
			"action_name": "ping",
			"modifier_alt": false,
			"modifier_ctrl": true,
			"modifier_meta": false,
			"modifier_shift": false
		},
	]

func _remove_actions() -> void:
	for action_name in InputMap.get_actions():
		# ONLY remove our actions we make.
		if not action_name.begins_with(KEYBIND_PREFIX):
			continue
		InputMap.erase_action(action_name)

func _load_default() -> void:
	_remove_actions()
	_create_initial_actions()
	_add_actions()
	settings_ui.reset()
	settings_ui.set_initial_key_actions(key_actions)
	
func save_before(_settings_current : Dictionary):
	_settings_current["keybinds_key_actions"] = key_actions
	print_log("Saved key actions")

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	if _settings_new.has("keybinds_key_actions") and len(_settings_new["keybinds_key_actions"]) > 0:
		key_actions = _settings_new["keybinds_key_actions"]
		print_log("Loaded key actions.")

	# Try set initial, it will return if initial has already been set.	
	if len(key_actions) <= 0:
		return
	print_log("Attempting to load...")
	if not settings_ui.has_set_initial:
		print("Initial adding of actions.")
		_add_actions()
	print_log("Setting up UI...")
	settings_ui.set_initial_key_actions(key_actions)	
