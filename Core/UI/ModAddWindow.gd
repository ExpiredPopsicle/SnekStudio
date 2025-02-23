extends BasicSubWindow

var _mods_list = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	popout_modal = true
	_get_app_root()._load_mods()

	var mod_scene_files : PackedStringArray

	var mod_dirs = DirAccessWithMods.get_directory_list("res://Mods")
	for mod_dir in mod_dirs:
		var file_list = DirAccessWithMods.get_file_list("res://Mods/" + mod_dir)
		for filename in file_list:
			if filename.ends_with("tscn"):
				mod_scene_files.append("res://Mods/" + mod_dir + "/" + filename)
				break

	for mod_file : String in mod_scene_files:
		var mod_entry = {}
		mod_entry["name"] = mod_file.get_file().get_basename()
		mod_entry["path"] = mod_file
		mod_entry["description"] = "A SnekStudio module."

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
				mod_entry["description"] = desc_file.get_as_text(true)
				desc_file.close()
				break

		_mods_list.append(mod_entry)
		%Mods_List.add_item(mod_entry["name"])

func _get_mods_node():
	return _get_app_root().get_node("%Mods")

func _on_button_add_mod_pressed() -> void:

	var selected_index : PackedInt32Array = %Mods_List.get_selected_items()
	if len(selected_index) > 0:
		var mod_script = load(_mods_list[selected_index[0]]["path"])
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
