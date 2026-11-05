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

		# Resources reference additional compressed / pre-processed files,
		# listed in their `.import` file, that are exported to `.godot/`.
		for config: ConfigFile in files.filter(_is_extension.bind("import")).map(_load_config_file):
			for dep_file_path in config.get_value("deps", "dest_files", []):
				_zip_file(zip, dep_file_path)

		zip.close()


static func _is_extension(file_path: String, ext: String) -> bool:
	return (file_path.get_extension() == ext)

static func _load_config_file(file_path: String) -> ConfigFile:
	var config := ConfigFile.new()
	config.load(file_path)
	return config

static func _get_files_recursive(dir_path: String, result: Array[String]) -> void:
	for name in DirAccess.get_files_at(dir_path):
		result.append(dir_path + "/" + name)
	for name in DirAccess.get_directories_at(dir_path):
		_get_files_recursive(dir_path + "/" + name, result)

static func _zip_file(zip: ZIPPacker, file_path: String) -> void:
	zip.start_file(file_path.trim_prefix("res://"))
	zip.write_file(FileAccess.get_file_as_bytes(file_path))
	zip.close_file()
