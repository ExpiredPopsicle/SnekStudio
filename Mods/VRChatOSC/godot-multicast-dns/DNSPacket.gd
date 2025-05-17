extends Node
class_name DNSPacket

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

static func from_packet(packet : StreamPeerBuffer) -> DNSPacket:
	var dns_packet : DNSPacket = DNSPacket.new()

	dns_packet.id = packet.get_u16()
	var flags = packet.get_u16()
	dns_packet.response_code = (flags & 0x000F);
	dns_packet.tentative = (flags & 0x0100) == 0x0100;
	dns_packet.truncation = (flags & 0x0200) == 0x0200;
	dns_packet.conflict = (flags & 0x0400) == 0x0400;
	dns_packet.opcode = (flags & 0x7800) >> 11;
	dns_packet.query_response = (flags & 0x8000) == 0x8000

	var cache : Dictionary = {}

	# Fill in the extra properties based on lengths read from packet.
	var question_length = packet.get_u16()
	var answer_length = packet.get_u16()
	var auth_length = packet.get_u16()
	var add_length = packet.get_u16()
	for i in range(question_length):
		dns_packet.dns_questions.append(DNSQuestion.from_packet(packet, cache))
	for i in range(answer_length):
		dns_packet.dns_answers.append(DNSRecord.from_packet(packet, cache))
	for i in range(auth_length):
		dns_packet.dns_authoritories.append(DNSRecord.from_packet(packet, cache))
	for i in range(add_length):
		dns_packet.dns_additional.append(DNSRecord.from_packet(packet, cache))

	return dns_packet

# TODO: Add send support.
# static func to_packet() ....
