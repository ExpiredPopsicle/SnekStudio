# Python build export plugin
#
# This just makes sure that the specific Python build for whatever platform we
# need gets bundled into the build for that platform, so that it can be unpacked
# and used later by KiriPythonBuildWrangler.

@tool
extends EditorExportPlugin
class_name KiriPythonBuildExportPlugin

func _get_name() -> String:
	return "KiriPythonBuildExportPlugin"

func _export_begin(
	features : PackedStringArray, is_debug : bool,
	path : String, flags : int):

	var build_wrangler : KiriPythonBuildWrangler = KiriPythonBuildWrangler.new()

	var platform_list = []

	if "linux" in features:
		platform_list.append("Linux")
	if "windows" in features:
		platform_list.append("Windows")
	# FIXME: MacOS stuff

	
	# TODO: Other platforms (macos)
	
	for platform in platform_list:
		var archive_to_export = build_wrangler._detect_archive_for_build(platform)
		var file_contents : PackedByteArray = FileAccess.get_file_as_bytes(archive_to_export)
		add_file(archive_to_export, file_contents, false)

	# Make sure all the RPC wrapper scripts make it in.
	var script_path : String = get_script().resource_path
	var script_dir : String = script_path.get_base_dir()

	# Actually add all the files.
	var extra_python_files = build_wrangler.get_extra_scripts_list(platform_list)
	for extra_python_file : String in extra_python_files:
		var file_bytes : PackedByteArray = FileAccess.get_file_as_bytes(extra_python_file)
		add_file(extra_python_file, file_bytes, false)

	# Add the list of Python files as its own file so we know what to extract so
	# it's visible to Python.
	var python_wrapper_manifest_str : String = JSON.stringify(extra_python_files, "    ")
	var python_wrapper_manifest_bytes : PackedByteArray = \
		python_wrapper_manifest_str.to_utf8_buffer()
	var python_wrapper_manifset_path = script_dir.path_join(
		"KiriPythonWrapperPythonFiles.json")
	add_file(python_wrapper_manifset_path, python_wrapper_manifest_bytes, false)
