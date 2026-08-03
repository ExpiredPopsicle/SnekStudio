extends Node
class_name KiriOSClient

var udp_peer : PacketPeerUDP = null
var ntp_start_date : Dictionary
var ntp_start_unix : int

@export var target_ip : String = "127.0.0.1"
@export var target_port : int = 39539
@export var auto_start : bool = false

var target_ip_resolved : String = IP.resolve_hostname(target_ip)

func _ready():
	ntp_start_date = Time.get_datetime_dict_from_datetime_string("1900-01-01T00:00:00Z", false)
	ntp_start_unix = Time.get_unix_time_from_datetime_dict(ntp_start_date)
	if auto_start:
		start_client()

## Change the target port and IP address and restart the underlying connection.
func change_port_and_ip(port : int, ip : String) -> void:
	if target_ip != ip or target_port != port:
		target_ip = ip
		target_ip_resolved = IP.resolve_hostname(ip)
		target_port = port
		if is_client_active():
			stop_client()
			start_client()

## Connect to host.
func start_client() -> void:
	udp_peer = PacketPeerUDP.new()
	udp_peer.connect_to_host(target_ip_resolved, target_port)

## Disconnect from host.
func stop_client() -> void:
	if udp_peer:
		udp_peer.close()
		udp_peer = null

func is_client_active() -> bool:
	return udp_peer != null

## Attempts to automatically map the type to the supplied argument and passes through to the prepare_osc_message function.
## Types supported: nil, bool, int, float, string, color, packedbytearray (blob).
## If it cannot map a type of argument it will push an error.
## This does not send the OSC message.
func prepare_osc_message_auto_type_tag(address : String, arguments : Array) -> PackedByteArray:
	var types = ""
	
	for arg in arguments:
		match typeof(arg):
			TYPE_NIL:
				types += "N"
			TYPE_BOOL:
				types += arg if "T" else "F"
			TYPE_INT:
				types += "i"
			TYPE_FLOAT:
				types += "f"
			TYPE_STRING:
				types += "s"
			TYPE_COLOR:
				types += "r"
			TYPE_PACKED_BYTE_ARRAY:
				types += "b"
			_:
				push_error("Unsupported type from automatic type tagging: %s" % type_string(typeof(arg)))
	return prepare_osc_message(address, types, arguments)

## Prepares but does not send an OSC message given the supplied address, types and arguments for those types.
## The number of types and arguments must match.
func prepare_osc_message(address : String, types : String, arguments : Array) -> PackedByteArray:
	assert(len(types) == len(arguments))
	
	var packet = PackedByteArray()
	packet.append_array(_osc_string(address))
	packet.append_array(_osc_string("," + types))

	for i in range(types.length()):
		var type = types[i]
		var arg = arguments[i]
		match type:
			"i":
				packet.append_array(_osc_int(arg))
			"f":
				packet.append_array(_osc_float(arg))
			"s", "S": 
				# Technically both can be OSC-string, although 'S' is normally application defined.
				packet.append_array(_osc_string(arg))
			"c":
				packet.append_array(_osc_char(arg))
			"b":
				packet.append_array(_osc_blob(arg))
			"r":
				# Arg is treated as a Color.
				packet.append_array(_osc_rgba(arg))
			"h":
				packet.append_array(_osc_int64(arg))
			"m":
				# Arg is treated as an array of bytes, or ints.
				packet.append_array(_osc_midi(arg[0], arg[1], arg[2], arg[3]))
			"t":
				# Zero precision.
				packet.append_array(_osc_timetag(arg, 0))
			"d":
				packet.append_array(_osc_double(arg))
			"T", "F", "N", "I":
				# Do nothing with these, they are simply no-argument types.
				pass
			_:
				# We do not continue execution. An unsupported type is fatal.
				assert(false, "Unsupported type: %s" % type)
	return packet

## Prepares and sends an OSC message given the address, types and arguments.
func send_osc_message(address : String, types : String, arguments : Array) -> void:
	var packet = prepare_osc_message(address, types, arguments)
	send_osc_message_raw(packet)

## Sends an OSC message that has already been prepared.
func send_osc_message_raw(packet : PackedByteArray) -> void:
	# FIXME: Assert? Perhaps better in the send_osc_message function.
	if not is_client_active():
		return
		
	udp_peer.put_packet(packet)

## Creates a bundle using the array of provided OSC messages.
## Creation of these message packets can occur through the use of the prepare_osc_message 
## or equivalent function.
func create_osc_bundle(timetag : int, osc_element_packets : Array) -> PackedByteArray:
	var packet = PackedByteArray()

	packet.append_array(_osc_string("#bundle"))

	# Add the timetag (64-bit)
	# FIXME: Add support for precision beyond 0.
	packet.append_array(_osc_timetag(timetag, 0))

	# Add each element
	for element in osc_element_packets:
		var element_size = element.size()
		packet.append_array(_osc_int(element_size))
		packet.append_array(element)

	return packet

## Retrieve a timetag for the current time to help with sending.
## Will return an int representing the time since 1900.
func get_timetag_for_current_time() -> int:
	return Time.get_unix_time_from_system() - ntp_start_unix
	
func _osc_string(s : String) -> PackedByteArray:
	var packet = PackedByteArray()

	# Technically the OSC specs state "non-null ASCII characters followed by null", but we use utf8.
	# This is due to the comm format in VMC: "Use UTF-8. (Data includes non ascii type)"
	packet.append_array(s.to_utf8_buffer())
	packet.append(0)

	# Pad to a multiple of 4 bytes
	while packet.size() % 4 != 0:
		packet.append(0)

	return packet

func _osc_midi(port_id : int, status : int, data1 : int, data2 : int) -> PackedByteArray:
	_assert_is_byte(port_id)
	_assert_is_byte(status)
	_assert_is_byte(data1)
	_assert_is_byte(data2)

	var packet = PackedByteArray()
	packet.resize(4)
	packet[0] = port_id >> 0 & 0xFF
	packet[1] = status >> 0 & 0xFF
	packet[2] = data1 >> 0 & 0xFF
	packet[3] = data2 >> 0 & 0xFF
	return packet

func _osc_int(value : int) -> PackedByteArray:
	var packet = PackedByteArray()
	packet.resize(4)
	packet[0] = (value >> 24) & 0xFF
	packet[1] = (value >> 16) & 0xFF
	packet[2] = (value >> 8) & 0xFF
	packet[3] = (value >> 0) & 0xFF
	return packet

func _osc_int64(value : int) -> PackedByteArray:
	var packet = PackedByteArray()
	packet.resize(8)
	packet[0] = (value >> 56) & 0xFF
	packet[1] = (value >> 48) & 0xFF
	packet[2] = (value >> 40) & 0xFF
	packet[3] = (value >> 32) & 0xFF
	packet[4] = (value >> 24) & 0xFF
	packet[5] = (value >> 16) & 0xFF
	packet[6] = (value >> 8) & 0xFF
	packet[7] = (value >> 0) & 0xFF
	return packet

func _osc_double(value : float) -> PackedByteArray:
	var buf = StreamPeerBuffer.new()
	buf.put_double(value)

	var swapped_array = PackedByteArray()
	swapped_array.resize(8)
	swapped_array[0] = buf.data_array[7]
	swapped_array[1] = buf.data_array[6]
	swapped_array[2] = buf.data_array[5]
	swapped_array[3] = buf.data_array[4]
	swapped_array[4] = buf.data_array[3]
	swapped_array[5] = buf.data_array[2]
	swapped_array[6] = buf.data_array[1]
	swapped_array[7] = buf.data_array[0]

	return swapped_array

func _osc_float(value : float) -> PackedByteArray:
	var buf = StreamPeerBuffer.new()
	buf.put_float(value)

	var swapped_array = PackedByteArray()
	swapped_array.resize(4)
	swapped_array[0] = buf.data_array[3]
	swapped_array[1] = buf.data_array[2]
	swapped_array[2] = buf.data_array[1]
	swapped_array[3] = buf.data_array[0]

	return swapped_array

func _osc_char(value : String) -> PackedByteArray:
	assert(len(value) == 1)

	var packet = PackedByteArray()
	packet.resize(4)
	packet[0] = value.to_ascii_buffer()[0] & 0xFF
	return packet

func _osc_blob(data : PackedByteArray) -> PackedByteArray:
	var packet = PackedByteArray()
	packet.append_array(_osc_int(data.size()))
	packet.append_array(data)

	# Pad to a multiple of 4 bytes
	while packet.size() % 4 != 0:
		packet.append(0)

	return packet

func _osc_timetag(timestamp : int, precision : int) -> PackedByteArray:
	var packet = PackedByteArray()
	packet.resize(8)

	# First 32 bits: seconds since Jan 1 1900
	packet[0] = (timestamp >> 24) & 0xFF
	packet[1] = (timestamp >> 16) & 0xFF
	packet[2] = (timestamp >> 8) & 0xFF
	packet[3] = (timestamp >> 0) & 0xFF

	# Last 32 bits: fractional part of a second
	packet[4] = (precision >> 24) & 0xFF
	packet[5] = (precision >> 16) & 0xFF
	packet[6] = (precision >> 8) & 0xFF
	packet[7] = (precision >> 0) & 0xFF

	return packet

func _osc_rgba(rgba : Color) -> PackedByteArray:
	# Pack it into an int and return value.
	return _osc_int(rgba.r8 << 24 | rgba.g8 << 16 | rgba.b8 << 8 | rgba.a8)

func _assert_is_byte(value : int) -> void:
	assert(value >= 0 and value < 256)
