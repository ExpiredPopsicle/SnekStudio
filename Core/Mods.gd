class_name SnekStudioMods
extends Node

## Fired whenever the active mod list is changed in some way.
## This includes mods being added, removed, enabled, disabled or reordered.
signal mod_list_changed

class AvailableMod extends RefCounted:
	var name: String
	var path: String
	var icon: Texture2D = null
	var description: String = "A SnekStudio module."

## Returns an array of available mods that may be added to the active mod list.
func get_available_mods() -> Array[AvailableMod]:
	return _available_mods

## Adds a fresh instance of an available mod to the active mod list.
## You can specify the index where to insert the mod, defaulting to the end.
func add_mod(mod: AvailableMod, index := 99999) -> Mod_Base:
	# This should always succeed. An AvailableMod is only constructed for mods
	# which extend Mod_Base and have been successfully instantiated before.
	var instance: Mod_Base = load(mod.path).instantiate()
	add_child(instance)
	# If necessary, move mod to the desired index.
	if index < get_child_count(): move_child(instance, maxi(0, index))
	if _mods_running: instance.scene_init()
	mod_list_changed.emit()
	return instance

## Removes an active (or disabled) mod from the active mod list.
func remove_mod(mod: Mod_Base) -> void:
	assert(is_instance_valid(mod))
	assert(mod.get_parent() == self)
	if _mods_running: mod.scene_shutdown()
	remove_child(mod)
	mod.queue_free()
	mod_list_changed.emit()


## Return an array of all currently active mods.
func get_active_mods(include_disabled := false) -> Array[Mod_Base]:
	var result: Array[Mod_Base]
	for child in get_children():
		if child is Mod_Base and (include_disabled or child is not DisabledMod):
			result.append(child)
	return result

func enable_mod(disabled_mod: DisabledMod) -> Mod_Base:
	assert(is_instance_valid(disabled_mod))
	assert(disabled_mod.get_parent() == self)

	var scene_path: String = disabled_mod.saved_settings["scene_path"]
	var settings: Dictionary = disabled_mod.saved_settings["settings"]

	var index := disabled_mod.get_index()
	remove_child(disabled_mod)
	disabled_mod.queue_free()

	var mod: Mod_Base = load(scene_path).instantiate()
	mod.name = disabled_mod.get_name()
	add_child(mod)
	move_child(mod, index)
	mod.load_settings(settings)
	mod.update_settings_ui()
	if _mods_running: mod.scene_init()

	mod_list_changed.emit()
	return mod

func disable_mod(mod: Mod_Base) -> DisabledMod:
	assert(is_instance_valid(mod))
	assert(mod.get_parent() == self)
	if mod is DisabledMod: return # already disabled

	var index := mod.get_index()
	if _mods_running: mod.scene_shutdown()
	remove_child(mod)
	mod.queue_free()

	const DISABLED_MOD_SCENE := preload("res://Mods/DisabledMod/DisabledMod.tscn")
	var disabled_mod: DisabledMod = DISABLED_MOD_SCENE.instantiate()
	disabled_mod.name = mod.name
	disabled_mod.saved_settings = {
		name       = mod.name,
		scene_path = mod.scene_file_path,
		settings   = mod.save_settings(),
	}
	add_child(disabled_mod)
	move_child(disabled_mod, index)

	mod_list_changed.emit()
	return disabled_mod

## Reorders the specified mod in the active mod list.
func move_mod(mod: Mod_Base, index: int) -> void:
	assert(is_instance_valid(mod))
	assert(mod.get_parent() == self)
	index = clampi(index, 0, get_child_count() - 1)
	move_child(mod, index)
	mod_list_changed.emit()


var _mods_loaded := false
var _mods_running := false
var _available_mods: Array[AvailableMod]

# Using _enter_tree to ensure this runs earlier than other nodes' _ready functions.
# Running this as early as possible should be fine, since we don't access other nodes.
func _enter_tree() -> void:
	if _mods_loaded: return
	_mods_loaded = true

	_load_mod_zips()
	_process_available_mods()

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

func _process_available_mods() -> void:
	# Go through potential mod directories.
	for mod_dir: String in DirAccessWithMods.get_directory_list("res://Mods"):
		# Go through all the files in those directories.
		var file_list = DirAccessWithMods.get_file_list("res://Mods/" + mod_dir)
		for filename: String in file_list:
			# Skip anything that isn't a scene (.tscn) file.
			if filename.get_extension() != "tscn": continue

			# Attempt to load the scene at that location.
			var scene_path := "res://Mods/" + mod_dir + "/" + filename
			var scene      := load(scene_path) as PackedScene
			var instance   := scene.instantiate()
			instance.queue_free() # Gotta free to prevent leaks.

			if instance is DisabledMod:
				break # special mod, skip

			# If the scene turns out to be a mod, add it to available mods.
			if instance is Mod_Base:
				var mod := AvailableMod.new()
				mod.name = filename.get_basename() # strip extension
				mod.path = scene_path
				mod.icon = instance.icon
				mod.description = _find_mod_description("res://Mods/" + mod_dir)
				_available_mods.append(mod)
				break # skip remaining files in directory

	# Make sure the available mods are sorted by their names.
	_available_mods.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower() )

func _find_mod_description(base_dir: String) -> String:
	const POSSIBLE_DESCRIPTION_FILES := [
		"README", "README.txt", "readme.txt",
		"DESCRIPTION", "DESCRIPTION.txt", "description.txt",
		"FILE_ID.DIZ", "file_id.diz" ]

	for file in POSSIBLE_DESCRIPTION_FILES:
		var path := base_dir.path_join(file)
		if FileAccess.file_exists(path):
			var access := FileAccess.open(path, FileAccess.READ)
			var text := access.get_as_text()
			access.close()
			return text

	return "A SnekStudio module."

func _load_mods_from_settings(dict: Array) -> void:
	_shutdown_mods()
	_clear_mods()

	for mod_definition in dict:
		var packed_scene: PackedScene = load(mod_definition["scene_path"])
		if not packed_scene: continue

		var scene: Mod_Base = packed_scene.instantiate()
		scene.set_name(mod_definition["name"])
		add_child(scene)
		scene.load_settings(mod_definition["settings"])
		scene.update_settings_ui()

	_reinit_mods()
	mod_list_changed.emit()

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
		if _mods_running: mod.scene_shutdown()
		remove_child(mod)
		mod.queue_free()
	mod_list_changed.emit()

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
