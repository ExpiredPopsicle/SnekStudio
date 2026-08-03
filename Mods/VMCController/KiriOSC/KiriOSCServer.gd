extends Node
class_name KiriOSCServer

var udp_peer : PacketPeerUDP = null

@export var host_ip : String = "127.0.0.1"
@export var host_port : int = 39567
@export var auto_start : bool = true

var host_ip_resolved : String = IP.resolve_hostname(host_ip)

signal message_received(address, arguments)

var _errors_since_last_check = []
func get_new_errors():
	var new_errors = _errors_since_last_check
	_errors_since_last_check = []
	return new_errors

func _add_error(new_error):
	_errors_since_last_check.append(new_error)

func change_port_and_ip(port, ip):
	if host_ip != ip or host_port != port:
		host_ip = ip
		host_ip_resolved = IP.resolve_hostname(ip)
		host_port = port
		if is_server_active():
			stop_server()
			start_server()

func start_server():
	udp_peer = PacketPeerUDP.new()
	var err = udp_peer.bind(host_port, host_ip_resolved)
	if err != OK:
		_add_error("Failed to bind port!")
		udp_peer.close()
		udp_peer = null

func stop_server():
	if udp_peer:
		udp_peer.close()
		udp_peer = null

func is_server_active():
	if udp_peer:
		return true
	return false

func _ready():
	if auto_start:
		start_server()

func _parse_osc_string(packet, byte_index):
	
	assert(byte_index == byte_index & ~3)
	
	var return_string = ""
	while byte_index < packet.size() and packet[byte_index] != 0:
		var c = packet[byte_index]
		return_string += char(c)
		byte_index += 1
		
	# Skip final null terminator.
	byte_index += 1

	# Handle padding at the end of the address string. Bring us up to a
	# multiple of 4 bytes.
	byte_index = (byte_index + 3) & ~3
	
	return [byte_index, return_string]

func _parse_osc_int(packet, byte_index):
	return [
		byte_index + 4,
		(packet[byte_index]   << 24) + \
		(packet[byte_index+1] << 16) + \
		(packet[byte_index+2] << 8 ) + \
		(packet[byte_index+3] << 0 )]

func _parse_osc_timetag(packet, byte_index):
	# FIXME: Half of this should be fractional.
	return [
		byte_index + 8,
		(packet[byte_index]   << 56) + \
		(packet[byte_index+1] << 48) + \
		(packet[byte_index+2] << 40) + \
		(packet[byte_index+3] << 32) + \
		(packet[byte_index+4] << 24) + \
		(packet[byte_index+5] << 16) + \
		(packet[byte_index+6] << 8 ) + \
		(packet[byte_index+7] << 0 )]

func _parse_osc_float(packet, byte_index):
	var buf = StreamPeerBuffer.new()

	var swapped_array = PackedByteArray()
	swapped_array.resize(4)
	swapped_array[0] = packet[byte_index+3]
	swapped_array[1] = packet[byte_index+2]
	swapped_array[2] = packet[byte_index+1]
	swapped_array[3] = packet[byte_index+0]

	buf.data_array = swapped_array

	return [byte_index + 4, buf.get_float()]

func _parse_osc_blob(packet, byte_index):

	var original_byte_index = byte_index
	var parse_result = _parse_osc_int(packet, byte_index)
	byte_index = parse_result[0]

	# Handle padding at the end of the address string. Bring us up to a
	# multiple of 4 bytes.
	byte_index = (byte_index + 3) & ~3

	return [
		byte_index,
		packet.slice(
			original_byte_index + 4,
			original_byte_index + 4 + parse_result[1] - 1)]

func _handle_message_part(packet : PackedByteArray):

	var byte_index = 0
	
	var parse_result # Temp value used in a bunch of places.

	var address_string = ""
	var type_string = ""
	var arguments = []
	
	# Parse address string.
	parse_result = _parse_osc_string(packet, byte_index)
	byte_index = parse_result[0]
	address_string = parse_result[1]

	if parse_result[1] == "#bundle":

		# Handle OSC bundles. We're going to split this packet up and
		# recurse into this function.

		parse_result = _parse_osc_timetag(packet, byte_index)
		byte_index = parse_result[0]
		var _timetag = parse_result[1]

		while byte_index < packet.size():
			
			parse_result = _parse_osc_int(packet, byte_index)
			var bundle_element_size = parse_result[1]
			byte_index = parse_result[0]
			
			_handle_message_part(packet.slice(byte_index, byte_index + bundle_element_size))
			
			byte_index += bundle_element_size

	else:
	
		# Attempt to parse type string.
		if byte_index < packet.size():
			parse_result = _parse_osc_string(packet, byte_index)
			if parse_result[1].length() > 0:
				if parse_result[1][0] == ',':
					type_string = parse_result[1]
					byte_index = parse_result[0]
		
		# Discard any packets with unknown type data.
		if type_string.length() > 0:
			
			var bad_packet = false
			for c in type_string:

				if c != "f" && c != "i" && c != "s" && c != "b" && c != ",":
					# FIXME: Do bad packet reporting here.
					bad_packet = true
					break
			
			if bad_packet:
				return

		# Parse data.
		if type_string.length() > 1:

			for c in type_string.substr(1):
				if c == "i":
					parse_result = _parse_osc_int(packet, byte_index)
				if c == "f":
					parse_result = _parse_osc_float(packet, byte_index)
				if c == "s":
					parse_result = _parse_osc_string(packet, byte_index)
				if c == "b":
					parse_result = _parse_osc_blob(packet, byte_index)

				byte_index = parse_result[0]
				arguments.append(parse_result[1])

		emit_signal(
			"message_received", address_string,
			arguments)

func _physics_process(_delta):

	if not udp_peer:
		return
	
	while(udp_peer.get_available_packet_count()):
		var packet = udp_peer.get_packet()
		_handle_message_part(packet)
