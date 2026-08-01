extends BasicSubWindow

var _mods_list = []
var _filter_text: String = ""

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	popout_modal = true
	_get_app_root()._load_mods()

	for mod_file : String in _get_mod_scene_files():
		var mod_entry = _get_mod_entry_from_file(mod_file)
		if mod_entry != null:
			_mods_list.append(mod_entry)

	_mods_list.sort_custom(func(a, b): return a["name"].to_lower() < b["name"].to_lower() )

	_update_mods_list()

func _update_mods_list() -> void:
	%Mods_List.clear()
	for mod_entry: Dictionary in _mods_list:
		if _filter_text.length() > 0:
			if !mod_entry["name"].to_lower().contains(_filter_text):
				continue
		
		%Mods_List.add_item(mod_entry["name"])
		%Mods_List.set_item_icon(%Mods_List.item_count - 1, mod_entry["icon"])

func _get_mod_entry_from_file(mod_file: String):
	var mod_entry: Dictionary = {}
	mod_entry["name"] = mod_file.get_file().get_basename()
	mod_entry["path"] = mod_file
	mod_entry["description"] = "A SnekStudio module."
	var tmp_mod_instance: Mod_Base = load(mod_file).instantiate()
	mod_entry["icon"] = tmp_mod_instance.icon

	# Special cases for internal-only mods.
	if tmp_mod_instance is DisabledMod:
		# Only created by disabling another mod.
		tmp_mod_instance.queue_free()
		return null

	tmp_mod_instance.queue_free()

	# Search for a description file and overwrite the default
	# description if it's found.
	for possible_description_file in [
		"README", "README.txt", "readme.txt",
		"DESCRIPTION", "DESCRIPTION.txt", "description.txt",
		"FILE_ID.DIZ", "file_id.diz"]:
		var possible_description_file_full : String = \
			mod_file.get_base_dir().path_join(possible_description_file)
		if FileAccess.file_exists(possible_description_file_full):
			var desc_file : FileAccess = \
				FileAccess.open(possible_description_file_full, FileAccess.READ)
			mod_entry["description"] = desc_file.get_as_text()
			desc_file.close()
			break

	return mod_entry

func _get_mod_scene_files() -> PackedStringArray:
	var mod_scene_files : PackedStringArray

	var mod_dirs = DirAccessWithMods.get_directory_list("res://Mods")
	for mod_dir in mod_dirs:
		var file_list = DirAccessWithMods.get_file_list("res://Mods/" + mod_dir)
		for filename in file_list:
			if filename.ends_with("tscn"):
				mod_scene_files.append("res://Mods/" + mod_dir + "/" + filename)
				break
				
	return mod_scene_files

func _get_mods_node():
	return _get_app_root().get_node("%Mods")

func _on_button_add_mod_pressed() -> void:

	var selected_index : PackedInt32Array = %Mods_List.get_selected_items()
	if len(selected_index) > 0:
		var selected_mod = _mods_list.filter(func(item): return item["name"].to_lower().contains(_filter_text))[selected_index[0]]
		var mod_script = load(selected_mod["path"])
		var mod = mod_script.instantiate()
		_get_mods_node().add_child(mod)
		mod.scene_init()
		%ModsWindow.update_mods_list()

func _on_button_cancel_pressed():
	close_window()

func _on_mods_list_item_selected(_index: int) -> void:

	# Fill in the description field for the selection, or leave it blank if
	# nothing is selected.
	%ModDescription.clear()
	var selected_index : PackedInt32Array = %Mods_List.get_selected_items()
	if len(selected_index) > 0:
		var desc : String = _mods_list[selected_index[0]]["description"]
		%ModDescription.append_text(desc)

func _on_filter_search_text_changed(new_text: String) -> void:
	_filter_text = new_text.to_lower()
	_update_mods_list()
