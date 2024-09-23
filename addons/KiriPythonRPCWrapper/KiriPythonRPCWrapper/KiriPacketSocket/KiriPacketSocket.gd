# KiriPacketSocket
#
# GDScript version of the KiriPacketSocket Python module. Basically just copied
# the code over and reformatted it. Error handling and some other behaviors are
# different due to differences in how Python and GDScript handle exceptions and
# others.

extends RefCounted
class_name KiriPacketSocket

var _should_quit : bool = false
var _packet_buffer : KiriPacketBuffer = KiriPacketBuffer.new()
var _state : KiriSocketState = KiriSocketState.DISCONNECTED
var _outgoing_packet_queue : Array = []

var _worker_thread : bool = false
signal _worker_thread_should_continue

var _new_connections_to_server : Array = []
var _error_string : String = ""

# This class exists in __init__.py, ported as the original Python. Any
# functional changes to this should be reflected in that implementation as well.
class KiriPacketBuffer:
	var _receive_buffer : PackedByteArray = []
	var _packet_buffer : Array = []

	func _grab_complete_packets():
		while len(_receive_buffer) >= 4:
			
			var next_packet_size : int = \
				_receive_buffer[0] | \
				(_receive_buffer[1] << 8) | \
				(_receive_buffer[2] << 16) | \
				(_receive_buffer[3] << 24)

			if len(_receive_buffer) >= 4 + next_packet_size:
				var next_packet = _receive_buffer.slice(4, 4 + next_packet_size)
				assert(len(next_packet) == next_packet_size)
				_receive_buffer = _receive_buffer.slice(4 + len(next_packet))
				_packet_buffer.append(next_packet)
			
			else:
			
				break
	
	func _have_complete_packet():
		_grab_complete_packets()
		return len(_packet_buffer) > 0

	func get_next_packet():
		if not _have_complete_packet():
			return null
		return _packet_buffer.pop_front()

	func add_bytes(incoming_bytes : PackedByteArray):
		_receive_buffer.append_array(incoming_bytes)

enum KiriSocketState {
	DISCONNECTED     = 0,
	CONNECTING       = 1,
	CONNECTED        = 2,
	SERVER_STARTING  = 3,
	SERVER_LISTENING = 4,
	ERROR            = 5
}

func send_packet(packet_bytes : PackedByteArray):
	assert(packet_bytes)
	_outgoing_packet_queue.append(packet_bytes)

func poll():
	_worker_thread_should_continue.emit()

func get_next_packet():
	poll()
	var ret = _packet_buffer.get_next_packet()
	return ret

func get_next_server_connection():
	poll()
	var ret = null
	if len(_new_connections_to_server) > 0:
		ret = _new_connections_to_server.pop_front()
	return ret

func get_last_error():
	var ret = _error_string
	return ret

func is_disconnected_or_error():
	var bad_states = [
		KiriSocketState.DISCONNECTED,
		KiriSocketState.ERROR
	]

	var ret : bool = false
	if _state in bad_states:
		ret = true

	return ret

func get_state():
	var ret = _state
	return ret

func start_server(address):

	_set_state(KiriSocketState.SERVER_STARTING)

	assert(not _worker_thread)
	_worker_thread = true
	
	# Starts coroutine.
	_server_thread_func(address)

func start_client(address):

	_set_state(KiriSocketState.CONNECTING)

	assert(not _worker_thread)

	_worker_thread = true

	# Starts coroutine.
	_client_thread_func(address)

func stop():

	if not _worker_thread:
		return

	_should_quit = true
	while _worker_thread:
		_worker_thread_should_continue.emit()
	_should_quit = false

func is_running():
	return not (_worker_thread == null)

func _normal_communication_loop_iteration(sock : StreamPeer, address):

	if sock.poll() != OK:
		return FAILED

	if sock.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return FAILED

	# Get new data.
	var available_bytes = sock.get_available_bytes()
	if available_bytes > 0:
		var incoming_bytes = sock.get_data(available_bytes)
		_packet_buffer.add_bytes(PackedByteArray(incoming_bytes[1]))
		if incoming_bytes[0] != OK:
			return FAILED

	# Send all packets from queue.
	while len(self._outgoing_packet_queue):
		var next_outgoing_packet = _outgoing_packet_queue.pop_front()
		var len_to_send = len(next_outgoing_packet)
		sock.put_u8((len_to_send & 0x000000ff) >> 0)
		sock.put_u8((len_to_send & 0x0000ff00) >> 8)
		sock.put_u8((len_to_send & 0x00ff0000) >> 16)
		sock.put_u8((len_to_send & 0xff000000) >> 24)
		sock.put_data(next_outgoing_packet)

	return OK

func _client_thread_func(address):

	var sock : StreamPeerTCP = StreamPeerTCP.new()

	# Connect to the server.
	_set_state(KiriSocketState.CONNECTING)
	var connect_err = sock.connect_to_host(address[0], address[1])

	if connect_err == OK:
		_set_state(KiriSocketState.CONNECTED)

		while not _should_quit:
			
			await _worker_thread_should_continue
			
			var err = _normal_communication_loop_iteration(sock, address)
			if err != OK:
				break

		# We are now disconnected.
		_set_state(KiriSocketState.DISCONNECTED)
		sock.disconnect_from_host()

	else:
		_set_state(KiriSocketState.ERROR, "Connection failed")

	sock.close()
	_worker_thread = false

func _set_state(state : KiriSocketState, error_string=null):
	_state = state
	if _state == KiriSocketState.ERROR:
		assert(error_string)
		_error_string = error_string
	else:
		assert(not error_string)
		_error_string = ""

func _server_to_client_thread_func(connection : StreamPeerTCP, address):

	print("_server_to_client_thread_func start")

	_set_state(KiriSocketState.CONNECTED)

	while not _should_quit:

		await _worker_thread_should_continue

		var err = _normal_communication_loop_iteration(connection, address)
		if err != OK:
			break

	# FIXME: Missing some error handling here due to exception differences
	# between Python and GDScript.

	# Only switch to "disconnected" if we were most recently
	# connected, otherwise we could mask an error.
	if get_state() == KiriSocketState.CONNECTED:
		_set_state(KiriSocketState.DISCONNECTED)

	connection.disconnect_from_host()
	_worker_thread = false
	
	print("_server_to_client_thread_func stop")

func _server_thread_func(address):

	while not _should_quit:

		var sock : TCPServer = TCPServer.new()

		var listen_err = sock.listen(address[1], address[0])

		if listen_err != OK:

			# FIXME: I wonder if we should do this in the main
			# thread so we can get the exceptions back up to
			# the start_server function and up from there.
			_set_state(KiriSocketState.ERROR, "Could not listen on port.")
			break

		_set_state(KiriSocketState.SERVER_LISTENING)

		while not _should_quit:
			
			await _worker_thread_should_continue
			
			if sock.is_connection_available():
				var connection : StreamPeerTCP = sock.take_connection()
				var new_client : KiriPacketSocket = KiriPacketSocket.new()
				new_client._start_client_connection_from_server(connection, address)
				_new_connections_to_server.append(new_client)

		sock.stop()
		sock = null

	# Close all connections that were waiting to be accepted.
	for c in _new_connections_to_server:
		c.stop()
	_new_connections_to_server = []

	_worker_thread = false

func _start_client_connection_from_server(connection : StreamPeerTCP, address):

	assert(not _worker_thread)
	_worker_thread = true

	# Coroutine call.
	_server_to_client_thread_func(connection, address)

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# Well, this is horrible.
		if self:
			if is_running():
				stop()
