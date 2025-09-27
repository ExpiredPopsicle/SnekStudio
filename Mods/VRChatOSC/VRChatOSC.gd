extends Mod_Base
class_name VRChatOSC

@export var dns_service : MulticastDNS
@export var update_vrc_param_values : bool = false
@export var osc_client : KiriOSClient
@export var osc_query_server : OSCQueryServer
var osc_query_name : String = str(randi_range(500000, 5000000))
var osc_server_name : String = str(randi_range(500000, 5000000))
var vrchat_osc_query_endpoint : String = ""
## Cached processed keys that exist on the current avatar.
var cached_valid_keys : Array[String] = []
## The current value of the avatar ID.
var current_avatar_id : String
## The previous value of the avatar ID.
var previous_avatar_id : String
## Parsed VRChat parameters.
var vrc_params : VRCParams = VRCParams.new()
## Keys for quick lookup and verification.
var vrc_param_keys : Array[String] = []
var avatar_req : HTTPRequest
var client_send_rate_limit_ms : int = 50
var curr_client_send_time : float
var processing_request : bool = false
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

func _get_unified_value(shape : String, shape_type : ParameterMappings.SHAPE_KEY_TYPE, unified_blendshapes : Dictionary) -> float:
	if shape_type == ParameterMappings.SHAPE_KEY_TYPE.UNIFIED:
		return unified_blendshapes.get(shape, 0.0)
	elif shape_type == ParameterMappings.SHAPE_KEY_TYPE.MEDIAPIPE:
		var unified_shape: String = arkit_to_unified_mapping.get(shape, shape)
		return unified_blendshapes.get(unified_shape, 0.0)
	return 0.0
	
func _get_unified_shape(shape: String, shape_type: ParameterMappings.SHAPE_KEY_TYPE) -> String:
	if shape_type == ParameterMappings.SHAPE_KEY_TYPE.UNIFIED:
		
		return shape
	elif shape_type == ParameterMappings.SHAPE_KEY_TYPE.MEDIAPIPE:
		return arkit_to_unified_mapping.get(shape, shape)
	return shape

func _apply_transform_rules(unified_blendshapes : Dictionary, base_dict : Dictionary) -> void:
	for param_name : String in base_dict.keys():
		var rule : Dictionary = base_dict[param_name]
		var comb_type : int = rule["combination_type"]
		var shapes : Array = rule["combination_shapes"]

		match comb_type:
			ParameterMappings.COMBINATION_TYPE.COPY:
				var src_shape_info : Dictionary = shapes[0]
				var src_shape : String = src_shape_info["shape"]
				var src_type : ParameterMappings.SHAPE_KEY_TYPE = src_shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
				var src_value : float = _get_unified_value(src_shape, src_type, unified_blendshapes)
				var src_inverse : bool = src_shape_info.get("inverse", false)
				if src_inverse:
					if src_value < 0:
						src_value = abs(src_value)
					else:
						src_value *= -1

				for i in range(1, shapes.size()):
					var dst_shape_info : Dictionary = shapes[i]
					var dst_shape : String = dst_shape_info["shape"]
					var dst_type : ParameterMappings.SHAPE_KEY_TYPE = dst_shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
					var unified_shape : String = _get_unified_shape(dst_shape, dst_type)
					unified_blendshapes[unified_shape] = src_value

			ParameterMappings.COMBINATION_TYPE.AVERAGE:
				var sum : float = 0.0
				var count : int = 0
				for shape_info : Dictionary in shapes:
					var shape : String = shape_info["shape"]
					var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
					var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
					sum += value
					count += 1
				unified_blendshapes[param_name] = sum / max(count, 1)
			
			ParameterMappings.COMBINATION_TYPE.RANGE_AVERAGE:
				var positive_shapes : Array = shapes[0]["positive"]
				var negative_shapes : Array = shapes[0]["negative"]
				var use_max_value : bool = shapes[0].get("use_max_value", false)
				if use_max_value:
					var max_pos : float = 0.0
					var max_neg : float = 0.0
					for shape_info : Dictionary in positive_shapes:
						var shape : String = shape_info["shape"]
						var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
						var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
						if value > max_pos:
							max_pos = value
					for shape_info : Dictionary in negative_shapes:
						var shape : String = shape_info["shape"]
						var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
						var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
						if value > max_neg:
							max_neg = value
					unified_blendshapes[param_name] = max_pos + (max_neg * -1.0)
				else:
					var sum_pos : float = 0.0
					var sum_neg : float = 0.0
					for shape_info : Dictionary in positive_shapes:
						var shape : String = shape_info["shape"]
						var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
						var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
						sum_pos += value
					for shape_info : Dictionary in negative_shapes:
						var shape : String = shape_info["shape"]
						var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
						var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
						sum_neg += value
					unified_blendshapes[param_name] = (sum_pos / max(len(positive_shapes), 1)) + ((sum_neg * -1.0) / max(len(negative_shapes), 1))

			ParameterMappings.COMBINATION_TYPE.RANGE:
				var total : float = 0.0
				for shape_info : Dictionary in shapes:
					var shape : String = shape_info["shape"]
					var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
					var direction : ParameterMappings.DIRECTION = shape_info.get("direction", ParameterMappings.DIRECTION.POSITIVE)
					var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
					if direction == ParameterMappings.DIRECTION.POSITIVE:
						total += value
					else:
						total -= value
				unified_blendshapes[param_name] = total
				
			ParameterMappings.COMBINATION_TYPE.WEIGHTED_ADD:
				var total : float = 0.0
				for shape_info : Dictionary in shapes:
					var shape : String = shape_info["shape"]
					var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
					var weight : float = shape_info.get("weight", 1.0)
					var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
					total += value * weight
				unified_blendshapes[param_name] = total
				
			ParameterMappings.COMBINATION_TYPE.WEIGHTED:
				var src_shape_info : Dictionary = shapes[0]
				var src_shape : String = src_shape_info["shape"]
				var src_type : ParameterMappings.SHAPE_KEY_TYPE = src_shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
				var src_value : float = _get_unified_value(src_shape, src_type, unified_blendshapes)
				var src_weight : float = src_shape_info["weight"]

				var dst_shape_info : Dictionary = shapes[1]
				var dst_shape : String = dst_shape_info["shape"]
				var dst_type : ParameterMappings.SHAPE_KEY_TYPE = dst_shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
				var dst_value : float = _get_unified_value(dst_shape, dst_type, unified_blendshapes)
				var dst_weight : float = dst_shape_info["weight"]

				unified_blendshapes[param_name] = src_value * src_weight + dst_value * dst_weight
			
			ParameterMappings.COMBINATION_TYPE.SUBTRACT:
				var src_shape_info : Dictionary = shapes[0]
				var src_shape : String = src_shape_info["shape"]
				var src_type : ParameterMappings.SHAPE_KEY_TYPE = src_shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
				var src_value : float = _get_unified_value(src_shape, src_type, unified_blendshapes)

				var dst_shape_info : Dictionary = shapes[1]
				var dst_shape : String = dst_shape_info["shape"]
				var dst_type : ParameterMappings.SHAPE_KEY_TYPE = dst_shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
				var dst_value : float = _get_unified_value(dst_shape, dst_type, unified_blendshapes)

				unified_blendshapes[param_name] = src_value - dst_value

			ParameterMappings.COMBINATION_TYPE.MAX:
				var max_pos : float = 0.0
				for shape_info : Dictionary in shapes:
					var shape : String = shape_info["shape"]
					var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
					var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
					if value > max_pos:
						max_pos = value
				unified_blendshapes[param_name] = max_pos

			ParameterMappings.COMBINATION_TYPE.MIN:
				var min : float = 1.1 # Very unlikely > 1.0 exists given they're constrainted to 1.0
				for shape_info : Dictionary in shapes:
					var shape : String = shape_info["shape"]
					var shape_type : ParameterMappings.SHAPE_KEY_TYPE = shape_info.get("shape_type", ParameterMappings.SHAPE_KEY_TYPE.UNIFIED)
					var value : float = _get_unified_value(shape, shape_type, unified_blendshapes)
					if value < min:
						min = value
				unified_blendshapes[param_name] = min

func _ready() -> void:
	avatar_req = HTTPRequest.new()
	add_child(avatar_req)
	avatar_req.request_completed.connect(_avatar_params_request_complete)
	# We need to know the vrc endpoint to get data from.
	dns_service.on_receive.connect(_vrc_dns_packet)
	# We need to have another connection to resolve OTHER DNS queries (OSCQuery).
	dns_service.on_receive.connect(_resolve_dns_packet)
	osc_query_server.osc_paths = {
		"/avatar/change": {
			"DESCRIPTION": "Avatar Change",
			"FULL_PATH": "/avatar/change",
			"ACCESS": 2, # WRITE_ONLY
			"TYPE": "s",
		}
	}
	osc_query_server.on_osc_server_message_received.connect(_osc_query_received)
	
	for key in unified_to_arkit_mapping:
		var new_key = unified_to_arkit_mapping[key]
		var new_value = key
		arkit_to_unified_mapping[new_key] = new_value

func _process(delta : float) -> void:
	
	if vrchat_osc_query_endpoint == "":
		return
		
	#curr_client_send_time += delta
	#if curr_client_send_time > client_send_rate_limit_ms / 1000:
	#	curr_client_send_time = 0

	# Map the blendshapes we have from mediapipe to the unified versions.
	var unified_blendshapes : Dictionary = _map_blendshapes_to_unified()
	
	# Apply unified blendshape simplification mapping
	_apply_transform_rules(unified_blendshapes, ParameterMappings.simplified_parameter_mapping)
	# Apply legacy parameter mapping (this makes me sad)
	_apply_transform_rules(unified_blendshapes, ParameterMappings.legacy_parameter_mapping)

	if len(cached_valid_keys) == 0:
		cached_valid_keys = vrc_params.valid_params_from_dict(unified_blendshapes)

	# Set params to values
	for shape in unified_blendshapes:
		if not shape in cached_valid_keys:
			continue
		vrc_params.update_value(shape, unified_blendshapes[shape])

	# Finally, send all dirty params off to VRC
	_send_dirty_params()


func _map_blendshapes_to_unified() -> Dictionary:
	var blendshapes : Dictionary = get_global_mod_data("BlendShapes")
	var unified_blendshapes : Dictionary = {}
	for blendshape in blendshapes:
		if not arkit_to_unified_mapping.has(blendshape):
			continue
		var unified_blendshape = arkit_to_unified_mapping[blendshape]
		#if len(cached_valid_keys) > 0 and not cached_valid_keys.has(unified_blendshape):
		#	continue
		unified_blendshapes[unified_blendshape] = blendshapes[blendshape]

	return unified_blendshapes

func _send_dirty_params():
	var to_send_osc : Array[VRCParam] = vrc_params.get_dirty()

	for param in to_send_osc:
		param.reset_dirty()
		# We send the message with the full path for the avatar parameter, and type.
		var type = param.type
		if param.type == "T":
			# Param value is true? Send as type "T" representing "True" in OSC.
			if param.value:
				type = "T"
			else:
				type = "F"
		osc_client.send_osc_message(param.full_path, type, [param.value])

func _osc_query_received(address : String, args) -> void:
	if address == "/avatar/change":
		print("WAOH")
		_get_avatar_params()

func _resolve_dns_packet(packet : DNSPacket, raw_packet : StreamPeerBuffer) -> void:
	if vrchat_osc_query_endpoint == "" or packet.opcode != 0:
		return
	
	for question : DNSQuestion in packet.dns_questions:
		# We have two services to respond to: 
		# 1. The OSC Query Server (http) (_oscjson._tcp.local)
		# 2. The OSC Server (udp) (_osc._udp.local)
		var service_name : String = ""
		var is_osc_query : bool = false
		if question.full_label.begins_with("_osc._udp.local"):
			service_name = "SNEKS-" + osc_server_name
		elif question.full_label.begins_with("_oscjson._tcp.local"):
			service_name = "SNEKS-" + osc_query_name
			is_osc_query = true
			
		if service_name == "":
			continue
		
		var full_name : Array[String] = [service_name, question.labels[0], question.labels[1], question.labels[2]]
		var full_service_name : Array[String] = [service_name, question.labels[0].replace("_", ""), question.labels[1].replace("_", "")]
		
		var txt_record = DNSRecord.new()

		txt_record.labels = full_name
		txt_record.dns_type = DNSRecord.RECORD_TYPE.TXT
		txt_record.data = { "text": "txtvers=1" }
		
		var srv_record = DNSRecord.new()
		srv_record.labels = full_name
		srv_record.dns_type = DNSRecord.RECORD_TYPE.SRV
		if is_osc_query:
			srv_record.data = { "port": osc_query_server.http_server.port }
		else:
			srv_record.data = { "port": osc_query_server.osc_server_port }
		srv_record.data.set("target", full_service_name)
		
		var a_record = DNSRecord.new()
		a_record.dns_type = DNSRecord.RECORD_TYPE.A
		a_record.labels = full_service_name
		# We know this will always be 127.0.0.1 buuuuuuuuut
		if is_osc_query:
			a_record.data = { "address": osc_query_server.http_server.bind_address }
		else:
			a_record.data = { "address": osc_query_server.osc_server_ip }
			
		var ptr_record = DNSRecord.new()
		ptr_record.dns_type = DNSRecord.RECORD_TYPE.PTR
		ptr_record.data = { "domain_labels": full_name }
		ptr_record.labels = question.labels
		
		var answers : Array[DNSRecord] = [ptr_record]
		var additional : Array[DNSRecord] = [txt_record, srv_record, a_record]
		
		var new_packet = DNSPacket.new()
		new_packet.dns_answers = answers
		new_packet.dns_additional = additional
		new_packet.query_response = true
		new_packet.conflict = true
		new_packet.tentative = false
		new_packet.truncation = false
		new_packet.opcode = 0
		new_packet.response_code = 0
		new_packet.id = 0
		
		# Send it off to our peers to alert them to the answer.
		dns_service.send_packet(new_packet)
		
func _vrc_dns_packet(packet : DNSPacket, raw_packet : StreamPeerBuffer) -> void:
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
		# If it is the first time going through, we get the current avi params.
		_get_avatar_params()
		
	print("[VRChat OSC] Found VRChat OSC Query Endpoint: %s" % vrchat_osc_query_endpoint)

func _get_avatar_params():
	if vrchat_osc_query_endpoint == "":
		return
	if processing_request:
		return
	var err = avatar_req.request(vrchat_osc_query_endpoint + "/avatar")
	processing_request = true
	if err != OK:
		printerr("[VRChat OSC] Failed to request VRC avatar parameters with error code: %d" % err)

func _avatar_params_request_complete(result : int, response_code : int, 
									headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		printerr("Request for VRC avatar params failed.")
		return
	print("[VRChat OSC] Avatar param request complete.")
	
	var json = JSON.parse_string(body.get_string_from_utf8())
	var root_contents : Dictionary = json["CONTENTS"]
	if not root_contents.has("parameters") or not root_contents.has("change"):
		# Could be booting game/loading/logging in/not in game.
		printerr("[VRChat OSC] No parameters, or avatar information exists.")
		return

	# Uh oh... that's a lot of hardcoded values.
	# FIXME: Check that all these keys exist.
	current_avatar_id = json["CONTENTS"]["change"]["VALUE"][0]
	var has_changed_avi : bool = current_avatar_id != previous_avatar_id
	if has_changed_avi:
		# Update only if changed avi.
		print("[VRChat OSC] Avatar has changed. Updating parameter keys, values and types.")
		vrc_param_keys = []
		cached_valid_keys = []
		vrc_params.reset()

	# We always pull raw avatar params to update the current value.
	var raw_avatar_params = json["CONTENTS"]["parameters"]["CONTENTS"]

	processing_request = false

	if not update_vrc_param_values and not has_changed_avi:
		previous_avatar_id = current_avatar_id
		return

	vrc_params.initialize(raw_avatar_params, current_avatar_id, has_changed_avi)

	previous_avatar_id = current_avatar_id
