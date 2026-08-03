extends BasicSubWindow

var _selected_mod = null

# Saved splitter offsets for both embedded and popout mode
var embed_mod_list_offset: int = 0
var embed_mod_status_offset: int = 0
var popout_mod_list_offset: int = 0
var popout_mod_status_offset: int = 0

func show_window():
	super.show_window()
	_update_log_text()

func _process(_delta: float) -> void:
	_update_error_list()

func _update_error_list():

	var full_error_list : PackedStringArray = []
	var mods : Node = _get_mods_node()
	for mod in mods.get_children():
		var new_warnings : Array = mod.check_configuration()
		for new_warning : String in new_warnings:
			full_error_list.append(mod.get_name() + ": " + new_warning)

	if len(full_error_list):
		%ModWarningsLabel.show()
		%ModWarningsLabel.text = "Errors:\n" + "\n".join(full_error_list)
	else:
		%ModWarningsLabel.hide()
		%ModWarningsLabel.text = ""

# FIXME: Kind of a hack until we figure out how to correctly update the pointer
#   when mods are removed.
func _get_selected_mod() -> Node:
	var mods_node : Node = _get_mods_node()
	if is_instance_valid(_selected_mod):
		if mods_node:
			if _selected_mod in mods_node.get_children():
				if is_instance_valid(_selected_mod):
					return _selected_mod
	return null

func _update_status_text_for_mod(mod):
	var selected : Node = _get_selected_mod()
	if selected != mod:
		return
	_update_status_text()
	
func _update_status_text():
	var selected : Node = _get_selected_mod()
	if selected:
		%LineEdit_ModStatus.text = selected._mod_status
	else:
		%LineEdit_ModStatus.text = ""

func _update_log_text_for_mod(mod):
	var selected : Node = _get_selected_mod()
	if selected != mod:
		return
	_update_log_text()
	
func _update_log_text():
	var selected : Node = _get_selected_mod()

	var old_scroll_vertical = \
		%TextEdit_ModLog.scroll_vertical
	var old_scroll_vertical_with_lines = old_scroll_vertical + \
		%TextEdit_ModLog.get_visible_line_count()
	var old_line_count = %TextEdit_ModLog.get_line_count()
	
	if is_instance_valid(selected):
		%TextEdit_ModLog.text = "\n".join(selected._mod_log)
	else:
		%TextEdit_ModLog.text = ""
	
	if old_line_count == old_scroll_vertical_with_lines:
		#print(old_line_count, " ", old_scroll_vertical)
		%TextEdit_ModLog.set_v_scroll(%TextEdit_ModLog.get_line_count())
	else:
		%TextEdit_ModLog.set_v_scroll(old_scroll_vertical) 

func _handle_selection_change():
	var mods_list_node : ItemList = %ModsList
	var selected = mods_list_node.get_selected_items()
	
	if len(selected) > 0:

		var newly_selected_mod = null
		if selected[0] < _get_mods_node().get_child_count():
			newly_selected_mod = _get_mods_node().get_child(selected[0])

		if newly_selected_mod != _get_selected_mod():
			_selected_mod = newly_selected_mod
			
			# Clear out old mods window.
			for child in %Mods_Settings_Panel.get_children():
				%Mods_Settings_Panel.remove_child(child)
			
			# Create and add new settings panel.
			if _selected_mod:
				%Mods_Settings_Panel.add_child(
					_selected_mod.get_settings_window())
				%TextEdit_ModName.text = _selected_mod.name
				%TextEdit_ModName.editable = true
			else:
				%TextEdit_ModName.text = ""
				%TextEdit_ModName.editable = false
	
	else:
		
		# Clear out old mods window.
		for child in %Mods_Settings_Panel.get_children():
			%Mods_Settings_Panel.remove_child(child)
			%TextEdit_ModName.text = ""
			%TextEdit_ModName.editable = false
	
	_update_log_text()
	_update_status_text()
	
func _on_mods_list_item_selected(_index):
	_handle_selection_change()
	
func _get_mods_node():
	return _get_app_root().get_node("%Mods")

func update_mods_list():
	var mods_node = _get_mods_node()
	var mods_list_node : ItemList = %ModsList

	# This is just for running the local scene without a full app.
	if not mods_node:
		return

	# Rewrite and resize the list to match actual existing mods.
	while mods_list_node.item_count < mods_node.get_child_count():
		mods_list_node.add_item("test")
	while mods_list_node.item_count > mods_node.get_child_count():
		mods_list_node.remove_item(mods_list_node.item_count - 1)
	for i in range(mods_node.get_child_count()):
		if mods_node.get_child(i).name != mods_list_node.get_item_text(i):
			mods_list_node.set_item_text(i, mods_node.get_child(i).name)
		if mods_node.get_child(i).icon != mods_list_node.get_item_icon(i):
			mods_list_node.set_item_icon(i, mods_node.get_child(i).icon)

	# Handle mod selection changing.
	_handle_selection_change()

func _ready():
	# Save default values for both popout and embedded splitter offsets
	popout_mod_list_offset = $VBoxContainer3/HSplitContainer.split_offset
	popout_mod_status_offset = $VBoxContainer3/HSplitContainer/VBoxContainer2/VSplitContainer.split_offset
	embed_mod_list_offset = $VBoxContainer3/HSplitContainer.split_offset
	embed_mod_status_offset = $VBoxContainer3/HSplitContainer/VBoxContainer2/VSplitContainer.split_offset

	register_serializable_subwindow()
	update_mods_list()
	_update_error_list()

func _swap_adjacent_mods(index1, index2):

	# Swap the text.
	var mods_list_node : ItemList = %ModsList
	var text_tmp = mods_list_node.get_item_text(index1)
	mods_list_node.set_item_text(index1, mods_list_node.get_item_text(index2))
	mods_list_node.set_item_text(index2, text_tmp)

	var mods_node = _get_mods_node()
	if index1 > index2:
		mods_node.move_child(mods_node.get_child(index1), index2)
	else:
		mods_node.move_child(mods_node.get_child(index2), index1)

func _on_button_move_mod_up_pressed():
	var mods_list_node : ItemList = %ModsList
	var selected_item = mods_list_node.get_selected_items()
	if len(selected_item) < 1:
		return
	
	if selected_item[0] == 0:
		return
	
	_swap_adjacent_mods(selected_item[0], selected_item[0] - 1)
	
	mods_list_node.select(selected_item[0] - 1)

func _on_button_move_mod_down_pressed():
	var mods_list_node : ItemList = %ModsList
	var selected_item = mods_list_node.get_selected_items()
	if len(selected_item) < 1:
		return
	
	if selected_item[0] >= mods_list_node.get_item_count() - 1:
		return
	
	_swap_adjacent_mods(selected_item[0], selected_item[0] + 1)
	
	mods_list_node.select(selected_item[0] + 1)

func _on_button_remove_mod_pressed():
	var mods_list_node : ItemList = %ModsList
	var selected_item = mods_list_node.get_selected_items()
	if len(selected_item) < 1:
		return
	
	var mods_node = _get_mods_node()
	var mod = mods_node.get_child(selected_item[0])
	mod.scene_shutdown()
	mods_node.remove_child(mod)
	mod.queue_free()
	_handle_selection_change()

	update_mods_list()

func _on_button_add_mod_pressed():
	var add_window = _get_app_root().get_node("%UI_Root/%ModAddWindow")
	add_window._save_current_window_state()
	add_window.show_window()
	add_window._set_popped_out(popped_out)
	if popped_out:
		var last_owner = add_window.owner
		add_window.popout_window.reparent(self)
		add_window.owner = last_owner
		add_window.popout_window.exclusive = true

func _update_currently_selected_name():
	var mods_list_node : ItemList = %ModsList
	var selected_item = mods_list_node.get_selected_items()
	if len(selected_item) < 1:
		return
	var mods_node = _get_mods_node()
	var mod = mods_node.get_child(selected_item[0])
	if mod.name != %TextEdit_ModName.text:
		mod.name = %TextEdit_ModName.text
		mods_list_node.set_item_text(selected_item[0], mod.name)
		_handle_selection_change()
		%TextEdit_ModName.text = mod.name

func _on_text_edit_mod_name_gui_input(event):
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_ENTER:
				_update_currently_selected_name()

func _on_text_edit_mod_name_focus_exited():
	_update_currently_selected_name()

func save_current_splitter_offsets() -> void:
	if popped_out:
		popout_mod_list_offset = $VBoxContainer3/HSplitContainer.split_offset
		popout_mod_status_offset = $VBoxContainer3/HSplitContainer/VBoxContainer2/VSplitContainer.split_offset
	else:
		embed_mod_list_offset = $VBoxContainer3/HSplitContainer.split_offset
		embed_mod_status_offset = $VBoxContainer3/HSplitContainer/VBoxContainer2/VSplitContainer.split_offset

func load_splitter_offsets(pop_out: bool) -> void:
	if pop_out:
		$VBoxContainer3/HSplitContainer.split_offset = popout_mod_list_offset
		$VBoxContainer3/HSplitContainer/VBoxContainer2/VSplitContainer.split_offset = popout_mod_status_offset
	else:
		$VBoxContainer3/HSplitContainer.split_offset = embed_mod_list_offset
		$VBoxContainer3/HSplitContainer/VBoxContainer2/VSplitContainer.split_offset = embed_mod_status_offset

func popout_state_changing(pop_out: bool) -> void:
	if pop_out != popped_out:
		save_current_splitter_offsets()
	load_splitter_offsets(pop_out)

func serialize_window() -> Dictionary:
	save_current_splitter_offsets()

	return {"popout_mod_list_offset": popout_mod_list_offset,
			"popout_mod_status_offset": popout_mod_status_offset,
			"embed_mod_list_offset": embed_mod_list_offset,
			"embed_mod_status_offset": embed_mod_status_offset}

func deserialize_window(dict: Dictionary) -> void:
	embed_mod_list_offset = dict["embed_mod_list_offset"]
	embed_mod_status_offset = dict["embed_mod_status_offset"]
	popout_mod_list_offset = dict["popout_mod_list_offset"]
	popout_mod_status_offset = dict["popout_mod_status_offset"]

	load_splitter_offsets(popped_out)

func close_window() -> void:
	save_current_splitter_offsets()
	super.close_window()


func _on_button_toggle_mod_pressed() -> void:
	var mods_list_node: ItemList = %ModsList
	var selected_item = mods_list_node.get_selected_items()
	if len(selected_item) < 1:
		return

	var mods_node = _get_mods_node()
	var mod: Mod_Base = mods_node.get_child(selected_item[0])


	if mod is DisabledMod:

		# This mod is already disabled. Re-enable it.

		# Re-create the mod instance.
		var loaded_mod = load(mod.saved_settings["scene_path"]).instantiate()
		loaded_mod.name = mod.get_name()

		# Remove the placeholder (but don't free it yet) so the names don't
		# collide.
		_get_mods_node().remove_child(mod)

		# Add the new one to the scene and initialize it with the settings.
		_get_mods_node().add_child(loaded_mod)
		_get_mods_node().move_child(loaded_mod, selected_item[0])
		loaded_mod.load_settings(mod.saved_settings["settings"])
		loaded_mod.update_settings_ui()
		loaded_mod.scene_init()

		# Free the old placeholder.
		mod.queue_free()

	else:

		var saved_settings: Dictionary = {}

		saved_settings["scene_path"] = mod.scene_file_path
		saved_settings["name"] = mod.get_name()
		saved_settings["settings"] = mod.save_settings()

		var placeholder: DisabledMod = load("res://Mods/DisabledMod/DisabledMod.tscn").instantiate()
		placeholder.name = saved_settings["name"]
		placeholder.saved_settings = saved_settings

		# Clear out the mod we just disabled. Do this first so the name doesn't
		# get clobbered with the placeholder mod.
		mod.scene_shutdown()
		mods_node.remove_child(mod)
		mod.queue_free()

		# Insert the placeholder.
		_get_mods_node().add_child(placeholder)
		_get_mods_node().move_child(placeholder, selected_item[0])

	_handle_selection_change()
	update_mods_list()
