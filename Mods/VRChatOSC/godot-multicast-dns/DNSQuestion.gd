extends Node
class_name DNSQuestion
## Unsigned Short - Type of question/record.
var dns_type : int
## Unsigned Short - The question/record class.
var dns_class : int
## Labels for the question
var labels : Array[String] = []
## The full label is just the labels joined.
var full_label : String
## The cache MUST be the same across the entire packet deserialization.
var _cache : Dictionary

## Extract a DNS Question from the provided packet with the label cache.
static func from_packet(packet : StreamPeerBuffer, cache: Dictionary) -> DNSQuestion:
	var dns_question : DNSQuestion = DNSQuestion.new()

	dns_question._cache = cache
	dns_question.labels = dns_question._read_labels(packet)
	dns_question.full_label = ".".join(dns_question.labels)
	dns_question.dns_type = packet.get_u16()
	dns_question.dns_class = packet.get_u16()

	return dns_question

## Extract a DNS Question from the provided packet with the label cache, applying to the record.
static func from_packet_for_record(packet : StreamPeerBuffer, cache: Dictionary, record : DNSRecord):
	record._cache = cache
	record.labels = record._read_labels(packet)
	record.full_label = ".".join(record.labels)
	record.dns_type = packet.get_u16()
	record.dns_class = packet.get_u16()

## Writes the current DNS Question to the packet.
func to_packet(packet: StreamPeerBuffer, cache: Dictionary):
	_write_labels(packet, labels, cache)
	packet.put_u16(dns_type)
	packet.put_u16(dns_class)
	
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
	
func _write_labels(packet: StreamPeerBuffer, cur_labels: Array[String], cache: Dictionary) -> void:
	var i = 0
	while i < cur_labels.size():
		var suffix = ".".join(cur_labels.slice(i))
		if cache.has(suffix):
			var ptr = cache[suffix]
			packet.put_u8(0xC0 | (ptr >> 8))
			packet.put_u8(ptr & 0xFF)
			return
		else:
			cache[suffix] = packet.get_position()
			var label = cur_labels[i]
			var raw = label.to_utf8_buffer()
			packet.put_u8(raw.size())
			packet.put_data(raw)
			i += 1
	packet.put_u8(0)
