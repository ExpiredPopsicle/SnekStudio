extends Mod_Base
class_name VRChatOSC

@export var dns_service : MulticastDNS

func _ready() -> void:
	dns_service.on_receive.connect(_dns_packet)

func _process(_delta : float) -> void:
	pass

func _dns_packet(packet : DNSPacket, raw_packet : StreamPeerBuffer) -> void:
	pass
	
