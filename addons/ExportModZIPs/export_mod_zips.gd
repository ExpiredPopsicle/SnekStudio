@tool
class_name ExportModZIPs
extends EditorExportPlugin

const MODS_PATH := "res://Mods"
const MODS_OUTPUT := "Mods"

const CLASS_TEMPLATE := "{
\"base\": &\"{base}\",
\"class\": &\"{class}\",
\"icon\": \"\",
\"is_abstract\": false,
\"is_tool\": false,
\"language\": &\"GDScript\",
\"path\": \"{path}\"
}"

func _get_name() -> String:
	return "ExportModZIPs"

func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with(MODS_PATH + "/"): skip()

func _export_begin(_features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	var output_mods_path := path.get_base_dir() + "/" + MODS_OUTPUT

	# Ensure the output mods directory exists.
	DirAccess.make_dir_recursive_absolute(output_mods_path)

	# Clear out old mods from the output mods directory.
	for name in DirAccess.get_files_at(output_mods_path):
		DirAccess.remove_absolute(output_mods_path + "/" + name)

	for name in DirAccess.get_directories_at(MODS_PATH):
		var zip := ZIPPacker.new()
		zip.open(output_mods_path + "/" + name + ".zip")

		var files: Array[String]
		_get_files_recursive(MODS_PATH + "/" + name, files)
		for file_path in files: _zip_file(zip, file_path)

		# For modded scripts to be able to refer to each other (and themselves) they need
		# to be known to the engine in its script cache that maps `class_name` to scripts.
		# This is usually done by the engine in its export process, but we do it manually.
		var class_info: PackedStringArray
		for file_path in files:
			if file_path.get_extension() != "gd": continue
			var script: GDScript = load(file_path)

			var global_name := script.get_global_name()
			if global_name == "": continue # doesn't have a `class_name`, skip

			# When extending another user-created GDScript, use its `class_name`,
			# otherwise use the engine's type name (like "Node" or "RefCounted").
			var base := script.get_base_script()
			var base_name := base.get_global_name() if base else script.get_instance_base_type()

			class_info.append(CLASS_TEMPLATE.format({
				"base"  : base_name,
				"class" : global_name,
				"path"  : script.resource_path,
			}))

		if not class_info.is_empty():
			zip.start_file(".godot/global_script_class_cache.cfg")
			zip.write_file(("list=[" + ", ".join(class_info) + "]\n").to_utf8_buffer())
			zip.close_file()

		# Resources reference additional compressed / pre-processed files,
		# listed in their `.import` file, that are exported to `.godot/`.
		for file_path in files:
			if file_path.get_extension() != "import": continue
			var config := ConfigFile.new()
			config.load(file_path)

			for dep_file_path in config.get_value("deps", "dest_files", []):
				_zip_file(zip, dep_file_path)

		zip.close()


static func _get_files_recursive(dir_path: String, result: Array[String]) -> void:
	for name in DirAccess.get_files_at(dir_path):
		result.append(dir_path + "/" + name)
	for name in DirAccess.get_directories_at(dir_path):
		_get_files_recursive(dir_path + "/" + name, result)

static func _zip_file(zip: ZIPPacker, file_path: String) -> void:
	zip.start_file(file_path.trim_prefix("res://"))
	zip.write_file(FileAccess.get_file_as_bytes(file_path))
	zip.close_file()
