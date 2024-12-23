extends RefCounted
class_name KiriPythonWrapperInstance

enum KiriPythonWrapperStatus {
	STATUS_RUNNING,
	STATUS_STOPPED
}

class KiriPythonWrapperActiveRequest:
	
	enum KiriPythonWrapperActiveRequestState {
		STATE_WAITING_TO_SEND,
		STATE_SENT,
		STATE_RESPONSE_RECEIVED
	}
	
	var id : int
	var method_name : String
	var arguments : Variant # Dictionary or Array
	var callback # Callable or null
	var state : KiriPythonWrapperActiveRequestState
	var response # Return value from the call
	var error_response = ""

var _active_request_queue = {}
var _request_counter = 0

var _server_packet_socket : KiriPacketSocket = null
var communication_packet_socket : KiriPacketSocket = null

var python_script_path : String = ""

var _build_wrangler : KiriPythonBuildWrangler = null

var _external_process_pid = -1

signal _rpc_async_response_received


func _init(python_file_path : String):
	_build_wrangler = KiriPythonBuildWrangler.new()
	python_script_path = python_file_path

func _get_python_executable():
	return _build_wrangler.get_runtime_python_executable_system_path()

func _get_wrapper_script():
	# FIXME: Paths will be different for builds.
	var script_path = self.get_script().get_path()
	var script_dirname = script_path.get_base_dir()
	return ProjectSettings.globalize_path( \
		script_dirname + "/KiriPythonRPCWrapper_start.py")

func _get_wrapper_cache_path() -> String:
	return _build_wrangler._get_cache_path_godot().path_join("packaged_scripts")

func _get_wrapper_script_cache_path() -> String:
	return _get_wrapper_cache_path().path_join("addons/KiriPythonRPCWrapper/KiriPythonRPCWrapper/__init__.py")

## Unpack and setup Python, if necessary.
##
## FIXME: For now, use force_unpack_extras in development and after an update to
## get updates to the wrapper script and Project-specific Python code.
func setup_python(force_unpack_extras : bool = false):

	# Determine if we need to purge the cache based on what we're expecting to
	# see version-wise vs what's actually represented there.
	var needs_purge : bool = false
	var platform_status = _build_wrangler._get_platform_status()
	var cache_status = _build_wrangler.get_cache_status()
	if cache_status.has("requirements_installed"):
		if cache_status["requirements_installed"] != platform_status["requirements"]:
			# Has the requirements field, and it's changed since we installed
			# last.
			needs_purge = true
		else:
			pass # No purge. Everything matches.
	else:
		# Doesn't have the requirements field. Possible indicator of a partial
		# install.
		needs_purge = true

	# If we're running a build, let's see if the build's packaged version
	# matches what we see in the cache.
	var data_hash = _build_wrangler.get_extra_scripts_hash()
	if data_hash != null: # If it's null then we're just running in the editor.
		if cache_status.has("extra_data_hash"):
			if cache_status["extra_data_hash"] != data_hash:
				# Stale data detected. Purge it.
				needs_purge = true
			else:
				pass # Hashes match. Do nothing.
		else:
			# No hash marker at all? Purge it just to be safe.
			needs_purge = true

	# Purge it if needed.
	if needs_purge:
		_build_wrangler.purge_cached_python()

	# Unpack base Python build.
	if _build_wrangler.unpack_python() == false:
		OS.alert("Unpacking Python failed!")
		return false

	# Determine if we need to install whl files and unpack wrapper scripts.
	var needs_setup = true
	platform_status = _build_wrangler._get_platform_status()
	cache_status = _build_wrangler.get_cache_status()
	if cache_status.has("requirements_installed"):
		if cache_status["requirements_installed"] == platform_status["requirements"]:
			needs_setup = false

	# Unpack Python wrapper, whl files, and project-specific scripts.
	if needs_setup or force_unpack_extras or data_hash == null:

		var extra_scripts = _build_wrangler.get_extra_scripts_list()

		for extra_script : String in extra_scripts:
			
			# Chop off the "res://".
			var extra_script_relative : String = extra_script.substr(len("res://"))

			# Some other path wrangling.
			var extraction_path : String = _get_wrapper_cache_path().path_join(extra_script_relative)
			var extraction_path_dir : String = extraction_path.get_base_dir()
			
			# Make the dir.
			DirAccess.make_dir_recursive_absolute(extraction_path_dir)
			
			# Extract the file.
			var bytes : PackedByteArray = FileAccess.get_file_as_bytes(extra_script)
			FileAccess.open(extraction_path, FileAccess.WRITE).store_buffer(bytes)

	# Run pip to install packages from .whl files.
	var successfully_ran_pip_setup : bool = false
	if needs_setup:
		
		# Get a list of all the wheel files.
		var wheels_path : String = _build_wrangler._get_cache_path_godot().path_join("packaged_scripts/addons/KiriPythonRPCWrapper/Wheels")
		if DirAccess.dir_exists_absolute(wheels_path):
			var platform_wheels_path = wheels_path.path_join(KiriPythonBuildWrangler.get_host_os_name())
			var wheel_list : PackedStringArray = DirAccess.get_files_at(platform_wheels_path)

			if len(wheel_list):

				var pip_args : PackedStringArray = [
					"-m", "pip", "install",
				]

				# Add every wheel file in the directory as an argument.
				for wheel in wheel_list:
					if wheel.ends_with(".whl"):
						pip_args.append(ProjectSettings.globalize_path(platform_wheels_path.path_join(wheel)))

				# Run pip.
				var output : Array = []
				var pip_result = execute_python(pip_args, output, true, false)
				if pip_result != 0:
					OS.alert("Pip installation failed!\n" + "\n".join(output))
					return false

				successfully_ran_pip_setup = true

			else:
				print("No wheel files detected. Skipping pip install.")
		else:
			print("Wheel directory does not exist. Skipping pip install.")

	# FIXME: Delete wheel files? I don't think we need them anymore. If we made
	# it this far, then we know we succeeded at the install.
	
	# Write success marker.
	if successfully_ran_pip_setup:
		cache_status = _build_wrangler.get_cache_status()
		cache_status["requirements_installed"] = platform_status["requirements"]
		if data_hash != null:
			cache_status["extra_data_hash"] = data_hash
		_build_wrangler.write_cache_status(cache_status)
	
	return true

func get_status():

	if _external_process_pid == -1:
		return KiriPythonWrapperStatus.STATUS_STOPPED

	if not OS.is_process_running(_external_process_pid):
		return KiriPythonWrapperStatus.STATUS_STOPPED

	return KiriPythonWrapperStatus.STATUS_RUNNING

func run_python_command(
	args : PackedStringArray,
	output : Array = [],
	read_stderr : bool = false,
	open_console : bool = false):

	var python_exe_path : String = _get_python_executable()
	
	# Do a little switcheroo on Linux to open a console.
	# FIXME: Remove this?
	if open_console:
		if OS.get_name() == "Linux":
			args = PackedStringArray(["-e", python_exe_path]) + args
			python_exe_path = "xterm"
	
	return OS.execute(python_exe_path, args, output, read_stderr, open_console)

func convert_cache_item_to_real_path(path : String):
	var real_python_script_path = path
	if real_python_script_path.begins_with("res://"):
		var real_python_script_path_without_res : String = real_python_script_path.substr(len("res://"))
		var script_cache_path_system : String = _build_wrangler._get_script_cache_path_system()
		real_python_script_path = script_cache_path_system.path_join(
			real_python_script_path_without_res)
	else:
		real_python_script_path = ProjectSettings.globalize_path(
			real_python_script_path)
	return real_python_script_path

func execute_python_async(arguments : PackedStringArray):

	var thread : Thread = Thread.new()
	var python_exe_path : String = _get_python_executable()
	var thread_func = func(path, arguments):
		return OS.execute(path, arguments)

	thread.start(thread_func.bind(python_exe_path, arguments))
	
	while thread.is_alive():
		await null # FIXME: ???????

	return thread.wait_to_finish()

func execute_python(
	args : PackedStringArray,
	output : Array = [], read_stderr : bool = false,
	open_terminal : bool = false):

	var python_exe_path : String = _get_python_executable()
	print("Python exe path: ", python_exe_path)
	return OS.execute(
		python_exe_path, args, output,
		read_stderr, open_terminal)

func start_process(open_terminal : bool = false):

	assert(_external_process_pid == -1)

	# FIXME: Make sure we don't have one running.

	var open_port = 9500
	
	var real_python_script_path = convert_cache_item_to_real_path(
		python_script_path)
	
	assert(not _server_packet_socket)
	_server_packet_socket = KiriPacketSocket.new()
	while true:
		_server_packet_socket.start_server(["127.0.0.1", open_port])
		
		# Wait for the server to start.
		while _server_packet_socket.get_state() == KiriPacketSocket.KiriSocketState.SERVER_STARTING:
			OS.delay_usec(1)
		
		# If we're successfully listening, then we found a port to use and we
		# don't need to loop anymore.
		if _server_packet_socket.get_state() == KiriPacketSocket.KiriSocketState.SERVER_LISTENING:
			break
		
		# This port is busy. Try the next one.
		_server_packet_socket.stop()
		open_port += 1

	var python_exe_path : String = _get_python_executable()
	var wrapper_script_path : String = \
		ProjectSettings.globalize_path(_get_wrapper_script_cache_path())

	var startup_command : Array = [
		python_exe_path,
		wrapper_script_path,
		"--script", real_python_script_path,
		"--port", open_port]

	# FIXME: Remove this?
	if open_terminal:
		if OS.get_name() == "Linux":
			startup_command = ["xterm", "-e"] + startup_command

	_external_process_pid = OS.create_process(
		startup_command[0], startup_command.slice(1),
		open_terminal)

func stop_process():

	if _external_process_pid != -1:
		OS.kill(_external_process_pid)
		_external_process_pid = -1

	# Clean up server and communication sockets.
	if _server_packet_socket:
		_server_packet_socket.stop()
		_server_packet_socket = null

	if communication_packet_socket:
		communication_packet_socket.stop()
		communication_packet_socket = null

func call_rpc_callback(method : String, args : Variant, callback = null) -> int:
	
	assert((args is Dictionary) or (args is Array))
	assert((callback == null) or (callback is Callable))
	
	var new_request = KiriPythonWrapperActiveRequest.new()
	new_request.id = _request_counter
	_request_counter += 1
	new_request.method_name = method
	new_request.arguments = args
	new_request.callback = callback

	assert(not _active_request_queue.has(new_request.id))
	_active_request_queue[new_request.id] = new_request

	return new_request.id

func call_rpc_async(method : String, args : Variant):

	var request_id = call_rpc_callback(method, args, func(request_ob):
		_rpc_async_response_received.emit(request_ob)
	)

	# Wait (block) until we get a response.
	while true:
		var rpc_response = await _rpc_async_response_received
		if not rpc_response:
			push_error("Error happened while waiting for RPC response in async call.")
			break
		
		if rpc_response.id == request_id:
			return rpc_response.response
	
	return null

func call_rpc_sync(method : String, args : Variant):

	# Kinda hacky. We're using arrays because we can change the contents.
	# Without the array or something else mutable we'd just end up with the
	# internal pointer pointing to different values without affecting these
	# ones.
	var done_array = [false]
	var response_list = []
	var request_id = call_rpc_callback(method, args, func(request_ob):
		done_array[0] = true
		response_list.append(request_ob.response)
	)

	# Wait (block) until we get a response.
	while not done_array[0]:
		
		# Bail out if something happened to our instance or connection to it.
		if communication_packet_socket:
			if communication_packet_socket.is_disconnected_or_error():
				push_error("Disconnected from RPC client while waiting for response.")
				break
		if (not communication_packet_socket) and (not _server_packet_socket):
			push_error("RPC socket evaporated into thin air.")
			break
		if _external_process_pid == -1:
			push_error("RPC client died.")
			break

		poll()
		OS.delay_usec(1)

	if len(response_list):
		return response_list[0]

	return null

func poll() -> Error:
	
	# Hand-off between listening socket and actual communications socket.
	if _server_packet_socket:
		communication_packet_socket = _server_packet_socket.get_next_server_connection()
		if communication_packet_socket:
			_server_packet_socket.stop()
			_server_packet_socket = null
	
	if communication_packet_socket:
		
		if communication_packet_socket.is_disconnected_or_error():
			# Tell any awaiting async calls that they're never getting an
			# answer. So sad.
			_rpc_async_response_received.emit(null)
			stop_process()
			push_error("poll(): Disconnected from RPC client.")
			return FAILED
		
		# Send all waiting requests
		for request_id in _active_request_queue:
			var request : KiriPythonWrapperActiveRequest = _active_request_queue[request_id]
			if request.state == request.KiriPythonWrapperActiveRequestState.STATE_WAITING_TO_SEND:
				
				var request_dict = {
					"jsonrpc": "2.0",
					"method": request.method_name,
					"params": request.arguments,
					"id": request.id
				}
				var request_dict_json = JSON.stringify(request_dict)
				communication_packet_socket.send_packet(request_dict_json.to_utf8_buffer())
				request.state = request.KiriPythonWrapperActiveRequestState.STATE_SENT

		# Check for responses.
		var packet = communication_packet_socket.get_next_packet()
		while packet != null:
			var packet_dict = JSON.parse_string(packet.get_string_from_utf8())
			if packet_dict:
				
				if packet_dict.has("kirijsonrpcerror"):
					push_error(packet_dict["kirijsonrpcerror"])

				elif packet_dict.has("id"):
					var request_id  = packet_dict["id"]

					# floats aren't even allowed in JSON RPC as an id. Probably
					# meant it to be an int.
					if request_id is float:
						request_id = int(request_id)

					if _active_request_queue.has(request_id):
						var request : KiriPythonWrapperActiveRequest = \
							_active_request_queue[request_id]
						if "result" in packet_dict:
							request.response = packet_dict["result"]
						elif "error" in packet_dict:
							if packet_dict["error"] is Dictionary and packet_dict["error"].has("message"):
								push_error(packet_dict["error"]["message"])
							else:
								push_error(packet_dict["error"])
						else:
							request.error_response = "Couldn't find result on packet."
						if request.callback:
							request.callback.call(request)

						# Clean up request.
						_active_request_queue.erase(request_id)

			packet = communication_packet_socket.get_next_packet()

	# Clean up if the process has died.
	if _external_process_pid != -1:
		if !OS.is_process_running(_external_process_pid):
			push_error("Process appears to have died. :(")
			stop_process()

	if _external_process_pid == -1:
		if _server_packet_socket:
			# Still waiting for a connection. Not an error.
			return OK
		else:
			# No process found.
			return FAILED

	return OK

func set_cache_path(new_path : String) -> void:
	_build_wrangler.set_cache_path(new_path)
