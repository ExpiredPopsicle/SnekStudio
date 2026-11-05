@tool
extends EditorPlugin

var exporter_plugin : SnekStudioExporter

func _enter_tree():
	exporter_plugin = SnekStudioExporter.new()
	add_export_plugin(exporter_plugin)

func _exit_tree():
	remove_export_plugin(exporter_plugin)
	exporter_plugin = null


class SnekStudioExporter extends EditorExportPlugin:

	func _get_name():
		return "SnekStudioExporter"

	func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
		# Skip importing sample models. They're included as full files.
		if path.begins_with("res://SampleModels/"): skip()

	# FIXME: Don't copy the MediaPipeController because it has some embedded
	#   scripts that handle the Python packaging separately.

	func _export_begin(_features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
		var export_path := path.get_base_dir()

		# Export all sample models.
		DirAccess.make_dir_recursive_absolute(export_path.path_join("SampleModels"))
		_copy_recursive(export_path.path_join("SampleModels"), "res://SampleModels", "*.vrm")

		# Export all LICENSE files.
		DirAccess.make_dir_recursive_absolute(export_path.path_join("Licenses"))
		_copy_recursive(export_path.path_join("Licenses"), "res://Licenses")

		# Copy our own LICENSE file.
		DirAccess.copy_absolute("res://LICENSE", export_path.path_join("LICENSE.txt"))

		# Create the empty Saved directory, for user settings and stuff.
		DirAccess.make_dir_recursive_absolute(export_path.path_join("Saved"))

	func _copy_recursive(dest : String, src : String, match_string : String = ""):
		# Make the directory to put the thing in.
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())

		if DirAccess.dir_exists_absolute(src):
			# Make the directory.
			print("make_dir_recursive_absolute: ", dest)
			DirAccess.make_dir_recursive_absolute(dest)

			# Copy contents over
			var directory_contents = PackedStringArray()
			directory_contents.append_array(DirAccess.get_directories_at(src))
			directory_contents.append_array(DirAccess.get_files_at(src))
			print("directory contents... ", directory_contents)
			for thing_in_directory in directory_contents:
				_copy_recursive(
					dest.path_join(thing_in_directory),
					src.path_join(thing_in_directory),
					match_string)

		else:
			# Copy the thing.
			if dest.match(match_string) or match_string == "":
				print("Copy file: ", dest, " - ", src)
				DirAccess.copy_absolute(src, dest)
