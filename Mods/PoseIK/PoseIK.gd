extends Mod_Base

var lean_scale : float = 1.0


func _ready() -> void:

	add_setting_group("advanced", "Advanced")

	add_tracked_setting(
		"lean_scale", "Lean Scale",
		{ "min" : -6.0, "max" : 6.0 },
		"advanced")


func _process(_delta : float) -> void:

	var tracker_dict : Dictionary = get_global_mod_data("trackers")
	var skel : Skeleton3D = get_skeleton()
	var model_root : Node3D = get_model()

	#print(tracker_dict.keys())
#
	##print(tracker_dict["finger_positions"].keys())
	#for k in tracker_dict["finger_positions"].keys():
		#print(k, ": ", tracker_dict["finger_positions"][k])


	# Lean!
	var lean_check_axis : Vector3 = (skel.transform * skel.get_bone_global_pose(skel.find_bone("Hips"))).basis * Vector3(1.0, 0.0, 0.0)
	#print(lean_check_axis)
	lean_check_axis = lean_check_axis.normalized()
	#var head_offset : Vector3 = $Head.transform.origin - (skel.transform * skel.get_bone_global_pose(skel.find_bone("Head"))).origin
	var head_offset : Vector3 = tracker_dict["head"]["transform"].origin - model_root.transform.origin
	var lean_amount : float = sin(lean_check_axis.dot(head_offset))
	handle_lean(skel, lean_amount * lean_scale)


func rotate_bone_in_global_space(
	skel : Skeleton3D,
	bone_index : int,
	axis : Vector3,
	angle : float,
	relative : bool = false):

	if axis.length() <= 0.0001:
		return

	var parent_bone_index = skel.get_bone_parent(bone_index)	
	var gs_rotation = Basis(axis.normalized(),  angle).get_rotation_quaternion()
	var gs_rotation_parent = skel.get_bone_global_rest(parent_bone_index).basis.get_rotation_quaternion()
	var gs_rotation_rest = skel.get_bone_global_rest(bone_index).basis.get_rotation_quaternion()
	var bs_rotation = gs_rotation_parent.inverse() * gs_rotation * gs_rotation_rest
	
	if relative:
		skel.set_bone_pose_rotation(
			bone_index,
			skel.get_bone_pose_rotation(bone_index) * bs_rotation)
	else:
		skel.set_bone_pose_rotation(
			bone_index,
			bs_rotation)


func handle_lean(skel : Skeleton3D, angle : float):

	var current_bone : int = skel.find_bone("Head")
	var hips_bone : int = skel.find_bone("Hips")
	var bone_count : int = 0
	
	while current_bone != hips_bone and current_bone != -1:
		bone_count += 1
		current_bone = skel.get_bone_parent(current_bone)
	
	angle /= float(bone_count)
	
	current_bone = skel.find_bone("Head")
	while current_bone != hips_bone and current_bone != -1:
		rotate_bone_in_global_space(skel, current_bone, Vector3(0.0, 0.0, 1.0), angle, true)
		current_bone = skel.get_bone_parent(current_bone)
