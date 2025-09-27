extends Node
class_name MulticastDNS

var server : UDPServer
var clients : Array[PacketPeerUDP] = []
var multicast_address : String = "224.0.0.251"
var local_addresses : Array[String] = []

signal on_receive(packet : DNSPacket, raw_packet : StreamPeerBuffer)

func _ready() -> void:
	server = UDPServer.new()
	# We only listen on ipv4, we're not using mDNS for IPv6.
	var err = server.listen(5353, "0.0.0.0")
	if err != OK:
		printerr("[Multicast DNS] Failed to start listening on port 5353 with error code %d" % err)

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

		var dns_packet : DNSPacket = DNSPacket.from_packet(packet)

		on_receive.emit(dns_packet, packet)

## Sends DNS Packet to all connected client peers (UDP).
func send_packet(packet : DNSPacket):
	var raw_packet : StreamPeerBuffer = packet.to_packet()
	var byte_array : PackedByteArray = raw_packet.data_array
	for client : PacketPeerUDP in clients:
		client.put_packet(byte_array)
