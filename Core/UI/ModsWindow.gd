extends BasicSubWindow

## Get the currently selected mod in the mod list, if any.
func get_selected_mod() -> Mod_Base:
	var mods_list_node : ItemList = %ModsList
	var selected := mods_list_node.get_selected_items()
	if selected.size() == 0: return null # nothing selected

	assert(selected.size() == 1) # only one selection is supported
	var mod: Mod_Base = mods_list_node.get_item_metadata(selected[0])
	if (not is_instance_valid(mod)) or (not mod.is_inside_tree()): return null

	return mod

## Sets the currently selected mod in the mod list to the specified mod, if any.
## May only be called after update_mods_list if the global mods list changed.
func set_selected_mod(mod: Mod_Base) -> void:
	if is_instance_valid(mod) and (mod.get_parent() == _get_app_root().mods):
		%ModsList.select(mod.get_index())
	else:
		%ModsList.deselect_all()
	_handle_selection_change()


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

func _update_status_text_for_mod(mod: Mod_Base):
	if mod == get_selected_mod():
		_update_status_text()

func _update_status_text():
	var selected := get_selected_mod()
	if selected != null:
		%LineEdit_ModStatus.text = selected._mod_status
	else:
		%LineEdit_ModStatus.text = ""

func _update_log_text_for_mod(mod: Mod_Base):
	if mod == get_selected_mod():
		_update_log_text()

func _update_log_text():
	var selected : Node = get_selected_mod()

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
	# Clear out old mods window.
	for child in %Mods_Settings_Panel.get_children():
		%Mods_Settings_Panel.remove_child(child)

	var selected := get_selected_mod()
	if selected != null:
		%Mods_Settings_Panel.add_child(selected.get_settings_window())
		%TextEdit_ModName.text = selected.name
		%TextEdit_ModName.editable = true
	else:
		%TextEdit_ModName.text = ""
		%TextEdit_ModName.editable = false

	_update_log_text()
	_update_status_text()

func _on_mods_list_item_selected(_index):
	_handle_selection_change()

func _get_mods_node() -> SnekStudioMods:
	return _get_app_root().mods

func update_mods_list():
	var mods_node := _get_mods_node()
	var mods_list_node : ItemList = %ModsList
	var previous_selected := get_selected_mod()

	# This is just for running the local scene without a full app.
	if mods_node:
		# Recreate list of mods from scratch.
		mods_list_node.clear()
		for mod: Mod_Base in mods_node.get_children():
			mods_list_node.add_item(mod.name)
			mods_list_node.set_item_icon(mods_list_node.item_count - 1, mod.icon)
			mods_list_node.set_item_metadata(mods_list_node.item_count - 1, mod)

	# Restore previously selected mod, if any.
	set_selected_mod(previous_selected)

func _ready():
	_get_mods_node().mod_list_changed.connect(update_mods_list)

	# Save default values for both popout and embedded splitter offsets
	popout_mod_list_offset = $VBoxContainer3/HSplitContainer.split_offset
	popout_mod_status_offset = $VBoxContainer3/HSplitContainer/VBoxContainer2/VSplitContainer.split_offset
	embed_mod_list_offset = $VBoxContainer3/HSplitContainer.split_offset
	embed_mod_status_offset = $VBoxContainer3/HSplitContainer/VBoxContainer2/VSplitContainer.split_offset

	register_serializable_subwindow()
	update_mods_list()
	_update_error_list()

func _on_button_move_mod_up_pressed():
	var selected := get_selected_mod()
	if selected == null: return
	_get_mods_node().move_mod(selected, selected.get_index() - 1)
	set_selected_mod(selected)

func _on_button_move_mod_down_pressed():
	var selected := get_selected_mod()
	if selected == null: return
	_get_mods_node().move_mod(selected, selected.get_index() + 1)
	set_selected_mod(selected)

func _on_button_remove_mod_pressed():
	var selected := get_selected_mod()
	if not selected: return
	_get_mods_node().remove_mod(selected)

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
	var selected := get_selected_mod()
	if selected == null: return

	var new_mod: Mod_Base
	if selected is DisabledMod:
		new_mod = _get_mods_node().enable_mod(selected)
	else:
		new_mod = _get_mods_node().disable_mod(selected)

	update_mods_list()
	set_selected_mod(new_mod)
