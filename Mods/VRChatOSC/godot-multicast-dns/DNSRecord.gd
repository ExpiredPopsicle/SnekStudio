class_name DNSRecord
extends DNSQuestion

enum RECORD_TYPE {
	A = 1,
	NS = 2,
	PTR = 12,
	TXT = 16,
	SRV = 33
}

## Time-to-live in seconds
var ttl_seconds : int
## Length of data
var length : int
## Structured data (changes depending on record_type)
var data : Dictionary

## Extract a DNS Record from the provided packet with the label cache.
static func from_packet(packet : StreamPeerBuffer, cache: Dictionary) -> DNSRecord:
	# Make sure we init the details of the packet.
	var dns_record : DNSRecord = DNSRecord.new()
	DNSQuestion.from_packet_for_record(packet, cache, dns_record)

	dns_record.ttl_seconds = packet.get_u32()
	dns_record.length = packet.get_u16()

	if dns_record.dns_type == RECORD_TYPE.A:
		dns_record._a_record(packet)
	elif dns_record.dns_type == RECORD_TYPE.PTR:
		dns_record._ptr_record(packet)
	elif dns_record.dns_type == RECORD_TYPE.SRV:
		dns_record._srv_record(packet)
	elif dns_record.dns_type == RECORD_TYPE.NS:
		dns_record._ns_record(packet)
	elif dns_record.dns_type == RECORD_TYPE.TXT:
		dns_record._txt_record(packet)
	else:
		print("Unsupported DNS record type found: %s", dns_record.dns_type)

	return dns_record

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
