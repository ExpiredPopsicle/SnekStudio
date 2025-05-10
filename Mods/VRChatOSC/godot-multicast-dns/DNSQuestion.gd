extends Node
class_name DNSQuestion
## Unsigned Short - Type of question/record.
var dns_type : int
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
