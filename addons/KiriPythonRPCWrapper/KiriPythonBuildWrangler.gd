# Python build wrangler
#
# This handles extracting and juggling standalone Python builds per-platform.

extends RefCounted
class_name KiriPythonBuildWrangler

# Cached release info so we don't have to constantly reload the .json file.
var _python_release_info : Dictionary = {}

#region Python archive filename wrangling

## Detect the Python archive based on the current platform and the status in
## platform_status.json.
func _detect_archive_for_runtime() -> String:
	return _detect_archive_for_build(OS.get_name())

## Detect the Python archive based on the input platform and the status in
## platform_status.json.
func _detect_archive_for_build(os_name : String) -> String:
	var platform_status_json : Dictionary = _get_platform_status()
	var platform_status_this_os : Dictionary = platform_status_json[os_name]
	return get_script().resource_path.get_base_dir().path_join(
		"StandalonePythonBuilds").path_join(platform_status_this_os["complete_filename"])

## Just load the platform_status.json file and return the dictionary from it.
func _get_platform_status() -> Dictionary:
	# TODO: Cache this.
	var platform_status_json : Dictionary = load(
		get_script().resource_path.get_base_dir().path_join(
			"platform_status.json")).data
	return platform_status_json

#endregion

#region Cache path wrangling

func _remove_archive_extensions(s : String) -> String:
	for ext in [ ".tar.gz", ".tar.zst"]:
		if s.ends_with(ext):
			s = s.substr(0, len(s) - len(ext))
	return s

## Get the cache path, relative to the user data dir. For use at runtime.
## Returns based on settings for the current runtime OS.
##
## Example return value:
##   "_python_dist/cpython-3.12.5+20240814-x86_64-unknown-linux-gnu-install_only_stripped"
func _get_cache_path_relative():
	var platform_status : Dictionary = _get_platform_status()
	var platform_status_this_platform : Dictionary = platform_status[OS.get_name()]
	var filename : String = platform_status_this_platform["complete_filename"]
	var ret : String = "_python_dist".path_join(_remove_archive_extensions(filename))
	return ret

## Get the full cache path, as understood by the OS.
##
## Example return value:
##   "/home/kiri/.local/share/godot/app_userdata/GodotJSONRPCTest/_python_dist/cpython-3.12.5+20240814-x86_64-unknown-linux-gnu-install_only_stripped"
func _get_script_cache_path_system() -> String:
	return OS.get_user_data_dir().path_join(_get_cache_path_relative()).path_join("packaged_scripts")

## Get the full cache path, as understood by Godot.
##
## Example return value:
##   "user://_python_dist/20240415/3.12.3"
func _get_cache_path_godot() -> String:
	return "user://".path_join(_get_cache_path_relative())

#endregion

#region Public API

# Get the expected path to the Python executable. This is where we think it'll
# end up, not where it actually did end up. This can be called without actually
# extracting the archive. In fact, we need it to act that way because we use it
# to determine if there's already a Python install in-place.
#
# Path is a Godot path. Use ProjectSettings.globalize_path() to conver to a
# system path.
#
# Example return:
#   "user://_python_dist/20240415/3.12.3/python/install/bin/python3"
func get_runtime_python_executable_godot_path() -> String:
	#var base_dir = _get_cache_path_godot().path_join("python/install")
	#if OS.get_name() == "Windows":
		#return base_dir.path_join("python.exe")
	#else:
		#return base_dir.path_join("bin/python3")
		
	var cache_status : Dictionary = get_cache_status()
	var ret = _get_cache_path_godot().path_join(cache_status["executable_path"])
	print(ret)
	return ret
	
	# TODO: Other platforms (macos).

# Get system path for the Python executable, which is what we actually need to
# use to execute it in most cases.
#
# Example return:
#   "home/<user>/.local/share/godot/app_userdata/<project>/_python_dist/20240415/3.12.3/python/install/bin/python3"
func get_runtime_python_executable_system_path() -> String:
	return ProjectSettings.globalize_path(get_runtime_python_executable_godot_path())

func get_cache_status() -> Dictionary:
	var cache_status = {}
	var cache_path_godot : String = _get_cache_path_godot()
	var cache_status_filename : String = cache_path_godot.path_join(".completed_unpack")
	if FileAccess.file_exists(cache_status_filename):
		var cache_status_json : String = FileAccess.get_file_as_string(cache_status_filename)
		cache_status = JSON.parse_string(cache_status_json)
	return cache_status

func write_cache_status(cache_status : Dictionary):
	var cache_path_godot : String = _get_cache_path_godot()
	var cache_status_filename : String = cache_path_godot.path_join(".completed_unpack")
	var cache_status_json = JSON.stringify(cache_status)
	var cache_status_file : FileAccess = FileAccess.open(cache_status_filename, FileAccess.WRITE)
	cache_status_file.store_string(cache_status_json)
	cache_status_file.close()

func unpack_python(overwrite : bool = false):

	var cache_path_godot : String = _get_cache_path_godot()

	# Open archive.
	var python_archive_path : String = _detect_archive_for_runtime()
	var reader : KiriTARReader = KiriTARReader.new()
	var err : Error = reader.open(python_archive_path)
	
	# If you hit this assert, you probably need to download the right Python
	# build using the Python Builds tab down at the bottom.
	assert(err == OK)

	var cache_status_filename : String = cache_path_godot.path_join(".completed_unpack")

	# Check to see if we've marked this as completely unpacked.
	var tar_hash : String = reader.get_tar_hash()
	var cache_status : Dictionary = get_cache_status()
	if not overwrite:
		if cache_status.has("completed_install_hash"):
			if cache_status["completed_install_hash"] == tar_hash:
				# This appears to already be completely unpacked.
				return

	# Get files.
	var file_list : PackedStringArray = reader.get_files()

	# Extract files.
	for relative_filename : String in file_list:
		reader.unpack_file(cache_path_godot, relative_filename)

	# Detect Python executable.
	var possible_executable_paths = []
	if OS.get_name() == "Windows":
		possible_executable_paths.append("python/install/python.exe")
		possible_executable_paths.append("python/python.exe")
	else:
		possible_executable_paths.append("python/bin/python")
		possible_executable_paths.append("python/install/bin/python")
		# FIXME: Verify that these are the same in macOS.
	for possible_path in possible_executable_paths:
		if FileAccess.file_exists(cache_path_godot.path_join(possible_path)):
			cache_status["executable_path"] = possible_path
			print("Found executable: ", possible_path)
			break

	# Mark this as completely unpacked and write out some metadata.
	print("Writing unpacked marker.")
	cache_status["completed_install_hash"] = tar_hash
	write_cache_status(cache_status)

# TODO: Clear cache function. Uninstall Python, etc.

func get_extra_scripts_list() -> Array:

	var script_path : String = get_script().resource_path
	var script_dir : String = script_path.get_base_dir()
	var python_wrapper_manifset_path = script_dir.path_join(
		"KiriPythonWrapperPythonFiles.json")
	
	# If this is running an actual build, we'll just return the manifest here.
	if FileAccess.file_exists(python_wrapper_manifset_path):
		return load(python_wrapper_manifset_path).data

	# If it's not running an actual build, we need to scan for extra Python
	# files.
	
	# First pass: Find all the .kiri_export_python markers in the entire project
	# tree.
	var extra_python_files : Array = []
	var scan_dir_list = ["res://"]
	var verified_script_bundles = []
	while len(scan_dir_list):
		var current_dir : String = scan_dir_list.pop_front()
		var da : DirAccess = DirAccess.open(current_dir)

		if da.file_exists(".kiri_export_python"):
			verified_script_bundles.append(current_dir)
		else:

			# Add all directories to the scan list.
			da.include_navigational = false
			var dir_list = da.get_directories()
			for dir in dir_list:
				if dir == "__pycache__":
					continue
				scan_dir_list.append(current_dir.path_join(dir))

	# Second pass: Add everything under a directory containing a
	# .kiri_export_python marker.
	scan_dir_list = verified_script_bundles
	while len(scan_dir_list):
		var current_dir : String = scan_dir_list.pop_front()
		var da : DirAccess = DirAccess.open(current_dir)

		# Add all directories to the scan list.
		da.include_navigational = false
		var dir_list = da.get_directories()
		for dir in dir_list:
			if dir == "__pycache__":
				continue
			scan_dir_list.append(current_dir.path_join(dir))
	
		# Add all Python files.
		var file_list = da.get_files()
		for file in file_list:
			var full_file = current_dir.path_join(file)
			extra_python_files.append(full_file)

	## FIXME: Remove this.
	#for f in extra_python_files:
		#print("Extra file: ", f)

	return extra_python_files

#endregion
