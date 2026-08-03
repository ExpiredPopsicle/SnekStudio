extends Node3D

var _mods_running = false
var colliders_by_model_name = {}

var hide_window_decorations_with_ui : bool = false

# TODO (multiplayer): Make this dictionary per-model.
var module_global_data : Dictionary = {}

var _mods_loaded : bool = false

# Array of all serializable BasicSubWindows
var subwindows : Array[BasicSubWindow] = []

func _process(_delta):
	$DebugMesh.mesh.clear_surfaces()
	_set_process_order()

func _set_process_order():

	# Force child execution order by just going through and re-assigning
	# process priority to everything in the list. Mods must execute before the
	# physics on the model, or the physics will lag a frame behind.
	var child_index = 0
	for child in $Mods.get_children():
		child.set_process_priority(-1 - get_child_count() + child_index)
		child_index += 1


func get_background_color():
	var current_style : StyleBoxFlat = %BackgroundPanel.get("theme_override_styles/panel")
	return current_style.bg_color

func set_background_color(c : Color):
	var env = get_node("WorldEnvironment")
	var env2 : Environment = env.environment
	env2.background_color = c
	
	var current_style : StyleBoxFlat = %BackgroundPanel.get("theme_override_styles/panel")
	current_style.bg_color = c

func set_background_transparency(transparent : bool):
	if transparent:
		var env = get_node("WorldEnvironment")
		var env2 : Environment = env.environment
		env2.background_mode = Environment.BG_CLEAR_COLOR
		get_node("BackgroundLayer").visible = false
		get_tree().get_root().set_transparent_background(true) # Needed for compatibility mode.
		
#		get_viewport().transparent_bg = true
#		DisplayServer.window_set_flag(
#			DisplayServer.WINDOW_FLAG_TRANSPARENT, true,
#			DisplayServer.MAIN_WINDOW_ID)
#		get_tree().root.transparent_bg = true
		
	else:
		var env = get_node("WorldEnvironment")
		var env2 : Environment = env.environment
		env2.background_mode = Environment.BG_CANVAS
		#env2.background_color = Color(1.0, 1.0, 1.0, 1.0)
		get_node("BackgroundLayer").visible = true
		get_tree().get_root().set_transparent_background(false) # Needed for compatibility mode.

func get_background_transparency() -> bool:
	return not get_node("BackgroundLayer").visible

## Load the mods at runtime. This function just adds the zip files to the
## project tree.
func _load_mods() -> void:

	if _mods_loaded:
		return

	var mods_paths : PackedStringArray = []

	# If we're running a build, make sure we add mods next to the binary by
	# default.
	if not OS.has_feature("editor"):
		var default_mods_dir : String = OS.get_executable_path().get_base_dir().path_join("Mods")
		mods_paths.append(default_mods_dir)

	# Add other environment-variable-defined mod locations.
	mods_paths.append_array(get_added_mods_locations())

	# Scan for mods and add them.
	for mods_dir : String in mods_paths:

		if not DirAccess.dir_exists_absolute(mods_dir):
			push_error("mods folder \"", mods_dir, "\" does not exist")
			continue

		print("loading mods from \"", mods_dir, "\"...")
		var mods_zip_list : PackedStringArray = DirAccess.get_files_at(mods_dir)
		for mod_zip in mods_zip_list:
			print("  loading: ", mod_zip)
			DirAccessWithMods.add_zip(mods_dir.path_join(mod_zip))

	_mods_loaded = true

func _ready():
	
	_load_mods()

	set_background_transparency(true)

	# Auto-load on startup.
	load_settings()
	
	$AudioStreamRecord.play()

func _exit_tree():
	# We may need to kill some background processes and stuff (like the
	# MediaPipe tracker) before fully shutting down here.
	shutdown_mods()

	# Auto-save on quit.
	save_settings()

func _on_handle_channel_points_redeem(redeemer_username, redeemer_display_name, redeem_title, user_input):
	
	# Relay message to all mods.
	for child in $Mods.get_children():
		if child is Mod_Base:
			child.handle_channel_point_redeem(redeemer_username, redeemer_display_name, redeem_title, user_input)

func _on_handle_channel_chat_message(cheerer_username, cheerer_display_name, message, bits_count):

	# Relay message to all mods.
	for child in $Mods.get_children():
		if child is Mod_Base:
			child.handle_channel_chat_message(cheerer_username, cheerer_display_name, message, bits_count)

func _on_handle_channel_raid(raider_username, raider_display_name, raid_user_count):
	
	# Relay message to all mods.
	for child in $Mods.get_children():
		if child is Mod_Base:
			child.handle_channel_raid(raider_username, raider_display_name, raid_user_count)

func _input(event):
	
	# Handle "esc" for UI toggling.
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_ESCAPE:
				%UI_Root.set_visible(not %UI_Root.visible)
				_update_window_decorations()

func _get_default_settings_path():
	return get_config_location().path_join("settings.json")

func _get_ui_root():
	return $CanvasLayer2/UI_Root

func _force_update_ui():
	
	# Update mods list.
	get_node("%UI_Root/%ModsWindow").update_mods_list()
	
	# Update settings window.
	%UI_Root/%SettingsWindow_General.settings_changed_from_app()
	%UI_Root/%SettingsWindow_Sound.settings_changed_from_app()
	%UI_Root/%SettingsWindow_Scene.settings_changed_from_app()
	%UI_Root/%SettingsWindow_Window.settings_changed_from_app()
	%UI_Root/%SettingsWindow_Colliders.update_from_app()

func _get_current_model_base_name():
	var last_vrm_path = $ModelController.get_last_loaded_vrm()
	var model_base_name = last_vrm_path.get_file()
	return model_base_name	

func _save_colliders_for_current_model():
	var model_base_name = _get_current_model_base_name()

	var new_list = []

	var skeleton = get_skeleton()
	for c in skeleton.get_children():
		if c is AvatarCollider:
			var new_collider_entry = {}
			#new_collider_entry["bone_name"] = c.get_bone_name()
			new_collider_entry = c.get_settings()
			#var pos = c.
			#new_collider_entry["position"] = c.
			new_list.append(new_collider_entry)

	colliders_by_model_name[model_base_name] = new_list

## Get settings for colliders for this model, as an array of Dictionaries
## containing their settings (not the actual instantiated collider objects).
func get_colliders(create_defaults_if_missing : bool = false) -> Array:
	var model_base_name = _get_current_model_base_name()

	if model_base_name in colliders_by_model_name:
		# Settings exist for this model. Use them.
		return colliders_by_model_name[model_base_name]

	else:
		# No settings? Optionally create defaults, otherwise return empty.
		var default_colliders : Array = []
		if create_defaults_if_missing:
			default_colliders = [
				{
					"bone_name" : "Head",
					"position" : [0.0, 0.1, 0.02],
					"radius" : 0.12,
					"from_vrm" : false,
				}
			]
			colliders_by_model_name[model_base_name] = default_colliders

		return default_colliders

## Get the root object of the VTuber model.
func get_model() -> Node3D:
	# FIXME (multiplayer): Get model by index or something.
	return $ModelController.get_model()

## Get the skeleton of the VTuber model.
func get_skeleton() -> Skeleton3D:
	# FIXME (multiplayer): Get skeleton by index or something.
	return $ModelController.get_skeleton()

## Sync colliders on model with whatever is in the dictionary, or do a default
## if colliders_list is null.
func set_colliders(colliders_list=null) -> void:

	var collider_type = preload("res://Core/AvatarColliders/AvatarCollider.tscn")

	var skeleton = get_skeleton()
	var children_to_delete = []
	if skeleton:

		# Delete all existing colliders.
		for c in skeleton.get_children():
			if c is AvatarCollider:
				children_to_delete.append(c)
		for c in children_to_delete:
			skeleton.remove_child(c)
			c.queue_free()

		# Add colliders.
		if colliders_list != null:
			for collider_data in colliders_list:
				var new_collider : BoneAttachment3D = collider_type.instantiate()
				new_collider.set_settings(collider_data)
				skeleton.add_child(new_collider)

		_save_colliders_for_current_model()

func reset_settings_to_default() -> void:

	# Reset all collider data.
	colliders_by_model_name = {}

	# Reset model to default.
	var location = get_sample_location().path_join("VRM/samplesnek_mediapipe_16.vrm")
	load_vrm(location)

	# Clear mods list.
	var mods_to_delete = $Mods.get_children()
	for child in mods_to_delete:
		child.scene_shutdown()
		$Mods.remove_child(child)
		child.queue_free()

	# Reset camera.
	$CameraBoom.reset_to_default()

	# Reset transparency.	
	set_background_transparency(true)

	# Reset background color.
	set_background_color(Color(1.0, 0.0, 1.0, 1.0))

	# TODO: Reset UI visibility.

	# Audio volume.
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 0.0)

	# Window size.
	var viewport_default_size = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	get_viewport().set_size(viewport_default_size)
	# Note: Not messing with window position (it doesn't really have a default).
	# FIXME: Make it default to screen center?
	get_viewport().mode &= ~Window.MODE_MAXIMIZED

	# Update UI with defaults.
	_force_update_ui()

func serialize_settings(do_settings=true, do_mods=true):
	var settings_to_save = {}

	# General app settings.
	if do_settings:
		
		# Save camera.
		settings_to_save["camera"] = $CameraBoom.save_settings()

		# Save UI visibility.
		settings_to_save["ui_visible"] = %UI_Root.visible

		# Save model path.
		var last_vrm_path = $ModelController.get_last_loaded_vrm()
		settings_to_save["last_vrm_path"] = last_vrm_path

		# Save window settings
		settings_to_save["transparent_window"] = get_background_transparency()
		settings_to_save["background_color"] = get_background_color().to_html()
		settings_to_save["hide_window_decorations"] = hide_window_decorations_with_ui
		settings_to_save["vsync_mode"] = DisplayServer.window_get_vsync_mode()

		# Save sound stuff.
		settings_to_save["volume_output"] = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
		settings_to_save["sound_device_output"] = AudioServer.get_output_device()
		settings_to_save["sound_device_input"] = AudioServer.get_input_device()
		
		# Save colliders.
		settings_to_save["colliders"] = colliders_by_model_name

		# Window settings
		var window_size = get_viewport().get_size()
		var window_position = get_viewport().get_position()
		settings_to_save["window_size"] = [
			window_size[0],
			window_size[1]]
		settings_to_save["window_position"] = [
			window_position[0],
			window_position[1]]	
		settings_to_save["window_maximized"] = not not \
			(get_viewport().mode & Window.MODE_MAXIMIZED)

	# Save mods list.
	if do_mods:
		var mods_list = $Mods.get_children()
		settings_to_save["mods"] = []
		for mod in mods_list:
			var mod_definition = {}
			mod_definition["scene_path"] = mod.scene_file_path
			mod_definition["name"] = mod.get_name()
			mod_definition["settings"] = mod.save_settings()
			settings_to_save["mods"].append(mod_definition)

	# Save state of all serializable subwindows (dimensions/popout/etc)
	var subwindows_dict = settings_to_save.get_or_add("subwindows", {})
	for subwindow in subwindows:
		subwindows_dict[subwindow.name] = subwindow._serialize_window()

	return settings_to_save

func _compare_values(a, b):
	
	if a is Dictionary and b is Dictionary:
		var keys_a = a.keys()
		var keys_b = b.keys()
		keys_a.sort()
		keys_b.sort()
		if keys_a == keys_b:
			for key in keys_a:
				if not _compare_values(a[key], b[key]):
					# Non-matching value found.
					return false
			# No non-matching value found in any key.
			return true
		# Key lists don't match.
		return false

	if a is Array and b is Array:
		if a.size() != b.size():
			# Mismatched length.
			return false
		for k in range(a.size()):
			if not _compare_values(a[k], b[k]):
				# Non-matching value.
				return false
		# No non-matching value found.
		return true
	
	if a is float and b is float:
		return is_equal_approx(a, b)
	
	if a == b:
		return true
		
	return false

func _setting_changed(key, old, new):
	if key in new:
		
		if key in old:

			# Key in both. Check difference.
			return not _compare_values(new[key], old[key])
		
		# Key in new but not old.
		return true
	
	# No new key.
	return false

func _update_window_decorations():
	if hide_window_decorations_with_ui:
		get_viewport().borderless = not %UI_Root.visible
	else:
		get_viewport().borderless = false

func deserialize_settings(settings_dict, do_settings=true, do_mods=true):
	
	# Get the old settings so we only apply stuff that's changed.
	var old_settings_dict = serialize_settings()
	
	# General app settings
	if do_settings:

		# Colliders (must be loaded before VRM).
		if _setting_changed("colliders", old_settings_dict, settings_dict):
			colliders_by_model_name = settings_dict["colliders"]

		# Load last model.
		if _setting_changed("last_vrm_path", old_settings_dict, settings_dict):
			print("last vrm (old): ", old_settings_dict["last_vrm_path"])
			print("last vrm (new): ", settings_dict["last_vrm_path"])
			load_vrm(settings_dict["last_vrm_path"])

		# Load camera.
		if "camera" in settings_dict:
			$CameraBoom.load_settings(settings_dict["camera"])

		# Load transparency.
		if "transparent_window" in settings_dict:
			set_background_transparency(settings_dict["transparent_window"])

		if "hide_window_decorations" in settings_dict:
			hide_window_decorations_with_ui = settings_dict["hide_window_decorations"]

		# Load VSync mode
		if "vsync_mode" in settings_dict:
			DisplayServer.window_set_vsync_mode(settings_dict["vsync_mode"])

		# Load UI visibility.
		if "ui_visible" in settings_dict:
			%UI_Root.set_visible(settings_dict["ui_visible"])

		# Load background color.
		if _setting_changed("background_color", old_settings_dict, settings_dict):
			set_background_color(Color.html(settings_dict["background_color"]))

		# Audio settings.
		var _audio_needs_restart = false
		if _setting_changed("volume_output", old_settings_dict, settings_dict):
			AudioServer.set_bus_volume_db(
				AudioServer.get_bus_index("Master"),
				settings_dict["volume_output"])

		if _setting_changed("volume_input", old_settings_dict, settings_dict):
			AudioServer.set_bus_volume_db(
				AudioServer.get_bus_index("Record"),
				settings_dict["volume_input"])
				
		if _setting_changed("sound_device_input", old_settings_dict, settings_dict):
			print("output device before setting input: ", AudioServer.get_output_device())
			AudioServer.set_input_device(settings_dict["sound_device_input"])
			print("output device after setting input:  ", AudioServer.get_output_device())
			_audio_needs_restart = true
		#else:
		#	AudioServer.set_input_device("Default")
#		if _audio_needs_restart:
#			$AudioStreamRecord.stop()
#			$AudioStreamRecord.play()

		if _setting_changed("sound_device_output", old_settings_dict, settings_dict):
			AudioServer.set_output_device(settings_dict["sound_device_output"])
		#elif not "sound_device_output" in settings_dict:
		#	AudioServer.set_output_device("Default")
			
		# Window size/position settings
		if _setting_changed("window_size", old_settings_dict, settings_dict):
			get_viewport().set_size(Vector2i(
				settings_dict["window_size"][0], 
				settings_dict["window_size"][1]))
		if _setting_changed("window_position", old_settings_dict, settings_dict):
			get_viewport().set_position(Vector2i(
				settings_dict["window_position"][0], 
				settings_dict["window_position"][1]))
		if _setting_changed("window_maximized", old_settings_dict, settings_dict):
			if settings_dict["window_maximized"]:
				get_viewport().mode |= Window.MODE_MAXIMIZED
			else:
				get_viewport().mode &= ~Window.MODE_MAXIMIZED

	_update_window_decorations()

	# Load mods list.
	if do_mods:
		if "mods" in settings_dict:
			shutdown_mods()
			for mod_definition in settings_dict["mods"]:
				print(mod_definition)
				var packed_scene = load(mod_definition["scene_path"])
				if packed_scene:
					var scene = packed_scene.instantiate()
					scene.set_name(mod_definition["name"])
					$Mods.add_child(scene)
					scene.load_settings(mod_definition["settings"])
					scene.update_settings_ui()
			reinit_mods()

	# Restore state of all serializable subwindows (dimensions/popout/etc)
	var subwindows_dict = settings_dict.get("subwindows")
	if subwindows_dict is Dictionary:
		for subwindow in subwindows:
			var subwindow_dict = subwindows_dict.get(subwindow.name)
			if subwindow_dict is Dictionary:
				subwindow._deserialize_window(subwindow_dict)

func save_settings(path : String = ""):
	
	var settings_to_save = serialize_settings()
	
	# Figure out actual save path.	
	var settings_filename = path
	if settings_filename == "":
		settings_filename = _get_default_settings_path()
	
	# Create settings directory if it doesn't already exist
	var settings_dir = ProjectSettings.globalize_path(settings_filename.get_basename())
	if not DirAccess.dir_exists_absolute(settings_dir):
		if DirAccess.make_dir_recursive_absolute(settings_dir) != OK:
			push_error("Failed to create settings directory: " + settings_dir)
			return
	
	# Convert settings to JSON and save.
	var save_string = JSON.stringify(settings_to_save, "  ")
	var file = FileAccess.open(settings_filename, FileAccess.WRITE)
	file.store_string(save_string)
	file.close()

func load_settings(path : String = ""):
	
	_load_mods()
	print("Loading settings...")
	
	# Get actual save path.
	var settings_filename = path
	if settings_filename == "":
		settings_filename = _get_default_settings_path()

	# Load and parse the file.
	var file = FileAccess.open(settings_filename, FileAccess.READ)
	var settings_dict = {
		"mods" : [
			{
				"name": "MediaPipeController",
				"scene_path": "res://Mods/MediaPipe/MediaPipeController.tscn",
				"settings": {
				"arm_rest_angle": 60,
				"debug_visible_hand_trackers": false,
				"hand_confidence_time_threshold": 1,
				"hand_count_change_time_threshold": 1,
				"hand_tracking_enabed": true,
				"mirror_mode": true,
				"tracking_pause": false,
				"use_mediapipe_shapes": true,
				"use_vrm_basic_shapes": true,
				"video_device": []
				}
			},
			{
				"name": "EyeAdjustments",
				"scene_path": "res://Mods/EyeAdjustments/EyeAdjustments.tscn",
				"settings": {
				}
			},
			{
				"name": "MediaPipeToVrmBlendShapes",
				"scene_path": "res://Mods/MediaPipeToVRMBlendShapes/MediaPipeToVRMBlendShapes.tscn",
				"settings": {
				}
			},
			{
				"name": "BlendShapeScalingAndOffset",
				"scene_path": "res://Mods/BlendShapeScalingAndOffset/BlendShapeScalingAndOffset.tscn",
				"settings": {
				}
			},
			{
				"name": "SceneBasic",
				"scene_path": "res://Mods/Scene_Basic/Scene_Basic.tscn",
				"settings": {
				"draw_ground_plane": true,
				"light_ambient_color": "ffffffff",
				"light_ambient_multiplier": 0.5,
				"light_directional_color": "ffffffff",
				"light_directional_multiplier": 0.5,
				"light_directional_pitch": -37.8007940368435,
				"light_directional_yaw": 36.680506409178
				}
			},
			{
				"name": "AnimationApplier",
				"scene_path": "res://Mods/AnimationApplier/AnimationApplier.tscn",
				"settings": { }
			},
			{
				"name": "PoseIk",
				"scene_path": "res://Mods/PoseIK/PoseIK.tscn",
				"settings": { }
			},
		]}

	if file:
		var file_contents = file.get_as_text()
		file.close()
		settings_dict = JSON.parse_string(file_contents)
	
	# Set everything to default.
	reset_settings_to_default()
	
	deserialize_settings(settings_dict)
	
	_force_update_ui()

## Load a new VRM file from a given path. Returns true on success and false on
## failure.
func load_vrm(path) -> bool:

	# FIXME: Handle failure cases.

	shutdown_mods()
	var new_model_root : Node3D = $ModelController.load_vrm(path)

	if not new_model_root:
		reinit_mods()
		push_error("Failed to load VRM: ", path)
		return false

	# Load colliders list
	var collider_data : Array = get_colliders(true)

	# Clear "from_vrm" from everything loaded because we'll correlate
	# loaded colliders in the next step.
	for collider in collider_data:
		collider["from_vrm"] = false

	# Add colliders from VRM (the ones used for springbone collisions).
	var model = $ModelController.get_node_or_null("Model")
	if model:
		var secondary_path = NodePath("secondary") #model.vrm_secondary
		var secondary = model.get_node_or_null(secondary_path)

		#if collider_data == null:
		#	collider_data = []

		var do_vrm_colliders = false
		if secondary != null and do_vrm_colliders:
			var collider_groups = secondary.collider_groups
			for collider_group in collider_groups:
				for sphere_collider in collider_group.colliders:

					# FIXME: Add support for capsules.
					if sphere_collider.is_capsule:
						continue

					var bone_name = sphere_collider.bone			

					var new_collider = {}
					
					new_collider["position"] = [
						sphere_collider.offset[0],
						sphere_collider.offset[1],
						sphere_collider.offset[2]]
						
					new_collider["radius"] = sphere_collider.radius
					new_collider["bone_name"] = bone_name	
					new_collider["from_vrm"] = true
					
					# See if this new one matches and existing collider.
					var found_collider = null
					for existing_collider in collider_data:
						var fields_to_compare = [
							"position", "radius",
							"bone_name" ]
						
						var is_this_collider = true
						for field in fields_to_compare:
							if not _compare_values(existing_collider[field], new_collider[field]):
								is_this_collider = false
								break

						if is_this_collider:
							existing_collider["from_vrm"] = true
							found_collider = existing_collider
							break
					
					# No loaded collider found? Add it.
					if found_collider == null:
						collider_data.append(new_collider)

	# FIXME: Hack to make collider visibility match collider window.
	var ui_root = _get_ui_root()
	var ui_collider_window = ui_root.get_node_or_null("%SettingsWindow_Colliders")
	for k in collider_data:
		k["visible"] = ui_collider_window.visible

	# Force initial T-Pose.
	var skel : Skeleton3D = get_skeleton()
	skel.reset_bone_poses()

	set_colliders(collider_data)

	reinit_mods()
	_force_update_ui()

	return true

func shutdown_mods():
	if _mods_running:
		for mod in $Mods.get_children():
			mod.scene_shutdown()
		_mods_running = false

func reinit_mods():
	if not _mods_running:
		for mod in $Mods.get_children():
			mod.scene_init()
		_mods_running = true

func get_audio():
	return $AudioStreamRecord

func get_controller():
	return $ModelController

## Get the saved user data directory. When running in the editor, this will be
## the "Saved" directory under the project. For running outside the editor, it
## will be the "Saved" directory under the same directory as the binary.
static func get_saved_location() -> String:
	if OS.has_feature("editor"):
		return "res://Saved"
	return OS.get_executable_path().get_base_dir().path_join("Saved")

## Get the config directory. Will default to the user data directory unless
## overridden by environment variable.
static func get_config_location() -> String:
	var env_path : String = OS.get_environment("SNEKSTUDIO_CONFIG_PATH")
	if env_path != "":
		return ProjectSettings.localize_path(env_path)
	return get_saved_location()


static func get_sample_location() -> String:
	var env_path : String = OS.get_environment("SNEKSTUDIO_SAMPLE_PATH")
	if env_path != "":
		return ProjectSettings.localize_path(env_path)
	return "res://SampleModels"

## Get the cache location. Mainly this is where Python gets unpacked to.
## Defaults to saved user data directory unless overridden.
static func get_cache_location() -> String:
	var env_path : String = OS.get_environment("SNEKSTUDIO_CACHE_PATH")
	if env_path != "":
		return ProjectSettings.localize_path(env_path)
	return get_saved_location()

## Get additional mods locations. These will be scanned after the ones that come
## alongside the executable.
static func get_added_mods_locations() -> PackedStringArray:
	var env_path : String = OS.get_environment("SNEKSTUDIO_MODS_PATHS")
	var paths_localized : PackedStringArray = []
	if env_path != "":
		var paths_global : PackedStringArray = env_path.split(":", false)
		for global_path : String in paths_global:
			paths_localized.append(ProjectSettings.localize_path(global_path))
	return paths_localized

## Get an ImmediateMesh for drawing debug lines to. Simple material with a
## shader that uses vertex data.
##
## The mesh is cleared every frame, so this is for immediate-mode style debug
## rendering.
func get_debug_mesh() -> ImmediateMesh:
	return $DebugMesh.mesh
