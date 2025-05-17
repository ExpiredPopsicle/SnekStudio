extends Mod_Base
class_name VRChatOSC

@export var dns_service : MulticastDNS
@export var update_vrc_param_values : bool = false
@export var osc_client : KiriOSClient

var vrchat_osc_query_endpoint : String = ""
## The current value of the avatar ID.
var current_avatar_id : String
## The previous value of the avatar ID.
var previous_avatar_id : String
## Dictionary of avatar parameters and their current values.
var raw_avatar_params : Dictionary
## Parsed VRChat parameters.
var vrc_params : VRCParams = VRCParams.new()
## Keys for quick lookup and verification.
var vrc_param_keys : Array[String] = []
var avatar_req : HTTPRequest
var client_send_rate_limit_ms : int = 500
var curr_client_send_time : float
# Can we not JUST USE THE SAME MAPPING
# WHY DOES EVERY APP NEED THEIR OWN WAY
var unified_to_arkit_mapping : Dictionary = {
	"EyeLookUpRight": "eyeLookUpRight",
	"EyeLookDownRight": "eyeLookDownRight",
	"EyeLookInRight": "eyeLookInRight",
	"EyeLookOutRight": "eyeLookOutRight",
	"EyeLookUpLeft": "eyeLookUpLeft",
	"EyeLookDownLeft": "eyeLookDownLeft",
	"EyeLookInLeft": "eyeLookInLeft",
	"EyeLookOutLeft": "eyeLookOutLeft",
	"EyeClosedRight": "eyeBlinkRight",
	"EyeClosedLeft": "eyeBlinkLeft",
	"EyeSquintRight": "eyeSquintRight",
	"EyeSquintLeft": "eyeSquintLeft",
	"EyeWideRight": "eyeWideRight",
	"EyeWideLeft": "eyeWideLeft",
	"BrowDownRight": "browDownRight",
	"BrowDownLeft": "browDownLeft",
	"BrowInnerUp": "browInnerUp",
	"BrowOuterUpRight": "browOuterUpRight",
	"BrowOuterUpLeft": "browOuterUpLeft",
	"NoseSneerRight": "noseSneerRight",
	"NoseSneerLeft": "noseSneerLeft",
	"CheekSquintRight": "cheekSquintRight",
	"CheekSquintLeft": "cheekSquintLeft",
	"CheekPuff": "cheekPuff",
	"JawOpen": "jawOpen",
	"MouthClosed": "mouthClose",
	"JawRight": "jawRight",
	"JawLeft": "jawLeft",
	"JawForward": "jawForward",
	"LipSuckUpper": "mouthRollUpper",
	"LipSuckLower": "mouthRollLower",
	"LipFunnel": "mouthFunnel",
	"LipPucker": "mouthPucker",
	"MouthUpperUpRight": "mouthUpperUpRight",
	"MouthUpperUpLeft": "mouthUpperUpLeft",
	"MouthLowerDownRight": "mouthLowerUpRight",
	"MouthLowerDownLeft": "mouthLowerUpLeft",
	"MouthSmileRight": "mouthSmileRight",
	"MouthSmileLeft": "mouthSmileLeft",
	"MouthFrownRight": "mouthFrownRight",
	"MouthFrownLeft": "mouthFrownLeft",
	"MouthStretchRight": "mouthStretchRight",
	"MouthStretchLeft": "mouthStretchLeft",
	"MouthDimplerRight": "mouthDimpleRight",
	"MouthDimplerLeft": "mouthDimpleLeft",
	"MouthRaiserUpper": "mouthShrugUpper",
	"MouthRaiserLower": "mouthShrugLower",
	"MouthPressRight": "mouthPressRight",
	"MouthPressLeft": "mouthPressLeft",
	"TongueOut": "tongueOut"
}
var arkit_to_unified_mapping : Dictionary = {}

func _ready() -> void:
	avatar_req = HTTPRequest.new()
	add_child(avatar_req)
	avatar_req.request_completed.connect(_avatar_params_request_complete)
	dns_service.on_receive.connect(_dns_packet)
	for key in unified_to_arkit_mapping:
		var new_key = unified_to_arkit_mapping[key]
		var new_value = key
		arkit_to_unified_mapping[new_key] = new_value

var get_a = true

func _process(delta : float) -> void:
	
	if vrchat_osc_query_endpoint == "":
		return
		
	curr_client_send_time += delta
	if curr_client_send_time > client_send_rate_limit_ms / 1000:
		curr_client_send_time = 0
		var blendshapes : Dictionary = get_global_mod_data("BlendShapes")
		
		var unified_blendshapes : Dictionary = {}
		for blendshape in blendshapes:
			if not arkit_to_unified_mapping.has(blendshape):
				continue
			var unified_blendshape = arkit_to_unified_mapping[blendshape]
			unified_blendshapes[unified_blendshape] = blendshapes[blendshape]
		
		for shape in unified_blendshapes:
			vrc_params.update_value(shape, unified_blendshapes[shape])

		var to_send_osc : Array[VRCParam] = vrc_params.get_dirty()
		#print(len(to_send_osc))

		for param in to_send_osc:
			param.reset_dirty()
			# We send the message with the full path for the avatar parameter, and type.
			var type = param.type
			if param.type == "T":
				if param.value == true:
					type = "T"
				else:
					type = "F"
			osc_client.send_osc_message(param.full_path, type, [param.value])

		await get_tree().create_timer(10).timeout
		if not get_a:
			return
		get_a = false
		_get_avatar_params()

func _dns_packet(packet : DNSPacket, raw_packet : StreamPeerBuffer) -> void:
	if not packet.query_response:
		return
	if len(packet.dns_answers) == 0 or len(packet.dns_additional) == 0:
		return

	var ptr_record : DNSRecord = packet.dns_answers[0]
	if ptr_record.dns_type != DNSRecord.RECORD_TYPE.PTR:
		return

	if ptr_record.full_label != "_oscjson._tcp.local":
		return

	var domain_label : String = ptr_record.data["full_label"]
	if not domain_label.begins_with("VRChat-Client"):
		return

	var a_records : Array[DNSRecord] = packet.dns_additional.filter(
		func (x : DNSRecord) -> bool: return x.dns_type == DNSRecord.RECORD_TYPE.A
	)
	if len(a_records) == 0:
		return
	var srv_records : Array[DNSRecord] = packet.dns_additional.filter(
		func (x : DNSRecord) -> bool: return x.dns_type == DNSRecord.RECORD_TYPE.SRV
	)
	if len(srv_records) == 0:
		return
	var ip_address : String = a_records[0].data["address"]
	var port : int = srv_records[0].data["port"]
	vrchat_osc_query_endpoint = "http://%s:%s" % \
	[
		ip_address,
		port
	]
	
	if not osc_client.is_client_active():
		# Init osc sender. Default to 9000 (default OSC port).
		osc_client.change_port_and_ip(9000, ip_address)
		osc_client.start_client()

	print("[VRChat OSC] Found VRChat OSC Query Endpoint: %s" % vrchat_osc_query_endpoint)

func _get_avatar_params():
	if vrchat_osc_query_endpoint == "":
		return null
	var err = avatar_req.request(vrchat_osc_query_endpoint + "/avatar")
	if err != OK:
		printerr("[VRChat OSC] Failed to request VRC avatar parameters with error code: %d" % err)

func _avatar_params_request_complete(result : int, response_code : int, 
									headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("Request for VRC avatar params failed.")
		return
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	# Uh oh... that's a lot of hardcoded values.
	# FIXME: Check that all these keys exist.
	current_avatar_id = json["CONTENTS"]["change"]["VALUE"][0]
	var has_changed_avi : bool = current_avatar_id != previous_avatar_id
	if has_changed_avi:
		# Update only if changed avi.
		print("[VRChat OSC] Avatar has changed. Updating parameter keys, values and types.")
		vrc_param_keys = []
		vrc_params.reset()

	# We always pull raw avatar params to update the current value.
	raw_avatar_params = json["CONTENTS"]["parameters"]["CONTENTS"]

	if not update_vrc_param_values and not has_changed_avi:
		previous_avatar_id = current_avatar_id
		return

	vrc_params.initialize(raw_avatar_params, current_avatar_id, has_changed_avi)

	previous_avatar_id = current_avatar_id
