extends Node
class_name MulticastDNS

class DNSPacket:
	## Unsigned Short - ID
	var id : int
	## QUERYRESPONSE
	var query_response : bool
	## Integer - OPCODE
	var opcode : int
	## CONFLICT
	var conflict : bool
	## TRUNCATION
	var truncation : bool
	## TENTATIVE
	var tentative : bool
	## Integer - RESPONSECODE
	var response_code : int
	
	## DNS Questions
	var dns_questions : Array[DNSQuestion] = []
	## DNS Answers (if any)
	var dns_answers : Array[DNSRecord] = []
	## DNS Authoritories
	var dns_authoritories : Array[DNSRecord] = []
	## DNS Additional
	var dns_additional : Array[DNSRecord] = []
		
	func _init(packet : StreamPeerBuffer) -> void:
		id = packet.get_u16()
		var flags = packet.get_u16()
		response_code = (flags & 0x000F);
		tentative = (flags & 0x0100) == 0x0100;
		truncation = (flags & 0x0200) == 0x0200;
		conflict = (flags & 0x0400) == 0x0400;
		opcode = (flags & 0x7800) >> 11;
		query_response = (flags & 0x8000) == 0x8000
		
		var cache : Dictionary = {}
		
		# Fill in the extra properties based on lengths read from packet.
		var question_length = packet.get_u16()
		var answer_length = packet.get_u16()
		var auth_length = packet.get_u16()
		var add_length = packet.get_u16()
		for i in range(question_length):
			dns_questions.append(DNSQuestion.new(packet, cache))
		for i in range(answer_length):
			dns_answers.append(DNSRecord.new(packet, cache))
		for i in range(auth_length):
			dns_authoritories.append(DNSRecord.new(packet, cache))
		for i in range(add_length):
			dns_additional.append(DNSRecord.new(packet, cache))

class DNSQuestion:
	## Unsigned Short - Type of question/record.
	var dns_type : RECORD_TYPE
	## Unsigned Short - The question/record class.
	var dns_class : int
	## Labels for the question
	var labels : Array[String] = []
	## The cache MUST be the same across the entire packet deserialization.
	var _cache : Dictionary
	## Initialize the properties.
	func _init(packet : StreamPeerBuffer, cache: Dictionary) -> void:
		_cache = cache
		labels = _read_labels(packet)
		dns_type = packet.get_u16()
		dns_class = packet.get_u16()

	## Recursively read all labels
	func _read_labels(packet : StreamPeerBuffer) -> Array[String]:
		var pos = packet.get_position()
		var length = packet.get_u8()
		# Check if compressed.
		if length & 0xC0 == 0xC0:
			var pointer = (length ^ 0xC0) << 8 | packet.get_u8()
			var cname = _cache[pointer]
			_cache[pos] = cname
			return cname
		var inner_labels : Array[String] = []
		if length == 0:
			return inner_labels
			
		# Get data returns a record of the attempt, and the results from the attempt.
		var raw_data = packet.get_data(length)[1]
		var packed_data = PackedByteArray(raw_data)

		inner_labels.append(packed_data.get_string_from_utf8())
		inner_labels.append_array(_read_labels(packet))
		_cache[pos] = inner_labels

		return inner_labels

enum RECORD_TYPE {
	A = 1,
	NS = 2,
	PTR = 12,
	TXT = 16,
	SRV = 33
}

class DNSRecord:
	extends DNSQuestion
	
	## Time-to-live in seconds
	var ttl_seconds : int
	## Length of data
	var length : int
	## Structured data (changes depending on record_type)
	var data : Dictionary

	## Read from the packet to initialize the DNS Record
	func _init(packet : StreamPeerBuffer, cache: Dictionary) -> void:
		# Make sure we init the details of the packet.
		super(packet, cache)

		ttl_seconds = packet.get_u32()
		length = packet.get_u16()

		if dns_type == RECORD_TYPE.A:
			_a_record(packet)
		elif dns_type == RECORD_TYPE.PTR:
			_ptr_record(packet)
		elif dns_type == RECORD_TYPE.SRV:
			_srv_record(packet)
		elif dns_type == RECORD_TYPE.NS:
			_ns_record(packet)
		elif dns_type == RECORD_TYPE.TXT:
			_txt_record(packet)
		else:
			print("Unsupported DNS record type found: %s", dns_type)

	func _a_record(packet : StreamPeerBuffer) -> void:
		data["address"] = _get_ipv4_address(packet)
	func _ptr_record(packet : StreamPeerBuffer) -> void:
		data["domain_labels"] = _read_labels(packet)
	func _srv_record(packet : StreamPeerBuffer) -> void:
		data["priority"] = packet.get_u16()
		data["weight"] = packet.get_u16()
		data["port"] = packet.get_u16()
		data["target"] = _read_labels(packet)
	func _ns_record(packet : StreamPeerBuffer) -> void:
		data["authority"] = _read_labels(packet)
	func _txt_record(packet : StreamPeerBuffer) -> void:
		data["text"] = ""
		var l = length
		while l > 0:
			var part_length : int = packet.get_u8()
			var part : PackedByteArray = PackedByteArray(packet.get_data(part_length)[1])
			var str_part : String = part.get_string_from_ascii()
			data["text"] += str_part
			l -= part_length + 1 # We +1 here for the part length byte we read.
	func _get_ipv4_address(packet : StreamPeerBuffer) -> String:
		# WHY
		var ip = packet.get_u32()
		var ip_bytes : Array[int] = [0, 0, 0, 0]
		ip_bytes[0] = int((ip >> 24) & 0xFF)
		ip_bytes[1] = int((ip >> 16) & 0xFF)
		ip_bytes[2] = int((ip >> 8) & 0XFF)
		ip_bytes[3] = int(ip & 0xFF)
		
		return "%d.%d.%d.%d" % [ip_bytes[0], ip_bytes[1], ip_bytes[2], ip_bytes[3]]

var server : UDPServer
var clients : Array[PacketPeerUDP] = []
var multicast_address : String = "224.0.0.251"
var local_addresses : Array[String] = []

signal on_receive(packet : DNSPacket, raw_packet : StreamPeerBuffer)

func _ready() -> void:
	server = UDPServer.new()
	# We only listen on ipv4, we're not using mDNS for IPv6.
	var err = server.listen(5353, "0.0.0.0")
	
	if err > 0:
		pass
func _process(delta : float) -> void:
	server.poll() # Important!
	if server.is_connection_available():
		var receiver = server.take_connection()
		for interface_details : Dictionary in IP.get_local_interfaces():
			receiver.join_multicast_group(multicast_address, interface_details["name"])
			# TODO: Make sender sockets for each local interface to support sending.
			for ip_addr in interface_details["addresses"]:
				if local_addresses.has(ip_addr):
					continue
				local_addresses.append(ip_addr)
		clients.append(receiver)

	for receiver in clients:
		if receiver.get_available_packet_count() <= 0:
			continue
			
		var packet_bytes : PackedByteArray = receiver.get_packet()
		
		# Make sure it is local, this may be disregarded in some situations in the future?
		# FIXME: If issues happen, remove this check.
		var packet_ip = receiver.get_packet_ip()
		if not local_addresses.has(receiver.get_packet_ip()):
			continue
		
		# Packet is big endian. Little endian is all that the extension methods of PackedByteArray support.
		# We must use a StreamPeerBuffer.
		# Source: https://github.com/godotengine/godot-proposals/issues/9586#issuecomment-2074227585
		var packet : StreamPeerBuffer = StreamPeerBuffer.new()
		packet.data_array = packet_bytes
		packet.big_endian = true
		
		var dns_packet : DNSPacket = DNSPacket.new(packet)
		
		on_receive.emit(dns_packet, packet)
