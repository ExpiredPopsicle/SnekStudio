extends BasicSubWindow

var _filter_text: String = ""

## Get the currently selected mod in the available mod list, if any.
func get_selected_mod() -> SnekStudioMods.AvailableMod:
	var mods_list_node : ItemList = %Mods_List
	var selected := mods_list_node.get_selected_items()
	if selected.size() == 0: return null # nothing selected

	assert(selected.size() == 1) # only one selection is supported
	return mods_list_node.get_item_metadata(selected[0])

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
	_get_mods_node().add_mod(get_selected_mod())
	%ModsWindow.update_mods_list()

func _on_button_cancel_pressed():
	close_window()

func _on_mods_list_item_selected(_index: int) -> void:
	%ModDescription.text = get_selected_mod().description

func _on_filter_search_text_changed(new_text: String) -> void:
	_filter_text = new_text.to_lower()
	_update_mods_list()
