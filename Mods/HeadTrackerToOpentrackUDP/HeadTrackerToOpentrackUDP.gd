extends Mod_Base

var _udp_peer = null

var enable_yaw : bool = true
var offset_yaw : float = 0.0
var scale_yaw : float = 1.0
var enable_pitch : bool = true
var offset_pitch : float = 0.0
var scale_pitch : float = 1.0



func _ready() -> void:

	_udp_peer = PacketPeerUDP.new()
	_udp_peer.set_dest_address("127.0.0.1", 4242)

	add_tracked_setting("offset_yaw", "Yaw offset", { "min" : -180, "max" : 180 })
	add_tracked_setting("scale_yaw", "Yaw scale", { "min" : -10, "max" : 10 })
	add_tracked_setting("enable_yaw", "Yaw enabled")
	add_tracked_setting("offset_pitch", "Pitch offset", { "min" : -180, "max" : 180 })
	add_tracked_setting("scale_pitch", "Pitch scale", { "min" : -10, "max" : 10 })
	add_tracked_setting("enable_pitch", "Pitch enabled")
	
func _process(delta: float) -> void:
	var tracker_dict : Dictionary = get_global_mod_data("trackers")

	var encoded_data : PackedByteArray = PackedByteArray()
	# 6 doubles (XYZ, PYR?) at 8 bytes each.
	encoded_data.resize(8 * 6)

	var val : float = cos(Time.get_unix_time_from_system()) * 20.0

	if "head" in tracker_dict:
		var b : Basis = tracker_dict["head"]["transform"].basis
		var q = b.get_rotation_quaternion()
		q.x *= -1.0
		q.y *= -1.0
		q.z *=  1.0
		q.w *= -1.0
		b = Basis(q)
		var forward_transformed : Vector3 = Vector3(0.0, 0.0, 1.0) * b
		
		
		
		#tracker_dict["head"]["transform"]
		#print(forward_transformed)

		# XYZ
		encoded_data.encode_double(0, 0)
		encoded_data.encode_double(8, 0)
		encoded_data.encode_double(16, 0)

		# YPR
		var yaw : float = atan2(forward_transformed.x, forward_transformed.z)
		yaw *= scale_yaw
		yaw += offset_yaw
		yaw = clampf(yaw, -180.0, 180.0)
		
		if enable_yaw:
			encoded_data.encode_double(24, (yaw / PI) * 180.0)
		else:
			encoded_data.encode_double(24, 0)
		
		var pitch : float = -atan2(forward_transformed.y, forward_transformed.z)
		pitch *= scale_pitch
		pitch += offset_pitch
		pitch  = clampf(pitch, -180.0, 180.0)
		
		if enable_pitch:
			encoded_data.encode_double(32, (pitch / PI) * 180.0)
		else:
			encoded_data.encode_double(32, 0)

		#print("yaw: ", yaw, " pitch: ", pitch)

		
		# Not doing roll yet because we can't use it.
		encoded_data.encode_double(40, 0)

		_udp_peer.put_packet(encoded_data)
