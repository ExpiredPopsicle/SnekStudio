extends Mod_Base

class BonePair:
	var top_index: int
	var bottom_index: int

	func _init() -> void:
		top_index = -1;
		bottom_index = -1;


func _process(delta: float) -> void:
	var skel: Skeleton3D = get_skeleton()

	var bone_pairs: Dictionary

	for bone_index: int in range(0, skel.get_bone_count()):
		#print("bone: ", bone_index, ": ", skel.get_bone_name(bone_index));

		var bone_name_parts: PackedStringArray = \
			skel.get_bone_name(bone_index).split(".");

		# Format for these bones is:
		# "Snudio.LookAt.<bone pair name>.Top" and 
		# "Snudio.LookAt.<bone pair name>.Bottom".
		# With <bone pair name> being whatever you set in Blender.
		# FIXME: Warn if the array isn't the right length so we catch when we do
		#   .R/.L instead of _R/_L
		if bone_name_parts.size() == 4:
			if bone_name_parts[0] == "Snudio" \
				and bone_name_parts[1] == "LookAt":

				# Create or find this bone pair.
				var bone_pair_name: String = bone_name_parts[3]
				if not bone_pairs.has(bone_pair_name):
					bone_pairs[bone_pair_name] = BonePair.new()
				var bone_pair: BonePair = bone_pairs[bone_pair_name]

				if bone_name_parts[2] == "Top":
					bone_pair.top_index = bone_index
				if bone_name_parts[2] == "Bottom":
					bone_pair.bottom_index = bone_index

	for pair_name: String in bone_pairs.keys():
		#print("------------")
		var pair: BonePair = bone_pairs[pair_name]

		# FIXME: Account for missing bones.

		skel.reset_bone_pose(pair.top_index)
		skel.reset_bone_pose(pair.bottom_index)

		_point_bone_to_other_bone(skel, pair.top_index, pair.bottom_index)
		_point_bone_to_other_bone(skel, pair.bottom_index, pair.top_index)

		#var top_rest_tx: Transform3D = skel.get_bone_global_rest(pair.top_index)
		#var bottom_rest_tx: Transform3D = skel.get_bone_global_rest(pair.bottom_index)
		#var top_current_tx: Transform3D = skel.get_bone_global_pose(pair.top_index)
		#var bottom_current_tx: Transform3D = skel.get_bone_global_pose(pair.bottom_index)
#
		#var bottom_rest_in_top_space: Vector3 = top_rest_tx.inverse() * bottom_rest_tx.origin
		#var bottom_current_in_top_space: Vector3 = top_current_tx.inverse() * bottom_current_tx.origin
		#print(bottom_rest_in_top_space)
		#print(bottom_current_in_top_space)
#
		#var perpendicular_axis: Vector3 = bottom_rest_in_top_space.cross(bottom_current_in_top_space).normalized()
		#var dp: float = bottom_rest_in_top_space.normalized().dot(bottom_current_in_top_space.normalized())
		#var angle: float = acos(dp)
#
		#var new_tx: Transform3D = Transform3D(Basis(perpendicular_axis, angle))
		#skel.set_bone_pose(pair.top_index, skel.get_bone_rest(pair.top_index) * new_tx)

func _point_bone_to_other_bone(skel: Skeleton3D, top: int, bottom: int):
	var top_rest_tx: Transform3D = skel.get_bone_global_rest(top)
	var bottom_rest_tx: Transform3D = skel.get_bone_global_rest(bottom)
	var top_current_tx: Transform3D = skel.get_bone_global_pose(top)
	var bottom_current_tx: Transform3D = skel.get_bone_global_pose(bottom)

	var bottom_rest_in_top_space: Vector3 = top_rest_tx.inverse() * bottom_rest_tx.origin
	var bottom_current_in_top_space: Vector3 = top_current_tx.inverse() * bottom_current_tx.origin
	#print(bottom_rest_in_top_space)
	#print(bottom_current_in_top_space)

	var perpendicular_axis: Vector3 = bottom_rest_in_top_space.cross(bottom_current_in_top_space).normalized()

	var dp: float = bottom_rest_in_top_space.normalized().dot(bottom_current_in_top_space.normalized())
	var angle: float = acos(dp)
	#print(perpendicular_axis, " ", angle)

	var new_tx: Transform3D = Transform3D(Basis(perpendicular_axis, angle))
	skel.set_bone_pose(top, skel.get_bone_rest(top) * new_tx)
	#if (new_tx.origin).length() > 0.0:
	#	print("NOT MATCH")
	#print(skel.get_bone_name(top), " - ", skel.get_bone_name(bottom))
