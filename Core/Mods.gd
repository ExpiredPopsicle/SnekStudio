class_name SnekStudioMods
extends Node

## Return an array of all currently active mods.
func get_active_mods(include_disabled := false) -> Array[Mod_Base]:
	var result: Array[Mod_Base]
	for child in get_children():
		if child is Mod_Base and (include_disabled or child is not DisabledMod):
			result.append(child)
	return result


var _mods_loaded := false
var _mods_running := false

func _ready() -> void:
	_load_mod_zips()

func _process(_delta: float) -> void:
	# Force child execution order by just going through and re-assigning
	# process priority to everything in the list. Mods must execute before the
	# physics on the model, or the physics will lag a frame behind.
	var child_index := 0
	for mod in get_children():
		mod.set_process_priority(-1 - get_child_count() + child_index)
		child_index += 1

## Load the mods at runtime.
## This function just adds the zip files to the project tree.
func _load_mod_zips() -> void:
	if _mods_loaded: return

	var mods_paths: PackedStringArray

	# When running a release version (not running from the editor),
	# make sure we add mods next to the binary by default.
	if not OS.has_feature("editor"):
		var executable_dir := OS.get_executable_path().get_base_dir()
		var default_mods_dir := executable_dir.path_join("Mods")
		mods_paths.append(default_mods_dir)

	# Add other environment-variable-defined mod locations.
	mods_paths.append_array(SnekStudioMain.get_added_mods_locations())

	# Scan for mods and add them.
	for mods_dir in mods_paths:
		if not DirAccess.dir_exists_absolute(mods_dir):
			push_error("mods folder \"", mods_dir, "\" does not exist")
			continue

		print("loading mods from \"", mods_dir, "\"...")
		var mods_zip_list := DirAccess.get_files_at(mods_dir)
		for mod_zip in mods_zip_list:
			print("  loading: ", mod_zip)
			DirAccessWithMods.add_zip(mods_dir.path_join(mod_zip))

	_mods_loaded = true

func _load_mods_from_settings(dict: Array) -> void:
	_shutdown_mods()
	_clear_mods()

	for mod_definition in dict:
		print(mod_definition)
		var packed_scene: PackedScene = load(mod_definition["scene_path"])
		if not packed_scene: continue

		var scene: Mod_Base = packed_scene.instantiate()
		scene.set_name(mod_definition["name"])
		add_child(scene)
		scene.load_settings(mod_definition["settings"])
		scene.update_settings_ui()

	_reinit_mods()

func _save_mods_to_settings() -> Array:
	var result: Array
	for mod in get_active_mods(true):
		var mod_definition: Dictionary
		mod_definition["scene_path"] = mod.scene_file_path
		mod_definition["name"] = mod.get_name()
		mod_definition["settings"] = mod.save_settings()
		result.append(mod_definition)
	return result

func _clear_mods() -> void:
	for mod in get_active_mods(true):
		# If mods are not currently running (like after calling
		# _shutdown_mods), don't call scene_shutdown a second time.
		if _mods_running: mod.scene_shutdown()
		remove_child(mod)
		mod.queue_free()

func _reinit_mods() -> void:
	if _mods_running: return
	_mods_running = true
	for mod in get_active_mods(true):
		mod.scene_init()

func _shutdown_mods() -> void:
	if not _mods_running: return
	_mods_running = false
	for mod in get_active_mods(true):
		mod.scene_shutdown()
