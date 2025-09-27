extends Mod_Base

# List from the VRM spec:
# https://github.com/vrm-c/vrm-specification/blob/master/specification/0.0/schema/vrm.humanoid.bone.schema.json
var _humanoid_bone_list : PackedStringArray = [
	"hips",
	"leftUpperLeg", "rightUpperLeg",
	"leftLowerLeg", "rightLowerLeg",
	"leftFoot", "rightFoot",
	"spine", "chest", "neck", "head",
	"leftShoulder", "rightShoulder",
	"leftUpperArm", "rightUpperArm",
	"leftLowerArm", "rightLowerArm",
	"leftHand", "rightHand",
	"leftToes", "rightToes",
	"leftEye", "rightEye",
	"jaw",
	"leftThumbProximal", "leftThumbIntermediate", "leftThumbDistal",
	"leftIndexProximal", "leftIndexIntermediate", "leftIndexDistal",
	"leftMiddleProximal", "leftMiddleIntermediate", "leftMiddleDistal",
	"leftRingProximal", "leftRingIntermediate", "leftRingDistal",
	"leftLittleProximal", "leftLittleIntermediate", "leftLittleDistal",
	"rightThumbProximal", "rightThumbIntermediate", "rightThumbDistal",
	"rightIndexProximal", "rightIndexIntermediate", "rightIndexDistal",
	"rightMiddleProximal", "rightMiddleIntermediate","rightMiddleDistal",
	"rightRingProximal", "rightRingIntermediate", "rightRingDistal",
	"rightLittleProximal", "rightLittleIntermediate", "rightLittleDistal",
	"upperChest"]

# These are the names to match, along with their first-letter-uppercased
# versions.
var _humanoid_bone_dict_lowercase_to_upper_first_letter : Dictionary = {}

func _ready() -> void:
	for bone_name in _humanoid_bone_list:
		var bone_name_upper_first_letter : String = bone_name[0].to_upper() + bone_name.substr(1)
		_humanoid_bone_dict_lowercase_to_upper_first_letter[bone_name.to_lower()] = \
			bone_name_upper_first_letter

func _physics_process(delta: float) -> void:
	var skel : Skeleton3D = get_skeleton()

	#for bone_index in range(0, skel.get_bone_count()):
	for bone_name in _humanoid_bone_list:
		var bone_name_lower : String = bone_name.to_lower()
		var bone_name_upper_first_letter : String = _humanoid_bone_dict_lowercase_to_upper_first_letter[bone_name_lower]
		var bone_index : int = skel.find_bone(bone_name_upper_first_letter)
		if bone_index != -1:

			var global_pose : Transform3D = skel.get_bone_global_pose(bone_index)

			var rotation_quat : Quaternion = global_pose.basis.get_rotation_quaternion()
			var origin : Vector3 = global_pose.origin

			# Shuffle stuff around into the coordinate space that VMC expects.
			rotation_quat.y *= -1
			rotation_quat.z *= -1
			origin.x *= -1

			$KiriOSClient.send_osc_message("/VMC/Ext/Bone/Pos", "sfffffff", [
				bone_name_upper_first_letter,
				origin.x, origin.y, origin.z,
				rotation_quat.x, rotation_quat.y, rotation_quat.z, rotation_quat.w])

func needs_3D_transform() -> bool:
	return false
