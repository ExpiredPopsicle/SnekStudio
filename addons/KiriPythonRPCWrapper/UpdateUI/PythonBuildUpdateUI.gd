@tool
extends Control

# These names must match the output from OS.get_name(). 
var _platform_list : Array = [
	"Linux",
	"Windows",
	"macOS"
]

# Last processed asset list (either from cache or GitHub).
var _asset_list = []

# Current request for the GitHub release info.
var _current_request : HTTPRequest = null

# Current downloads (HTTPRequests) of builds indexed by platform.
var _current_downloads : Dictionary = {}

var _platform_dropdowns : Dictionary = {}
var _platform_buttons : Dictionary = {}

# Current platform status. Loaded from/saved to platform_status.json.
var _platform_status = {}

func _get_platform_status_filename() -> String:
	var script_resource : Resource = get_script()
	return script_resource.resource_path.get_base_dir().path_join(
			"../platform_status.json")

func _load_platform_status():
	var platform_status_in : FileAccess = \
		FileAccess.open(
			_get_platform_status_filename(),
			FileAccess.READ)
	
	if platform_status_in:
		var json_string : String = \
			platform_status_in.get_buffer(1024*1024*1024).get_string_from_utf8()
		_platform_status = JSON.parse_string(json_string)

	else:
		_platform_status = {}
		for platform in _platform_list:
			_platform_status[platform] = {}
			_platform_status[platform]["complete_filename"] = ""
			_platform_status[platform]["download_url"] = ""
			_platform_status[platform]["file_size"] = 0

func _save_platform_status() -> void:
	var platform_status_out : FileAccess = \
		FileAccess.open(
			_get_platform_status_filename(),
			FileAccess.WRITE)
	platform_status_out.store_buffer(
		JSON.stringify(_platform_status).to_utf8_buffer())

func _dropdown_selected(item_index : int, platform_name):
	
	var complete_filename : String = \
		_platform_dropdowns[platform_name].get_item_text(item_index)
	
	for asset in _asset_list:
		if asset["complete_filename"] == complete_filename:
			_platform_status[platform_name] = asset
			break
	
	_save_platform_status()
	_update_platform_ui()

func _ready() -> void:
	
	# FIXME: Remove this.
	get_viewport().transparent_bg = false
	
	# Setup UI.
	for platform_name in _platform_list:
		var platform_label : Label = Label.new()
		platform_label.text = platform_name

		var platform_dropdown : OptionButton = OptionButton.new()
		platform_dropdown.item_selected.connect(
			self._dropdown_selected.bind(platform_name))
		platform_dropdown.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_platform_dropdowns[platform_name] = platform_dropdown

		var platform_download : Button = Button.new()
		_platform_buttons[platform_name] = platform_download
		platform_download.pressed.connect(
			self._start_github_download.bind(platform_name))

		var platform_exe_path : Label = Label.new()

		%PlatformGridContainer.add_child(platform_label)
		%PlatformGridContainer.add_child(platform_dropdown)
		%PlatformGridContainer.add_child(platform_download)

	# Load platform status.
	_load_platform_status()
	
	# Load the cached release info from last time we fetched the release asset
	# list from GitHub.
	_update_asset_list_from_cache()

	# Update UI.
	_update_platform_dropdowns()
	_update_platform_ui()

func _get_platform_filename_from_current_status(platform_name : String) -> String:
	var this_platform_status : Dictionary = _platform_status[platform_name]
	var file_path : String = get_script().resource_path.get_base_dir().path_join(
		"../StandalonePythonBuilds").path_join(
		this_platform_status["complete_filename"])
	return file_path

func _check_platform_file_ready(platform_name : String) -> bool:
	var this_platform_status : Dictionary = _platform_status[platform_name]
	var file_path : String = _get_platform_filename_from_current_status(platform_name)

	# Does the file even exist?
	var the_file : FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if not the_file:
		return false

	# Does the file size match?
	if the_file.get_length() != this_platform_status["file_size"]:
		return false

	return true

func _update_platform_dropdowns():

	# We're going to check this and just completely redo the entire thing every
	# time we find files that need to be added to the list (because they were
	# previously selected).
	var do_it_again = true
	while do_it_again:
		do_it_again = false

		for platform in _platform_list:
			_platform_dropdowns[platform].clear()
			
			# Add everything from the asset list.
			for item in _asset_list:
				_platform_dropdowns[platform].add_item(item["complete_filename"])

			# Re-select the currently selected thing.
			var current_fname = _platform_status[platform]["complete_filename"]
			var found_file : bool = false
			for i in range(0, len(_asset_list)):
				var asset = _asset_list[i]
				if asset["complete_filename"] == current_fname:
					_platform_dropdowns[platform].select(i)
					found_file = true
					break

			# If we didn't find the selected file, then add it to the asset list,
			# add it to the UI, then select it.
			#
			# This will happen when the currently selected file is not in an updated
			# (newer release) asset list.
			if not found_file:
				do_it_again = true
				_asset_list.append(_platform_status[platform])
				_platform_dropdowns[platform].add_item(current_fname)
				_platform_dropdowns[platform].select(len(_asset_list) - 1)

func _update_download_button_progress():
	for platform_name in _current_downloads.keys():
		_platform_buttons[platform_name].disabled = true

		if _current_downloads[platform_name].get_body_size() == -1:
			# We still don't know what the remote file size is.
			_platform_buttons[platform_name].text = "Starting..."
		else:
			# Change the button text to show a download percentage.
			var download_percent : float = 100.0 * \
				_current_downloads[platform_name].get_downloaded_bytes() / \
				_current_downloads[platform_name].get_body_size()
			_platform_buttons[platform_name].text = "Downloading: " + \
				str(int(download_percent)) + "%"

func _process(_delta : float):
	_update_download_button_progress()

func _update_platform_ui():
	for platform_name in _platform_list:
		
		# FIXME: Remove this.
		_check_platform_file_ready(platform_name)
		
		var this_platform_status : Dictionary = _platform_status[platform_name]
		if this_platform_status["file_size"] == 0 or \
			len(this_platform_status["complete_filename"]) == 0:
			# No file is even selected yet.
			_platform_buttons[platform_name].disabled = true
			_platform_buttons[platform_name].text = "Not ready"
		elif _check_platform_file_ready(platform_name):
			# File is selected, exists, and is the right size.
			_platform_buttons[platform_name].disabled = true
			_platform_buttons[platform_name].text = "Downloaded"
		elif _current_downloads.has(platform_name):
			# Do nothing here now. Will update this in _update_download_button_progress.
			pass
		else:
			# File is selected, but might not exist yet, or is incomplete.
			_platform_buttons[platform_name].disabled = false
			_platform_buttons[platform_name].text = "Download"

	_update_download_button_progress()

# Split up a string based on multiple delimeters.
#
# Used for sorting asset lists, so Python 3.9 shows up before Python 3.10.
func _multi_delimit_split(s : String, delimeters : PackedStringArray) -> PackedStringArray:

	var out_array : PackedStringArray = []
	var current_str : String = ""

	for c in s:
		if c in delimeters:
			if len(current_str):
				out_array.append(current_str)
			current_str = ""
		else:
			current_str += c

	if len(current_str):
		out_array.append(current_str)

	return out_array

# Sort assets by filename, such that Python 3.9 shows up before Python 3.10,
# where it wouldn't normally if we weren't aware of the version numbers.
func _compare_assets(a, b):
	var split_a : PackedStringArray = _multi_delimit_split(
		a["complete_filename"], ["-", "+", "."])
	var split_b : PackedStringArray = _multi_delimit_split(
		b["complete_filename"], ["-", "+", "."])
	
	var sort_items_a : PackedStringArray = []
	for item in split_a:
		if item.is_valid_int():
			item = _embiggen_string_with_zeros(item, 8)
		sort_items_a.append(item)
	
	var sort_items_b : PackedStringArray = []
	for item in split_b:
		if item.is_valid_int():
			item = _embiggen_string_with_zeros(item, 8)
		sort_items_b.append(item)

	var sort_str_a : String = "-".join(sort_items_a)
	var sort_str_b : String = "-".join(sort_items_b)
	
	a["sort"] = sort_str_a
	b["sort"] = sort_str_b

	return sort_str_a < sort_str_b

func _sort_asset_list():
	_asset_list.sort_custom(_compare_assets)

func _handle_download_finished(
	result: int, response_code: int,
	headers: PackedStringArray, body: PackedByteArray,
	platform_name : String):

	# Write the file, if it succeeded.
	if result == OK and response_code == 200:
		var output_filename : String = \
			_get_platform_filename_from_current_status(platform_name)
		var out_file : FileAccess = FileAccess.open(
			output_filename, FileAccess.WRITE)
		out_file.store_buffer(body)

	# Clean up.
	_current_downloads[platform_name].queue_free()
	_current_downloads.erase(platform_name)

	# Update UI.
	_update_platform_ui()

func _start_github_download(platform : String):
	assert(not _current_downloads.has(platform))
	var _current_request = HTTPRequest.new()
	add_child(_current_request)
	_current_downloads[platform] = _current_request
	_current_request.request_completed.connect(
		self._handle_download_finished.bind(platform))
	_current_request.request(
		_platform_status[platform]["download_url"], [],
		HTTPClient.METHOD_GET)
	_update_platform_ui()
	return _current_request

func _send_github_request(url : String, callback : Callable):
	assert(not _current_request)

	_current_request = HTTPRequest.new()
	_current_request.request_completed.connect(callback)
	add_child(_current_request)

	_current_request.request(
		"https://api.github.com/repos/indygreg/python-build-standalone/releases/latest",
		["Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28"],
		HTTPClient.METHOD_GET)

func _cleanup_request():
	if _current_request:
		_current_request.queue_free()
		_current_request = null

func _on_update_button_pressed():
	$Button_UpdateReleaseAssets.disabled = true
	_send_github_request(
		"https://api.github.com/repos/indygreg/python-build-standalone/releases/latest",
		self._get_latest_version_releaseinfo_completed)

func _embiggen_string_with_zeros(s : String, length_to_embiggen : int):
	while len(s) < length_to_embiggen:
		s = "0" + s
	return s

func _embiggen_string(s : String, length_to_embiggen : int):
	while len(s) < length_to_embiggen:
		s += " "
	return s

func _update_asset_list_from_cache() -> void:
	var buf : PackedByteArray = _load_asset_list_cache()
	_get_latest_version_releaseinfo_completed(0, 200, [], buf)

func _get_github_release_cache_filename() -> String:
	var script_resource : Resource = get_script()
	var cache_path : String = \
		script_resource.resource_path.get_base_dir().path_join(
			"../github_release_cache.json")
	return cache_path

func _save_asset_list_cache(body : PackedByteArray):
	var cache_file_out : FileAccess = \
		FileAccess.open(_get_github_release_cache_filename(), FileAccess.WRITE)
	cache_file_out.store_buffer(body)

func _load_asset_list_cache() -> PackedByteArray:
	var cache_file_in : FileAccess = \
		FileAccess.open(_get_github_release_cache_filename(), FileAccess.READ)
	if cache_file_in:
		return cache_file_in.get_buffer(1024*1024*1024)
	return JSON.stringify({ "assets" : [] }).to_utf8_buffer()

func _get_latest_version_releaseinfo_completed(
	result: int, response_code: int,
	headers: PackedStringArray, body: PackedByteArray):

	_asset_list.clear()

	if result == OK and response_code == 200:

		_save_asset_list_cache(body)

		var release_info : Dictionary = JSON.parse_string(
			body.get_string_from_utf8())
		
		var remote_asset_list : Array = release_info["assets"]
		
		for asset in remote_asset_list:
			var asset_filename : String = asset["name"]
			
			# Don't really care about these. We *could* check them after basic
			# functionality is added.
			if asset_filename.ends_with(".sha256"):
				continue

			# Split filename into parts based on the dashes.
			var asset_filename_parts : PackedStringArray = \
				asset_filename.split("-")
			if len(asset_filename_parts) < 5:
				# Misc files that aren't the archives we're looking for.
				continue

			# Split off the extension from the last part. We don't do this right
			# away because the version number contains dots, so we want to do it
			# with a piece of the filename that probably doesn't have them.
			var asset_filename_last_part_and_extension : PackedStringArray = \
				asset_filename_parts[len(asset_filename_parts)-1].split(".", false, 1)
			
			if len(asset_filename_last_part_and_extension) < 2:
				# Misc files that aren't the archives we're looking for.
				continue
			
			var dict_entry : Dictionary = {}
			
			dict_entry["complete_filename"] = asset["name"]
			dict_entry["download_url"] = asset["browser_download_url"]
			dict_entry["file_size"] = int(asset["size"])
			
			_asset_list.append(dict_entry)
		
		_sort_asset_list()
		_update_platform_dropdowns()
		_update_platform_ui()

	%Button_UpdateReleaseAssets.disabled = false
	_cleanup_request()