extends Mod_Base

var minimum_z: float = 0.2
var use_model_height_scale: bool = true

func _ready() -> void:
	add_tracked_setting("minimum_z", "Minimum (relative) depth for hands compared to chest", {
		"min": -10.0, "max": 10.0, "step": 0.01
	})

	add_tracked_setting("use_model_height_scale", "Use the height of the model to scale the depth")

func _process(_delta: float) -> void:

	var skel: Skeleton3D = get_skeleton()
	var tracker_dict : Dictionary = get_global_mod_data("trackers")

	for side: String in ["left", "right"]:
		var hand_name: String = "hand_" + side
		if tracker_dict.has(hand_name):

			var tracker_transform: Transform3D = tracker_dict[hand_name].transform

			var chest_transform_global_pose: Transform3D = \
				skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Chest"))
			var chest_transform_global_pose_inv: Transform3D = \
				chest_transform_global_pose.inverse()

			# Apply minimum hand depth in the chest coordinate space.
			var target_origin_chest_space: Vector3 = \
				chest_transform_global_pose_inv * tracker_transform.origin
			var actual_minimum_z: float = minimum_z
			if use_model_height_scale:
				actual_minimum_z *= get_model_height_scale()
			target_origin_chest_space.z = \
				max(actual_minimum_z, target_origin_chest_space.z)

			tracker_dict[hand_name].transform.origin = \
				chest_transform_global_pose * target_origin_chest_space
