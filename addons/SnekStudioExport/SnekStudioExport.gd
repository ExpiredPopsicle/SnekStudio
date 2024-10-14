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

	# FIXME: Don't copy the MediaPipeController because it has some embedded
	#   scripts that handle the Python packaging separately.

	var _export_path : String

	#func _export_file(path: String, type: String, features: PackedStringArray):
		## Skip export of all the Mods files because we're going to be copying
		## those out manually.
		#if path.begins_with("res://Mods/"):
			#skip()

	func _zip_directory(zip : ZIPPacker, path : String):

		# Get a relative path from root instead of resource path.
		var path_without_res : String = path
		if path_without_res.begins_with("res://"):
			path_without_res = path_without_res.substr(6)

		# Add all files for this directory.
		var file_list : PackedStringArray = DirAccess.get_files_at(path)
		for file_to_export in file_list:
			
			# Add the file...
			zip.start_file(path_without_res.path_join(file_to_export))
			var file_bytes : PackedByteArray = FileAccess.get_file_as_bytes(
				path.path_join(file_to_export))
			zip.write_file(file_bytes)
			
			# Add the remapped resource thingy...
			var import_file_path : String = path.path_join(file_to_export) + ".import"
			if FileAccess.file_exists(import_file_path):
				var config : ConfigFile = ConfigFile.new()
				config.load(import_file_path)
				
				# Write out exported converted thingies.
				var extra_files : PackedStringArray = config.get_value("deps", "dest_files", [])
				for extra_file in extra_files:
					var extra_file_without_resource = extra_file
					if extra_file_without_resource.begins_with("res://"):
						extra_file_without_resource = extra_file_without_resource.substr(6)

					zip.start_file(extra_file_without_resource)
					file_bytes = FileAccess.get_file_as_bytes(extra_file)
					zip.write_file(file_bytes)

		# Recurse for all directories.
		var dir_list : PackedStringArray = DirAccess.get_directories_at(path)
		for dir_to_export in dir_list:
			_zip_directory(zip, path.path_join(dir_to_export))

	func _export_begin(
		features : PackedStringArray, is_debug : bool,
		path : String, flags : int):
		
		_export_path = path.get_base_dir()

		# Export all mods as .zip files.
		DirAccess.make_dir_recursive_absolute(_export_path.path_join("Mods"))
		var mods_list : PackedStringArray = DirAccess.get_directories_at("res://Mods")
		for mod_to_export in mods_list:
			var zp : ZIPPacker = ZIPPacker.new()
			zp.open(_export_path.path_join("Mods").path_join(mod_to_export + ".zip"))
			_zip_directory(zp, "res://Mods".path_join(mod_to_export))
			zp.close()

		# Export all sample models.
		DirAccess.make_dir_recursive_absolute(_export_path.path_join("SampleModels"))
		copy_recursive(
			_export_path.path_join("SampleModels"),
			"res://SampleModels",
			"*.vrm")

		# Export all LICENSE files.
		DirAccess.make_dir_recursive_absolute(_export_path.path_join("Licenses"))
		copy_recursive(_export_path.path_join("Licenses"), "res://Licenses")

		# Copy our own LICENSE file.
		DirAccess.copy_absolute("res://LICENSE", _export_path.path_join("LICENSE.txt"))

	func copy_recursive(dest : String, src : String, match_string : String = ""):
		
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
				copy_recursive(
					dest.path_join(thing_in_directory),
					src.path_join(thing_in_directory),
					match_string)
			
		else:

			# Copy the thing.
			if dest.match(match_string) or match_string == "":
				print("Copy file: ", dest, " - ", src)
				DirAccess.copy_absolute(src, dest)
		
		

	func _export_file(path : String, type : String, features : PackedStringArray):
		# TODO: Don't pack files in the Mods/ directory. Copy them instead.
		
		var mods_path = "res://Mods/"
		if path.begins_with(mods_path):
			skip()

		if path.begins_with("res://SampleModels/"):
			skip()

	func _get_name():
		return "SnekStudioExporter"
