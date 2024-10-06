# TARReader
#
# Read .tar.gz and .tar.zst files. Interface mostly identical to ZIPReader.
#
# DO NOT USE THIS ON UNTRUSTED DATA.

extends RefCounted
class_name KiriTARReader

#region Internal data

class TarFileRecord:
	extends RefCounted
	var filename : String
	var offset : int
	var file_size : int
	
	# Unix file permissions.
	#
	# Technically this is an int, but we're just going to leave it as an octal
	# string because that's what we can feed right into chmod.
	var mode : String
	
	# Symlinks.
	var is_link : bool
	var link_destination : String
	
	var is_directory : bool
	
	var type_indicator : String

var _internal_file_list = []
var _internal_file_list_indices = {} # Map filename -> index in _internal_file_list
var _tar_file_cache : PackedByteArray = []
var _tar_file_hash : PackedByteArray = []
var _tar_file_path : String = ""

func _load_record(record : TarFileRecord) -> PackedByteArray:
	load_cache()
	return _tar_file_cache.slice(record.offset, record.offset + record.file_size)

#endregion

#region Cache wrangling

# We have to load the entire .tar file into memory with the way the ZipReader
# API works, but we'll at least include an option to nuke the cache to free up
# memory if you want to just leave the file open.
#
# This lets us avoid re-opening and decompressing the entire .tar every time we
# need something out of it, while still letting us manually free the memory when
# we won't need it for a while.
func clear_cache():
	_tar_file_cache = []

func load_cache() -> Error:
	assert(len(_tar_file_path))

	if len(_tar_file_cache):
		# Cache already in-memory.
		return OK
	
	var buff_size : int = 1024 * 1024 * 512
	var compressed_buffer : PackedByteArray = \
		FileAccess.get_file_as_bytes(_tar_file_path)

	var compression_method : FileAccess.CompressionMode = -1
	if _tar_file_path.ends_with(".tar.gz"):
		compression_method = FileAccess.COMPRESSION_GZIP
	elif _tar_file_path.ends_with(".tar.zst"):
		compression_method = FileAccess.COMPRESSION_ZSTD
	elif _tar_file_path.ends_with(".tar"):
		compression_method = -1
	else:
		return ERR_FILE_UNRECOGNIZED

	if compression_method == -1:
		_tar_file_cache = compressed_buffer
	else:
		var decompressed_data : PackedByteArray = PackedByteArray()
		while len(decompressed_data) == 0:
			decompressed_data = compressed_buffer.decompress(
				buff_size, compression_method)
			buff_size *= 2
			
			if buff_size >= 1024*1024*1024*10:
				return ERR_OUT_OF_MEMORY

		if len(decompressed_data):
			_tar_file_cache = decompressed_data

	if len(_tar_file_cache):
		return OK

	return ERR_FILE_CORRUPT

#endregion

#region Number wrangling

func _octal_str_to_int(s : String) -> int:
	var ret : int = 0;
	var digit_multiplier = 1;
	while len(s):
		var lsb = s.substr(len(s) - 1, 1)
		s = s.substr(0, len(s) - 1)
		ret += digit_multiplier * lsb.to_int()
		digit_multiplier *= 8
	return ret

func _pad_to_512(x : int) -> int:
	var x_lowbits = x & 511
	var x_hibits = x & ~511
	
	if x_lowbits:
		x_hibits += 512
	
	return x_hibits

#endregion

#region Public API

func close() -> Error:
	_internal_file_list = []
	_tar_file_path = ""
	clear_cache()
	return OK

func file_exists(path: String, case_sensitive: bool = true) -> bool:
	for record : TarFileRecord in _internal_file_list:
		if case_sensitive:
			if record.filename == path:
				return true
		else:
			if record.filename.nocasecmp_to(path) == 0:
				return true
	return false

func get_files() -> PackedStringArray:
	var ret : PackedStringArray = []
	for record : TarFileRecord in _internal_file_list:
		ret.append(record.filename)
	return ret

func get_tar_hash():
	return _tar_file_hash.hex_encode()

func open(path: String) -> Error:

	assert(not len(_tar_file_path))
	_tar_file_path = path

	var err : Error = load_cache()
	if err != OK:
		return err

	# Hash it.
	print("Computing tar hash...")
	var hashing : HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(_tar_file_cache)
	_tar_file_hash = hashing.finish()
	print("Done computing tar hash.")

	var tar_file_offset = 0
	var zero_filled_record_count = 0
	var zero_filled_record : PackedByteArray = []
	zero_filled_record.resize(512)
	zero_filled_record.fill(0)
	
	var paxheader_next_file = {}
	var paxheader_global = {}
	
	while tar_file_offset < len(_tar_file_cache):
		var chunk = _tar_file_cache.slice(tar_file_offset, tar_file_offset + 512)
		
		if chunk == zero_filled_record:
			zero_filled_record_count += 1
			if zero_filled_record_count >= 2:
				break
			tar_file_offset += 512
			continue
		
		var tar_record : TarFileRecord = TarFileRecord.new()
		
		var tar_chunk_name = chunk.slice(0, 100)
		var tar_chunk_size = chunk.slice(124, 124+12)
		var tar_chunk_mode = chunk.slice(100, 100+8)
		var tar_chunk_link_indicator = chunk.slice(156, 156+1)
		var tar_chunk_link_file = chunk.slice(157, 157+100)
		
		# FIXME: Technically "ustar\0" but we'll skip the \0
		var tar_ustar_indicator = chunk.slice(257, 257+5)
		var tar_ustar_file_prefix = chunk.slice(345, 345+155)

		# Pluck out the relevant bits we need for the record.
		tar_record.filename = tar_chunk_name.get_string_from_utf8()

		tar_record.file_size = _octal_str_to_int(tar_chunk_size.get_string_from_utf8())
		tar_record.mode = tar_chunk_mode.get_string_from_utf8()
		tar_record.is_link = (tar_chunk_link_indicator[0] != 0 and tar_chunk_link_indicator.get_string_from_utf8()[0] == "2")
		tar_record.link_destination = tar_chunk_link_file.get_string_from_utf8()
		
		tar_record.is_directory = (tar_chunk_link_indicator[0] != 0 and tar_chunk_link_indicator.get_string_from_utf8()[0] == "5")

		if tar_chunk_link_indicator[0] != 0:
			tar_record.type_indicator = tar_chunk_link_indicator.get_string_from_utf8()
		else:
			tar_record.type_indicator = ""
		
		# Append prefix if this is the "ustar" format.
		# TODO: Test this.
		if tar_ustar_indicator.get_string_from_utf8() == "ustar":
			tar_record.filename = \
				tar_ustar_file_prefix.get_string_from_utf8() + \
				tar_record.filename
		
		# TODO: Things we skipped:
		#       - owner id (108, 108+8)
		#       - group id (116, 116+8)
		#       - modification time (136, 136+12)
		#       - checksum (148, 148+8)
		#       - mosty related to USTAR format
		
		# Skip header.
		tar_file_offset += 512

		# Record start offset.
		tar_record.offset = tar_file_offset

		# Skip file contents.
		tar_file_offset += _pad_to_512(tar_record.file_size)
		
		if tar_record.filename.get_file() == "@PaxHeader":
			
			# This is a special file entry that just has some extended data
			# about the next file or all the following files. It's not an actual
			# file.
			var paxheader_data : PackedByteArray = _tar_file_cache.slice(
				tar_record.offset,
				tar_record.offset + tar_record.file_size)
			
			var paxheader_str : String = paxheader_data.get_string_from_utf8()
			
			# FIXME: Do some error checking here.
			var paxheader_lines = paxheader_str.split("\n", false)
			for line in paxheader_lines:
				var length_and_the_rest = line.split(" ")
				var key_and_value = length_and_the_rest[1].split("=")
				var key = key_and_value[0]
				var value = key_and_value[1]

				if tar_record.type_indicator == "x":
					paxheader_next_file[key] = value
				elif tar_record.type_indicator == "g":
					paxheader_global[key] = value

		else:
			
			# Apply paxheader. We're just using "path" for now.
			# See here for other available fields:
			#   https://pubs.opengroup.org/onlinepubs/009695399/utilities/pax.html
			var merged_paxheader : Dictionary = paxheader_global.duplicate()
			merged_paxheader.merge(paxheader_next_file, true)
			paxheader_next_file = {}
			
			if merged_paxheader.has("path"):
				tar_record.filename = merged_paxheader["path"]

			if merged_paxheader.has("linkpath"):
				tar_record.link_destination = merged_paxheader["linkpath"]
			
			# Add it to our record list.
			_internal_file_list_indices[tar_record.filename] = len(_internal_file_list)
			_internal_file_list.append(tar_record)
	
	return OK

# Extract a file into memory as a PackedByteArray.
func read_file(path : String, case_sensitive : bool = true) -> PackedByteArray:

	for record : TarFileRecord in _internal_file_list:
		if case_sensitive:
			if record.filename == path:
				return _load_record(record)
		else:
			if record.filename.nocasecmp_to(path) == 0:
				return _load_record(record)

	return []

func _convert_permissions(tar_mode_str : String) -> FileAccess.UnixPermissionFlags:
	# Okay so this turned out to be easier than I thought. Godot's
	# UnixPermissionFlags line up with the actual permission bits in the tar.
	return _octal_str_to_int(tar_mode_str)


# Extract a file to a specific path. Sets permissions when possible, handles
# symlinks and directories. Will extract to the dest_path plus the internal
# relative path.
#
# Example:
#   dest_path: "foo/bar", filename: "butts/whatever/thingy.txt"
#   extracts to: "foo/bar/butts/whatever/thingy.txt"
func unpack_file(dest_path : String, filename : String, force_overwrite : bool = false):
	var full_dest_path : String = dest_path.path_join(filename)
	DirAccess.make_dir_recursive_absolute(full_dest_path.get_base_dir())
	
	assert(_internal_file_list_indices.has(filename))
	var record : TarFileRecord = _internal_file_list[_internal_file_list_indices[filename]]

	# FIXME: There are probably a million other ways to do directory
	#        traversal attacks than just what we've checked for here.
	if record.filename.is_absolute_path():
		assert(false)
		return
	if record.filename.simplify_path().begins_with(".."):
		assert(false)
		return

	var need_file_made : bool = true
	var need_permission_update : bool = true
	var exists_in_some_way : bool = FileAccess.file_exists(full_dest_path) || DirAccess.dir_exists_absolute(full_dest_path)

	# Check to see if we need to make the dir/file/etc.
	if force_overwrite == false:

		if exists_in_some_way:

			# Link exists. Don't overwrite.
			if record.is_link:
				#print("Skip (link exist): ", full_dest_path)
				# FIXME: Check symlink destination?
				need_file_made = false

			if record.is_directory:
				#print("Skip (dir exist):  ", full_dest_path)
				need_file_made = false

			# If the file is there and it's a complete file, then we're probably
			# done. We can't check or set mtime through Godot's API, though.
			var f : FileAccess = FileAccess.open(full_dest_path, FileAccess.READ)
			if f.get_length() == record.file_size:
				#print("Skip (file exist): ", full_dest_path)
				need_file_made = false
			f.close()

	if not record.is_link and OS.get_name() != "Windows":
		if FileAccess.file_exists(full_dest_path) || DirAccess.dir_exists_absolute(full_dest_path):
			var existing_permissions : FileAccess.UnixPermissionFlags = FileAccess.get_unix_permissions(full_dest_path)
			var wanted_permissions : FileAccess.UnixPermissionFlags = _convert_permissions(record.mode)
			if existing_permissions == wanted_permissions:
				need_permission_update = false
				#print("Permission are fine: ", record.mode, " ", existing_permissions, " ", full_dest_path)
			else:
				print("Permission update needed on existing file: ", record.mode, " ", existing_permissions, " ", full_dest_path)

	if record.is_link:

		# Okay, look. I know that symbolic links technically exist on
		# Windows, but they're messy and hardly ever used. FIXME later
		# if for some reason you need to support that. -Kiri
		assert(OS.get_name() != "Windows")

		# Fire off a command to make a symbolic link on *normal* OSes.
		var err = OS.execute("ln", [
			"-s",
			record.link_destination,
			ProjectSettings.globalize_path(full_dest_path)
		])

		assert(err != -1)
	
	elif record.is_directory:

		# It's just a directory. Make it.
		DirAccess.make_dir_recursive_absolute(full_dest_path)

	else:

		# Okay this is an actual file. Extract it.
		var file_data : PackedByteArray = read_file(record.filename)
		var out_file = FileAccess.open(full_dest_path, FileAccess.WRITE)
		if out_file:
			need_permission_update = true
			out_file.store_buffer(file_data)
			out_file.close()
		else:
			push_error("Can't write file: ", full_dest_path)

	# Set permissions (on normal OSes, not Windows). I don't think this
	# applies to symlinks, though.
	if not record.is_link:
		if need_permission_update:
			if OS.get_name() != "Windows":
				var err : Error = FileAccess.set_unix_permissions(
					full_dest_path, _convert_permissions(record.mode))
				assert(err != -1)

#endregion
