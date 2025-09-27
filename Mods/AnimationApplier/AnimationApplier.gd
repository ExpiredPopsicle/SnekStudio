extends Mod_Base
class_name Mod_AnimationApplier

func _process(_delta: float) -> void:
	var blend_shapes_to_apply : Dictionary = get_global_mod_data("BlendShapes")

	var model : Node3D = get_model()

	apply_animations(model, blend_shapes_to_apply)

static func apply_animations(model, shape_dict):

	# Merge blend shapes with overridden stuff.
	var combined_blend_shape_last_values = shape_dict.duplicate()

	# Blend shapes are treated as the maximum value of any animations that
	# reference them.
	#
	# FIXME: Maybe these should be like the weighted averages, too?
	#   Sometimes someone might want to set a lower influence for some
	#   blendshape proxies.
	var blend_shape_maximums = {}

	# These are for value tracks. We're going to treat them as a weighted
	# average. There's an added twist in that, if the total weight is less than
	# 1.0, then we fill in the rest of the weighted average (1.0-weight) with
	# the values from the "RESET" animation.
	var value_average_totals = {}
	var value_average_weights = {}
	var value_rest_values = {}

	var total_bone_rotations = {}

	var anim_player : AnimationPlayer = model.find_child("AnimationPlayer", false, false)

	# Can't continue if there's no animation player.
	if not anim_player:
		return

	var anim_list : PackedStringArray = anim_player.get_animation_list()
	var anim_root = anim_player.get_node(anim_player.root_node)

	if anim_player:

		# Find all the "rest" values to blend with.
		var rest_anim : Animation = anim_player.get_animation("RESET")
		if rest_anim:
			for track_index in range(0, rest_anim.get_track_count()):
				if rest_anim.track_get_type(track_index) == Animation.TYPE_VALUE:
					var track_path : NodePath = rest_anim.track_get_path(track_index)
					value_rest_values[track_path] = \
						rest_anim.track_get_key_value(track_index, 0)

		for anim_name in combined_blend_shape_last_values.keys():

			# Skip any animations that don't exist in this VRM.				
			var full_anim_name = anim_name

			# Case-correct the animation name, and also verify that it's even
			# in the list.
			var found_animation_in_list = false
			for possible_anim_name in anim_list:
				if possible_anim_name.to_lower() == full_anim_name.to_lower():
					full_anim_name = possible_anim_name
					found_animation_in_list = true
					break
			
			if not found_animation_in_list:
				continue

			var anim = anim_player.get_animation(full_anim_name)

			if not anim:
				continue
				
			# Iterate through every track on the animation.
			for track_index in range(0, anim.get_track_count()):

				var anim_path : NodePath = anim.track_get_path(track_index)
			
				if anim.track_get_type(track_index) == Animation.TYPE_ROTATION_3D:

					# These tracks typically apply to eye direction stuff. The
					# VRM addon sets these up for us.

					if not anim_path in total_bone_rotations:
						total_bone_rotations[anim_path] = Quaternion()

					# Get the rest orientation.
					var bone_name = anim_path.get_subname(0)
					var node_to_modify_path = str(anim_path.get_concatenated_names())
					var node_to_modify : Skeleton3D = anim_root.get_node(node_to_modify_path)
					var bone_index = node_to_modify.find_bone(bone_name)
					var rest_orientation = Quaternion()
					if bone_index != -1:
						rest_orientation = node_to_modify.get_bone_rest(bone_index).basis.get_rotation_quaternion()
					
					var alpha = combined_blend_shape_last_values[anim_name]
					#alpha /= 10
					var kt = anim.track_get_key_time(track_index, 0)
					var q = anim.rotation_track_interpolate(
						track_index, kt)
						#combined_blend_shape_last_values[anim_name]) # FIXME: Do we need this here if there's on the one key?
					
					q = rest_orientation.inverse() * q
					
					#print(alpha, " - ", kt)
					q = Quaternion().slerp(q, alpha / kt)
					
					#if anim_name == "lookLeft":
					total_bone_rotations[anim_path] *= q #total_bone_rotations[anim_path].slerp(q, kt)
		
				if anim.track_get_type(track_index) == Animation.TYPE_BLEND_SHAPE:

					# Create the key if it does not exist.
					if not (anim_path in blend_shape_maximums.keys()):
						blend_shape_maximums[anim_path] = 0.0

					# Record max value.
					blend_shape_maximums[anim_path] = max(
						blend_shape_maximums[anim_path],
						combined_blend_shape_last_values[anim_name] * anim.track_get_key_value(track_index, 0))

				if anim.track_get_type(track_index) == Animation.TYPE_VALUE:

					# Values: Add to our weighted average.
					if not value_average_totals.has(anim_path):
						value_average_totals[anim_path] = \
							anim.track_get_key_value(track_index, 0) * combined_blend_shape_last_values[anim_name]
						value_average_weights[anim_path] = \
							combined_blend_shape_last_values[anim_name]
					else:
						value_average_totals[anim_path] += \
							anim.track_get_key_value(track_index, 0) * combined_blend_shape_last_values[anim_name]
						value_average_weights[anim_path] += \
							combined_blend_shape_last_values[anim_name]

		# Iterate through every max animation value and set it on the
		# appropriate blend shape on the object.
		if anim_root:

			for anim_path_max_value_key in blend_shape_maximums.keys():
				var object_to_animate : Node = anim_root.get_node(anim_path_max_value_key)
				if object_to_animate:
					object_to_animate.set(
						"blend_shapes/" + anim_path_max_value_key.get_subname(0),
						blend_shape_maximums[anim_path_max_value_key])

			# Handle "value" track types. Typically material properties.
			for value_key in value_average_totals.keys():

				# Add in the "rest" value if we're under 1.0 total influence.
				if value_average_weights[value_key] < 1.0:
					value_average_totals[value_key] += \
						(1.0 - value_average_weights[value_key]) * \
						value_rest_values[value_key]
					value_average_weights[value_key] = 1.0

				# Apply average value.
				var object_to_animate : Node = anim_root.get_node(value_key)
				if object_to_animate:
					var avg_value = value_average_totals[value_key] / value_average_weights[value_key]
					object_to_animate.set_indexed(
						NodePath(value_key.get_concatenated_subnames()),
						avg_value)

			for anim_path_rotation_key in total_bone_rotations.keys():
				var bone_name = anim_path_rotation_key.get_subname(0)
				var node_to_modify_path = str(anim_path_rotation_key.get_concatenated_names())
				var node_to_modify : Skeleton3D = anim_root.get_node(node_to_modify_path)
				var bone_index = node_to_modify.find_bone(bone_name)
				if bone_index != -1:
					node_to_modify.set_bone_pose_rotation(
						bone_index,
						node_to_modify.get_bone_rest(bone_index).basis.get_rotation_quaternion() *
						total_bone_rotations[anim_path_rotation_key])

func needs_3D_transform() -> bool:
	return false
