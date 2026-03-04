extends Mod_Base

var target_ip : String = "127.0.0.1"
var target_port : int = 39539
var vmc_sender_enabled : bool = false

# PoseIK applies an offset to the entire model.
# This sends it as the hips offset.
var send_hips_offset_from_model : bool = false

# List from the VRM spec:
# https://github.com/vrm-c/vrm-specification/blob/master/specification/0.0/schema/vrm.humanoid.bone.schema.json
const _humanoid_bone_list : PackedStringArray = [
	"Hips",
	"LeftUpperLeg", "RightUpperLeg",
	"LeftLowerLeg", "RightLowerLeg",
	"LeftFoot", "RightFoot",
	"Spine", "Chest", "Neck", "Head",
	"LeftShoulder", "RightShoulder",
	"LeftUpperArm", "RightUpperArm",
	"LeftLowerArm", "RightLowerArm",
	"LeftHand", "RightHand",
	"LeftToes", "RightToes",
	"LeftEye", "RightEye",
	"Jaw",
	"LeftThumbProximal", "LeftThumbIntermediate", "LeftThumbDistal",
	"LeftIndexProximal", "LeftIndexIntermediate", "LeftIndexDistal",
	"LeftMiddleProximal", "LeftMiddleIntermediate", "LeftMiddleDistal",
	"LeftRingProximal", "LeftRingIntermediate", "LeftRingDistal",
	"LeftLittleProximal", "LeftLittleIntermediate", "LeftLittleDistal",
	"RightThumbProximal", "RightThumbIntermediate", "RightThumbDistal",
	"RightIndexProximal", "RightIndexIntermediate", "RightIndexDistal",
	"RightMiddleProximal", "RightMiddleIntermediate","RightMiddleDistal",
	"RightRingProximal", "RightRingIntermediate", "RightRingDistal",
	"RightLittleProximal", "RightLittleIntermediate", "RightLittleDistal",
	"UpperChest"]

const _vrm_1_to_0_blend_shape_map : Dictionary[String, String] = {
	"neutral" : "Neutral",
	"aa" : "A",
	"ih" : "I",
	"ou" : "U",
	"ee" : "E",
	"oh" : "O",
	"blink" : "Blink",
	"happy" : "Joy",
	"angry" : "Angry",
	"sad" : "Sorrow",
	"relaxed" : "Fun",
	"lookUp" : "LookUp",
	"lookDown" : "LookDown",
	"lookLeft" : "LookLeft",
	"lookRight" : "LookRight",
	"blinkLeft" : "Blink_L",
	"blinkRight" : "Blink_R" }

func _ready() -> void:
	add_tracked_setting("target_ip", "Reciever IP address")
	add_tracked_setting("target_port", "Reciever port")
	add_tracked_setting("vmc_sender_enabled", "Sender enabled")

	add_tracked_setting("send_hips_offset_from_model", "Send hip offset from model")
	
	update_settings_ui()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary) -> void:
	$KiriOSClient.change_port_and_ip(target_port, target_ip)
	if _settings_old["vmc_sender_enabled"] != _settings_new["vmc_sender_enabled"]:
		if vmc_sender_enabled:
			$KiriOSClient.start_client()
		else:
			$KiriOSClient.stop_client()

func _physics_process(_delta: float) -> void:
	var skel : Skeleton3D = get_skeleton()

	for vmc_bone_name in _humanoid_bone_list:
		var model_bone_name : String = vmc_bone_name

		# VRM 1.0 has different thumb bone names.
		if model_bone_name.contains("Thumb"):
			model_bone_name = model_bone_name \
				.replace("Proximal", "Metacarpal") \
				.replace("Intermediate", "Proximal")

		var bone_index : int = skel.find_bone(model_bone_name)
		if bone_index == -1:
			continue

		var global_rest : Transform3D = skel.get_bone_global_rest(bone_index)
		var rest : Transform3D = skel.get_bone_rest(bone_index)
		var pose : Transform3D = skel.get_bone_pose(bone_index)

		var transformed_pose : Transform3D = global_rest * rest.inverse() * pose * global_rest.inverse()
		var rotation_quat : Quaternion = transformed_pose.basis.get_rotation_quaternion()
		var origin : Vector3 = pose.origin

		if model_bone_name == "Hips" and send_hips_offset_from_model:
			origin += get_model().transform.origin

		# Shuffle stuff around into the coordinate space that VMC expects.
		rotation_quat.y *= -1
		rotation_quat.z *= -1
		origin.x *= -1

		$KiriOSClient.send_osc_message("/VMC/Ext/Bone/Pos", "sfffffff", [
			vmc_bone_name,
			origin.x, origin.y, origin.z,
			rotation_quat.x, rotation_quat.y, rotation_quat.z, rotation_quat.w])

	var blend_shapes_to_apply : Dictionary = get_global_mod_data("BlendShapes")
	for model_shape_name in blend_shapes_to_apply:
		var vmc_shape_name : String = model_shape_name
		if model_shape_name in _vrm_1_to_0_blend_shape_map:
			vmc_shape_name = _vrm_1_to_0_blend_shape_map[model_shape_name]

		$KiriOSClient.send_osc_message("/VMC/Ext/Blend/Val", "sf", [
			vmc_shape_name,
			blend_shapes_to_apply[model_shape_name]])

	$KiriOSClient.send_osc_message("/VMC/Ext/Blend/Apply", "", [])
