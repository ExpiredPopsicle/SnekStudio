extends Node
class_name Mod_Base

var _settings_window : Control = null
var _settings_widgets_by_setting_name : Dictionary = {}
var _settings_properties = []
var _mod_status : String = ""
var _mod_log : Array = []

const defaults_text_get_rid_of_me = "\u27F2"

# -----------------------------------------------------------------------------
# Virtual functions

#region Virtual functions

# Virtual function called after the model is added to the scene, OR after the
# model is swapped.
func scene_init():
	pass

# Virtual function called before the object is removed from the scene, OR right
# before the model is swapped.
func scene_shutdown():
	pass

# Create the UI used to display settings for the mod.
#
# This function can be overridden.
#
# This is the *default* version, which creates a VBoxContainer that can be
# filled with settings_window_add_*() functions.
func _create_settings_window():
	assert(not _settings_window)
	_settings_window = VBoxContainer.new()
	_settings_window.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_window.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return _settings_window

# Virtual function called any time someone cheers with bits on twitch.
func handle_channel_chat_message(_cheerer_username, _cheerer_display_name, _message, _bits_count):
	pass

# Virtual function called any time someone does any channel point redeem.
func handle_channel_point_redeem(_redeemer_username, _redeemer_display_name, _redeem_title, _user_input):
	pass

# Virtual function called when a channel raid comes in.
func handle_channel_raid(_raider_username, _raider_display_name, _raid_user_count):
	pass

func get_redeem_names():
	
	# By default, just return and string properties that we've flagged as
	# redeems.
	var redeem_list = []
	for prop in _settings_properties:
		var prop_val = get(prop["name"])
		if prop_val is String:
			if prop["args"].has("is_redeem"):
				if prop["args"]["is_redeem"]:
					redeem_list.append(prop_val)
					
	return redeem_list

# Settings interface.

# Called before saving. Gives a last chance to modify the dictionary before
# going out. If you need to save custom data, do it here.
func save_before(_settings_current : Dictionary):
	pass

# Called before loading new settings, so that appropriate state may be prepared.
func load_before(_settings_old : Dictionary, _settings_new : Dictionary):
	pass

# Called after loading new settings, so that stuff can be applied to the actual
# state of stuff.
func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	pass

# FIXME: We don't really want this to be virtual anymore.
func save_settings():
	var ret = {}

	for prop in _settings_properties:
		if "is_color" in prop["args"] and prop["args"]["is_color"]:
			ret[prop["name"]] = get(prop["name"]).to_html()
		else:
			ret[prop["name"]] = get(prop["name"])
			

	save_before(ret)

	return ret
	
# FIXME: We don't really want this to be virtual anymore.
func load_settings(_settings_dict):
	
	var old_settings = save_settings()
	
	# Make the new complete settings by taking the old ones and copying over the
	# new settings into it.
	var new_settings = old_settings.duplicate()
	new_settings.merge(_settings_dict, true)
	
	load_before(old_settings, new_settings)
	
	for prop in _settings_properties:
		if "is_color" in prop["args"] and prop["args"]["is_color"]:
			set(prop["name"], Color(new_settings[prop["name"]]))
		else:
			set(prop["name"], new_settings[prop["name"]])

	load_after(old_settings, new_settings)

func add_tracked_setting(setting_name, label_text, extra_args={}):

	# Just make sure the property is actually in the list.
	var prop_found = false
	var props_list = get_property_list()
	for prop in props_list:
		if prop["name"] == setting_name:
			prop_found = true
			break
	assert(prop_found)
	
	var new_setting_prop = {}
	new_setting_prop["name"] = setting_name
	new_setting_prop["label"] = label_text
	new_setting_prop["args"] = extra_args

	if get(setting_name) is Color:
		new_setting_prop["args"]["is_color"] = true

	_settings_properties.append(new_setting_prop)

	var prop_val = get(new_setting_prop["name"])
	
	if prop_val is String:
		settings_window_add_lineedit(
			new_setting_prop["label"], new_setting_prop["name"],
			new_setting_prop["args"].get("is_redeem", false),
			new_setting_prop["args"].get("is_fileaccess", false))
		
	elif prop_val is bool:
		settings_window_add_boolean(new_setting_prop["label"], new_setting_prop["name"])
		
	elif prop_val is float:
		settings_window_add_slider_with_number(
			new_setting_prop["label"], new_setting_prop["name"],
			new_setting_prop["args"].get("min", 0.0),
			new_setting_prop["args"].get("max", 1.0),
			new_setting_prop["args"].get("step", 0.1))

	elif prop_val is int:
		settings_window_add_spinbox(
			new_setting_prop["label"], new_setting_prop["name"],
			new_setting_prop["args"].get("min", 0),
			new_setting_prop["args"].get("max", 4294967296))

	elif prop_val is Array:
		settings_window_add_selector(
			new_setting_prop["label"], new_setting_prop["name"],
			new_setting_prop["args"].get("values", {}),
			new_setting_prop["args"].get("allow_multiple", false),
			new_setting_prop["args"].get("combobox", false))
			
	elif prop_val is Color:
		settings_window_add_colorpicker(
			new_setting_prop["label"], new_setting_prop["name"])

	elif prop_val is Vector3:
		settings_window_add_vector3(
			new_setting_prop["label"], new_setting_prop["name"])

	else:
		# I don't recognize that type for a new setting.
		assert(false)

func _test_redeem_with_settings_value(prop_name, local=true):
	var prop_val = get(prop_name)
	if local:
		handle_channel_point_redeem("testuser", "TestUser", prop_val, "Test input")
	else:
		get_app()._on_handle_channel_points_redeem(
			"testuser", "TestUser", prop_val, "Test input")

func _get_file_path(prop_name, widget: LineEdit, filter: PackedStringArray):
	var prop_val = get(prop_name)
	var file_dialog = get_app()._get_ui_root().get_node("LineEditFileDialog")
	
	# Set the file format filter
	file_dialog.set_filters(filter)
	file_dialog.popup()
	
	prop_val = await file_dialog.file_selected
	modify_setting(prop_name, prop_val)
	widget.set_text(prop_val)
	
	# clear filter
	file_dialog.clear_filters()

# Pull settings from app and update UI widgets to reflect them.	
#
# Default version here. Can be overridden.
func update_settings_ui(_ui_window = null):
	var current_settings = save_settings()
	
	var keys = current_settings.keys()
	for key in keys:
		if key in _settings_widgets_by_setting_name:
			var value = current_settings[key]
			var widget = _settings_widgets_by_setting_name[key]
			
			# Checkbox/boolean
			if widget is CheckBox:
				widget.button_pressed = value

			# LineEdit/string
			if widget is LineEdit:
				widget.text = value

			if widget is SpinBox:
				value = roundi(value)
				widget.value = value
			
			# BasicSliderWithNumber/float
			if widget is BasicSliderWithNumber:
				value = roundf((value - widget.min_value) / widget.step) * widget.step + widget.min_value
				widget.value = value
			
			if widget is ColorPickerButton:
				widget.color = value
				value = Color(value)
			
			# ItemList/array
			if widget is ItemList:
				widget.deselect_all()
				for val in value:
					for item_index in range(widget.item_count):
						if widget.get_item_text(item_index) == val:
							widget.select(item_index)
							break

			if widget is OptionButton:
				for val in value:
					for item_index in range(widget.item_count):
						if widget.get_item_text(item_index) == val:
							widget.select(item_index)
							break

			if widget is VectorSettingWidget:
				widget.value = value
			
			var default_value = widget.get_meta("default")
			var is_default = false
			if value is float:
				is_default = is_equal_approx(value, default_value)
			else:
				is_default = value == default_value
			var reset_default = widget.get_meta("reset_button")
			reset_default.disabled = is_default
			reset_default.self_modulate = 0xFFFFFFFF * int(!is_default)

func _handle_global_mod_message(key : String, values : Dictionary):
	return

#endregion

# -----------------------------------------------------------------------------
# Functions usable by the mods themselves

#region Mod API

func _update_log_ui(update_log = true, update_status = true):
	# FIXME: This is a really gross way to do this thing.
	var mods_window = get_app()._get_ui_root().get_node("ModsWindow")
	if mods_window.visible:
		if update_log:
			mods_window._update_log_text_for_mod(self)
		if update_status:
			mods_window._update_status_text_for_mod(self)

func set_status(args):
	var out_str = args
	if args is Array:
		out_str = "".join(args)
	if _mod_status != out_str:
		_mod_status = out_str
		#print_log(["Status: ", out_str])
	_update_log_ui(false, true)

func print_log(args):
	var out_str = args
	if args is Array:
		out_str = "".join(args)
	print(get_name() + ": " + out_str)
	_mod_log.append(out_str)
	var max_log_length = 256
	if len(_mod_log) > max_log_length:
		_mod_log = _mod_log.slice(len(_mod_log) - max_log_length - 1, max_log_length)
	_update_log_ui(true, false)

# Get the group name that all the autodelete objects belong to.
func get_autodelete_group_name():
	return get_name() + "_autodelete_group"

# Call this to add an object to be automatically deleted when the mod is
# unloaded.
func add_autodelete_object(ob : Node):

	if not tree_exiting.is_connected(_autodelete_remove_everything):
		tree_exiting.connect(_autodelete_remove_everything)

	ob.add_to_group(get_autodelete_group_name())

func get_app():
	var current = self
	while current.name != "SnekStudio_Main":
		current = current.get_parent()
	return current

func get_skeleton() -> Skeleton3D:
	# This is kind of gross, but by putting it here we'll only have one place to
	# update if we ever need to re-do this interface.
	# FIXME: Better way to get this path.
	return get_app().get_node("ModelController")._get_model_skeleton()

func get_model() -> Node3D:

	var controller = get_app().get_node("ModelController")
	return controller.get_node_or_null("Model")
	
	#var skeleton = controller._get_model_skeleton()
	#if !skeleton:
		#return null
		#
	#var model_root = skeleton.get_parent()
	#return model_root

func get_bone_transform(bone_name) -> Transform3D:
	var skeleton = get_skeleton()
	if skeleton:
		var bone_index = skeleton.find_bone(bone_name)
		if bone_index != -1:
			return skeleton.get_bone_global_pose(bone_index)
	return Transform3D()

func get_input_audio_level():
	return get_app().get_audio().get_current_input_level()

func get_mod_path():
	var local_dir = self.get_script().get_path().get_base_dir()
	return local_dir

func get_files_in_directory(
	path, include_files=true,
	include_dirs=false, suffix_filter=""):

	# List of directories to (attempt to) search.
	var folders_to_search = [
		path
	]
	
	# Add a directory with the same path, but relative to the binary. This will
	# let runtime-loaded files override internal files.
	if path.begins_with("res://"):
		folders_to_search.append(
			OS.get_executable_path().get_base_dir().path_join(
				path.substr(len("res://"))))
	
	var output_list = []
	
	# Search those directories for any throwable objects, and load them.
	for path_to_list in folders_to_search:
		
		print(path_to_list)
		
		var dir = DirAccess.open(path_to_list)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				
				# Filter out files or directories.
				if dir.current_is_dir():
					if not include_dirs:
						continue
				else:
					if not include_files:
						continue

				var full_path = path_to_list.path_join(file_name)
				
				# Load scene files directly.
				if len(suffix_filter) == 0:
					output_list.append(full_path)
				elif full_path.ends_with(suffix_filter):
					output_list.append(full_path)

				file_name = dir.get_next()

	return output_list

func get_global_mod_data(key : String) -> Dictionary:
	var app : Node = get_app()
	if key in app.module_global_data:
		return app.module_global_data[key]
	app.module_data[key] = {}
	return app.module_global_data[key]

func send_global_mod_message(key : String, values : Dictionary, skip_current : bool = true):
	var mods_container : Node = get_app().get_node("Mods")
	for mod in mods_container.get_children():
		if mod != self or not skip_current:
			mod._handle_global_mod_message(key, values)

#endregion

# -----------------------------------------------------------------------------
# Settings window setup functions, to simplify settings UI creation
#
# Use these in ready().

#region Settings window

func settings_window_add_boolean(setting_label, setting_name):
	
	# This only works with the default-created settings window widget.
	var window : Container = get_settings_window()
	#assert(window is GridContainer)
	#assert(window.columns == 2)

	var container_widget : HBoxContainer = HBoxContainer.new()

	var label_widget = Label.new()
	label_widget.text = setting_label
	label_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var checkbox_widget = CheckBox.new()
	
	var default_value = get(setting_name)
		
	var reset_default = Button.new()
	var reset_default_action = func(default_value):
		modify_setting(setting_name, default_value)
		checkbox_widget.set_pressed_no_signal(default_value)
	reset_default.text = defaults_text_get_rid_of_me
	reset_default.flat = true
	reset_default.pressed.connect(
		reset_default_action.bind(default_value)
	)
	
	checkbox_widget.set_meta("default", default_value)
	checkbox_widget.set_meta("reset_button", reset_default)
	checkbox_widget.pressed.connect(
		func():
			modify_setting(setting_name, checkbox_widget.button_pressed)
			var is_default = checkbox_widget.button_pressed == default_value
			reset_default.disabled = is_default
			reset_default.self_modulate = 0xFFFFFFFF * int(!is_default)
	)
	
	container_widget.add_child(label_widget)
	container_widget.add_child(checkbox_widget)
	container_widget.add_child(reset_default)
	window.add_child(container_widget)
	
	_settings_widgets_by_setting_name[setting_name] = checkbox_widget


func settings_window_add_spinbox(
	setting_label, setting_name,
	min_value=0, max_value=4294967296):

	# This only works with the default-created settings window widget.
	var window : Container = get_settings_window()

	var label_widget = Label.new()
	label_widget.text = setting_label
	window.add_child(label_widget)
	
	var spinbox_widget : SpinBox = SpinBox.new()
	spinbox_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					
	spinbox_widget.min_value = min_value
	spinbox_widget.max_value = max_value
		
	var default_value = get(setting_name)
	
	var reset_default = Button.new()
	var reset_default_action = func(default_value):
		modify_setting(setting_name, default_value)
		spinbox_widget.set_value_no_signal(default_value)
	reset_default.text = defaults_text_get_rid_of_me
	reset_default.flat = true
	reset_default.disabled = true
	reset_default.pressed.connect(
		reset_default_action.bind(default_value)
	)

	spinbox_widget.set_meta("default", default_value)
	spinbox_widget.set_meta("reset_button", reset_default)
	spinbox_widget.value_changed.connect(
		func(new_number):
			modify_setting(setting_name, roundi(new_number))
			var is_default = new_number == default_value
			reset_default.disabled = is_default
			reset_default.self_modulate = 0xFFFFFFFF * int(!is_default)
	)

	var container_widget : HBoxContainer = HBoxContainer.new()
	
	container_widget.add_child(spinbox_widget)
	container_widget.add_child(reset_default)
	
	window.add_child(container_widget)
	_settings_widgets_by_setting_name[setting_name] = spinbox_widget

func settings_window_add_lineedit(setting_label, setting_name, is_redeem=false, is_fileaccess=false, file_filters: PackedStringArray = []):
	
	# This only works with the default-created settings window widget.
	var window : Container = get_settings_window()

	var label_widget = Label.new()
	label_widget.text = setting_label
	
	var group_widget = BoxContainer.new()
	group_widget.vertical = false
	group_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lineedit_widget = LineEdit.new()
	lineedit_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group_widget.add_child(lineedit_widget)

	if is_fileaccess:
		var dialog_button : Button = Button.new()
		dialog_button.text = "..."
		dialog_button.tooltip_text = "Open File"
		group_widget.add_child(dialog_button)
		dialog_button.button_down.connect(_get_file_path.bind(setting_name, lineedit_widget, file_filters))

	if is_redeem:
		var test_button : Button = Button.new()
		test_button.text = "Test This"
		test_button.tooltip_text = "Test this redeem, but only for this module."
		group_widget.add_child(test_button)
		test_button.button_down.connect(
			_test_redeem_with_settings_value.bind(setting_name, true))
		
		test_button = Button.new()
		test_button.text = "Test All"
		test_button.tooltip_text = "Test this redeem, but send it to the entire application (including other modules)."
		group_widget.add_child(test_button)
		test_button.button_down.connect(
			_test_redeem_with_settings_value.bind(setting_name, false))

	var default_value = get(setting_name)
	
	var reset_default = Button.new()
	var reset_default_action = func(default_value):
		modify_setting(setting_name, default_value)
		lineedit_widget.set_text(default_value)
	reset_default.text = defaults_text_get_rid_of_me
	reset_default.flat = true
	reset_default.pressed.connect(
		reset_default_action.bind(default_value)
	)

	lineedit_widget.set_meta("default", default_value)
	lineedit_widget.set_meta("reset_button", reset_default)
	lineedit_widget.text_changed.connect(
		func(new_text):
			modify_setting(setting_name, new_text)
			var is_default = new_text == default_value
			reset_default.disabled = is_default
			reset_default.self_modulate = 0xFFFFFFFF * int(!is_default)
	)
	
	group_widget.add_child(reset_default)

	window.add_child(label_widget)
	window.add_child(group_widget)

	_settings_widgets_by_setting_name[setting_name] = lineedit_widget

func settings_window_add_slider_with_number(
	setting_label, setting_name,
	min_value=0.0, max_value=1.0,
	step=0.1):
	
	# This only works with the default-created settings window widget.
	var window : Container = get_settings_window()

	var label_widget = Label.new()
	label_widget.text = setting_label
	
	var slider_widget = load("res://Core/UI/BasicSliderWithNumber.tscn").instantiate()
	slider_widget.min_value = min_value
	slider_widget.max_value = max_value
	slider_widget.step = step
	slider_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var default_value = get(setting_name)
	default_value = roundf((default_value - min_value) / step) * step + min_value
	
	var reset_default = Button.new()
	var reset_default_action = func(default_value):
		modify_setting(setting_name, default_value)
		slider_widget.set_value_no_signal(default_value)
	reset_default.text = defaults_text_get_rid_of_me
	reset_default.flat = true
	reset_default.pressed.connect(
		reset_default_action.bind(default_value)
	)
	
	slider_widget.set_meta("default", default_value)
	slider_widget.set_meta("reset_button", reset_default)
	slider_widget.value_changed.connect(
		func(new_value):
			modify_setting(setting_name, new_value)
			var is_default = is_equal_approx(new_value, default_value)
			reset_default.disabled = is_default
			reset_default.self_modulate = 0xFFFFFFFF * int(!is_default)
	)
	
	var container_widget : HBoxContainer = HBoxContainer.new()
	container_widget.add_child(slider_widget)
	container_widget.add_child(reset_default)
	
	window.add_child(label_widget)
	window.add_child(container_widget)

	_settings_widgets_by_setting_name[setting_name] = slider_widget

func settings_window_add_selector(
	setting_label, setting_name,
	initial_values = [],
	allow_multiple = false,
	use_combobox = false):
	
	# This only works with the default-created settings window widget.
	var window : Container = get_settings_window()

	var label_widget = Label.new()
	label_widget.text = setting_label
	
	var selection_widget = null
	
	var reset_default_action = null
	var reset_default = Button.new()
	reset_default.text = defaults_text_get_rid_of_me
	reset_default.flat = true
	
	var default_value = get(setting_name)
	
	var callback = func(widget):
		var new_value = []
		var selected_items = []
		if widget is ItemList:
			selected_items = widget.get_selected_items()
		elif widget is OptionButton:
			selected_items.append(widget.get_selected_id())
		for k in selected_items:			
			new_value.append(widget.get_item_text(k))
		modify_setting(setting_name, new_value)
		var is_default = new_value == default_value
		reset_default.disabled = is_default
		reset_default.self_modulate = 0xFFFFFFFF * int(!is_default)
	
	if use_combobox:
		selection_widget = OptionButton.new()
		selection_widget.fit_to_longest_item = false
		selection_widget.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		selection_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		reset_default_action = func(default_value):
			modify_setting(setting_name, default_value)
			for value in default_value:
				for idx in selection_widget.item_count:
					if selection_widget.get_item_text(idx) == value:
						selection_widget.select(idx)
						break
	else:
		selection_widget = ItemList.new()
		selection_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selection_widget.size_flags_vertical = Control.SIZE_EXPAND_FILL
		selection_widget.select_mode = ItemList.SELECT_SINGLE
		if allow_multiple:
			selection_widget.select_mode = ItemList.SELECT_MULTI
		
		reset_default_action = func(default_value):
			var single = selection_widget.select_mode != ItemList.SELECT_MULTI
			modify_setting(setting_name, default_value)
			if !single:
				selection_widget.deselect_all()
			for value in default_value:
				for idx in selection_widget.item_count:
					if selection_widget.get_item_text(idx) == value:
						selection_widget.select(idx, single)

		selection_widget.multi_selected.connect(
			(func(_index, widget): callback.call(widget)).bind(selection_widget))

	reset_default.pressed.connect(
		reset_default_action.bind(default_value)
	)

	selection_widget.set_meta("default", default_value)
	selection_widget.set_meta("reset_button", reset_default)
	selection_widget.item_selected.connect(
		(func(_index, widget): callback.call(widget)).bind(selection_widget))

	for item in initial_values:
		selection_widget.add_item(item)
	
	window.add_child(label_widget)

	var container_widget : HBoxContainer = HBoxContainer.new()
	container_widget.add_child(selection_widget)
	container_widget.add_child(reset_default)
	window.add_child(container_widget)

	_settings_widgets_by_setting_name[setting_name] = selection_widget

func settings_window_add_colorpicker(
	setting_label, setting_name):
	
	# This only works with the default-created settings window widget.
	var window : Container = get_settings_window()

	var label_widget = Label.new()
	label_widget.text = setting_label
	
	var colorpicker_widget = ColorPickerButton.new()
	
	colorpicker_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colorpicker_widget.custom_minimum_size.y = 32
	
	var default_value = get(setting_name)
	
	var reset_default = Button.new()
	var reset_default_action = func(default_value):
		modify_setting(setting_name, default_value)
		colorpicker_widget.set_pick_color(default_value)
	reset_default.text = defaults_text_get_rid_of_me
	reset_default.flat = true
	reset_default.pressed.connect(
		reset_default_action.bind(default_value)
	)
	
	colorpicker_widget.set_meta("default", default_value)
	colorpicker_widget.set_meta("reset_button", reset_default)
	colorpicker_widget.color_changed.connect(
		func(new_value):
			modify_setting(setting_name, new_value)
			var is_default = new_value == default_value
			reset_default.disabled = is_default
			reset_default.self_modulate = 0xFFFFFFFF * int(!is_default)
	)

	window.add_child(label_widget)
	
	var container_widget : HBoxContainer = HBoxContainer.new()
	container_widget.add_child(colorpicker_widget)
	container_widget.add_child(reset_default)
	window.add_child(container_widget)

	_settings_widgets_by_setting_name[setting_name] = colorpicker_widget

func settings_window_add_vector3(
	setting_label, setting_name):

	# This only works with the default-created settings window widget.
	var window : Container = get_settings_window()

	var label_widget = Label.new()
	label_widget.text = setting_label

	var vec3_widget : VectorSettingWidget = \
		load("res://Core/UI/VectorSettingWidget.tscn").instantiate()
	vec3_widget.custom_minimum_size.y = 32
	vec3_widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	window.add_child(label_widget)
	
	var default_value = get(setting_name)
	
	var reset_default = Button.new()
	var reset_default_action = func(default_value):
		modify_setting(setting_name, default_value)
		vec3_widget.set_value_no_signal(default_value)
	reset_default.text = defaults_text_get_rid_of_me
	reset_default.flat = true
	reset_default.pressed.connect(
		reset_default_action.bind(default_value)
	)
	
	vec3_widget.set_meta("default", default_value)
	vec3_widget.set_meta("reset_button", reset_default)
	vec3_widget.value_changed.connect(
		func(new_value):
			modify_setting(setting_name, new_value)
			var is_default = new_value == default_value
			reset_default.disabled = is_default
			reset_default.self_modulate = 0xFFFFFFFF * int(!is_default)
	)
	
	var container_widget : HBoxContainer = HBoxContainer.new()
	container_widget.add_child(vec3_widget)
	container_widget.add_child(reset_default)
	window.add_child(container_widget)

	_settings_widgets_by_setting_name[setting_name] = vec3_widget

func modify_setting(setting_name, value):
	var existing_settings = save_settings()
	existing_settings[setting_name] = value
	load_settings(existing_settings)

#endregion

# -----------------------------------------------------------------------------
# Stuff used by external systems

#region external

func get_settings_window():
	
	# Add cleanup callback.
	if not tree_exiting.is_connected(_cleanup_settings_window):
		tree_exiting.connect(_cleanup_settings_window)

	# Create the window if it doesn't exist.
	if not _settings_window:
		_settings_window = _create_settings_window()
	
		update_settings_ui(_settings_window)

	return _settings_window

#endregion

# -----------------------------------------------------------------------------
# Internal stuff

#region internal

func _cleanup_settings_window():
	if _settings_window:
		if is_instance_valid(_settings_window):
			_settings_window.queue_free()
	
	_settings_widgets_by_setting_name = {}

func _autodelete_remove_everything():
	var group_nodes = get_tree().get_nodes_in_group(get_autodelete_group_name())
	for node in group_nodes:
		node.queue_free()

#endregion
