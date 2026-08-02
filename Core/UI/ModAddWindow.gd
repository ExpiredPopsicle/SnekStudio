extends BasicSubWindow

var _filter_text: String = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	popout_modal = true
	_update_mods_list()

func _update_mods_list() -> void:
	var mods_list : ItemList = %Mods_List
	mods_list.clear()
	for mod in _get_mods_node().get_available_mods():
		if (_filter_text == "") or mod.name.to_lower().contains(_filter_text):
			mods_list.add_item(mod.name)
			mods_list.set_item_icon(mods_list.item_count - 1, mod.icon)
			mods_list.set_item_metadata(mods_list.item_count - 1, mod)

func _get_mods_node() -> SnekStudioMods:
	return _get_app_root().mods

func _on_button_add_mod_pressed() -> void:
	var mods_list : ItemList = %Mods_List
	var selected_index := mods_list.get_selected_items()
	if selected_index.size() != 1: return

	var available_mod = mods_list.get_item_metadata(selected_index[0])
	var mod: Mod_Base = load(available_mod.path).instantiate()
	_get_mods_node().add_child(mod)
	mod.scene_init()
	%ModsWindow.update_mods_list()

func _on_button_cancel_pressed():
	close_window()

func _on_mods_list_item_selected(_index: int) -> void:
	# Fill in the description field for the selection, or leave it blank if
	# nothing is selected.
	%ModDescription.clear()

	var mods_list : ItemList = %Mods_List
	var selected_index := mods_list.get_selected_items()
	if selected_index.size() != 1: return

	var available_mod = mods_list.get_item_metadata(selected_index[0])
	%ModDescription.append_text(available_mod.description)

func _on_filter_search_text_changed(new_text: String) -> void:
	_filter_text = new_text.to_lower()
	_update_mods_list()
