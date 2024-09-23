extends RefCounted
class_name DirAccessWithMods

# List of every filename
static var pack_files_added : PackedStringArray = []
static var pack_directories_added : PackedStringArray = []

static func add_zip(zip_path : String):
	
	var zr : ZIPReader = ZIPReader.new()
	if zr.open(zip_path) != OK:
		push_error("Bad zip file: ", zip_path)
		return
	
	# Add all files to our manifest.
	var zip_files = zr.get_files()
	for filename_in_zip in zip_files:
		var full_resource_path : String = "res://".path_join(filename_in_zip)
		var dir_path : String = full_resource_path.get_base_dir()
		pack_files_added.append(full_resource_path)
		
		if not dir_path in pack_directories_added:
			pack_directories_added.append(dir_path)
		
	
	ProjectSettings.load_resource_pack(zip_path, false)

static func get_file_list(path):

	var out_list = []

	var paths_to_search = []

	if path.is_absolute_path():
		paths_to_search.append(path)
	else:
		paths_to_search.append(
			OS.get_executable_path().get_base_dir().path_join(path))
		paths_to_search.append("res://".path_join(path))

	for path_to_search in paths_to_search:
	
		var dir = DirAccess.open(path_to_search)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
					
				# Filter out directories.
				if not dir.current_is_dir():
					out_list.append(file_name)

				file_name = dir.get_next()
	
	# Add all files from ZIPs or PCKs.
	for pack_file in pack_files_added:
		if pack_file.get_base_dir() == path:
			out_list.append(pack_file)
	
	# FIXME: Remove this.
	#var manifest_file : FileAccess = FileAccess.open("res://file_manifest.txt", FileAccess.READ)
	#var manifest_contents = manifest_file.get_as_text()
	#var manifest_lines = manifest_contents.split("\n")
	#for line in manifest_lines:
		#
		#line = OS.get_executable_path().get_base_dir().path_join(line)
		#
		#print("path:     ", path)
		#print("line:     ", line)
		#print("base_dir: ", line.get_base_dir())
		#if line.get_base_dir() == path:
			#var file_name_to_add = line.get_file()
			#if not line in out_list:
				#out_list.append(line.get_file())

	return out_list
	
static func get_directory_list(path):

	var out_list = []
	
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
				
			# Filter out normal files.
			if dir.current_is_dir():
				out_list.append(file_name)

			file_name = dir.get_next()

	# Add all directories from ZIPs or PCKs.
	for pack_dir in pack_directories_added:
		if pack_dir.get_base_dir() == path:
			out_list.append(pack_dir)
	
	# FIXME: Remove this.
	#var manifest_file : FileAccess = FileAccess.open("res://file_manifest.txt", FileAccess.READ)
	#var manifest_contents = manifest_file.get_as_text()
	#var manifest_lines = manifest_contents.split("\n")
	#for line in manifest_lines:
		#if line.get_base_dir().get_base_dir() == path:
			#var dir_name_to_append = line.get_base_dir().get_file()
			#if not dir_name_to_append in out_list:
				#out_list.append(dir_name_to_append)

	return out_list
