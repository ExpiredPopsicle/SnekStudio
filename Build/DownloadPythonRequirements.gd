# FIXME: This file is kinda rough. We should probably clean it up. But we need
#   build automation NOW.

extends SceneTree

var updater = null
var frame_count = 0

func _initialize():
	pass

func _process(_delta):
	
	if frame_count == 0:

		# Instantiate the updater.
		updater = load("res://addons/KiriPythonRPCWrapper/UpdateUI/PythonBuildUpdateUI.tscn").instantiate()
		root.add_child(updater)

		# Start Python downloads per-platform.
		updater._start_github_download("Windows")
		updater._start_github_download("Linux")
		# FIXME: MacOS.

		for platform in updater._current_downloads.keys():
			var download_request : HTTPRequest = updater._current_downloads[platform]
			download_request.request_completed.connect(
				func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
					if result == HTTPRequest.RESULT_SUCCESS and response_code == 200:
						print("Download finished (", response_code, ") for platform: ", platform)
					else:
						push_error("Download failed (", result, ") (", response_code, ") for platform: ", platform)
						quit(1))

	# FIXME: Add MacOS.
	if updater._check_platform_file_ready("Windows") and \
		updater._check_platform_file_ready("Linux"):

		# Download pip requirements.
		var succeeded = true
		if not updater.download_platform_requirements("Windows", true):
			succeeded = false
		if not updater.download_platform_requirements("Linux", true):
			succeeded = false
		# FIXME: MacOS.

		if not succeeded:
			push_error("Something went wrong!")
			quit(1)

		# We're done! Wrap it up.
		updater.queue_free()
		return true

	# Keep going.
	frame_count += 1
	return false

func _finalize():
	pass
