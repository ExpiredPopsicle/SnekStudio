extends Object

# FIXME: We may need to make this aware of both VRM 0.0 and VRM 1.0, unless the
#   VRM addon is doing conversion for us already.
#   See https://github.com/vrm-c/vrm-specification/blob/282edef7b8de6044d782afdab12b14bd8ccf0630/specification/VRMC_vrm-1.0/expressions.md
static func convert_mediapipe_shapes_to_vrm_standard(shape_dict):
	var basic_shapes = {}
	# TODO: sorrow, anger, fun, joy
	
	if "browDownLeft" in shape_dict and "browOuterUpLeft" in shape_dict and \
		"browDownRight" in shape_dict and "browOuterUpRight" in shape_dict:
		
		basic_shapes["Brows up"] = lerp(shape_dict["browOuterUpLeft"], shape_dict["browOuterUpRight"], 0.5)
		basic_shapes["Brows down"] = lerp(shape_dict["browDownLeft"], shape_dict["browDownRight"], 0.5)

	if "eyeWideLeft" in shape_dict and "eyeWideRight" in shape_dict:
		basic_shapes["surprised"] = clamp(
			lerp(
				shape_dict["eyeWideLeft"],
				shape_dict["eyeWideRight"], 0.5), 0.0, 1.0)

	if "eyeBlinkLeft" in shape_dict:
		basic_shapes["blinkLeft"] = clamp(shape_dict["eyeBlinkLeft"], 0.0, 1.0)
	if "eyeBlinkRight" in shape_dict:
		basic_shapes["blinkRight"] = clamp(shape_dict["eyeBlinkRight"], 0.0, 1.0)


	if "mouthSmileLeft" in shape_dict and "mouthSmileRight" in shape_dict:
		basic_shapes["relaxed"] = clamp(
			lerp(
				shape_dict["mouthSmileLeft"],
				shape_dict["mouthSmileRight"], 0.5), 0.0, 1.0)
					

	if "jawOpen" in shape_dict:
		var shape_ou = shape_dict["mouthPucker"]
		var shape_oh = shape_dict["mouthFunnel"]
		var shape_ih = lerp(shape_dict["mouthLeft"], shape_dict["mouthRight"], 0.5)
		var shape_ee = lerp(shape_dict["mouthLowerDownLeft"], shape_dict["mouthLowerDownRight"], 0.5)
		
		var mouthshape_total = shape_ou + shape_oh + shape_ih + shape_ee
		#shape_oh /= mouthshape_total
		#shape_ou /= mouthshape_total
		#shape_ih /= mouthshape_total
		#shape_ee /= mouthshape_total
		var shape_aa = clamp(1.0 - mouthshape_total, 0.0, 1.0)
		
		basic_shapes["ou"] = shape_ou
		basic_shapes["oh"] = shape_oh
		basic_shapes["aa"] = shape_aa
		basic_shapes["ih"] = shape_ih
		basic_shapes["ee"] = shape_ee
		
		var mouth_shape_names = ["ou", "oh", "aa", "ih", "ee"]
		var max_mouth_shape_name = "ou"
		for shape_name in mouth_shape_names:
			if basic_shapes[shape_name] > basic_shapes[max_mouth_shape_name]:
				max_mouth_shape_name = shape_name
		for shape_name in mouth_shape_names:
			if shape_name != max_mouth_shape_name:
				basic_shapes[shape_name] = 0.0
			else:
				basic_shapes[shape_name] *= clamp(shape_dict["jawOpen"] * 1.0, 0.0, 1.0)
	
	if "relaxed" in basic_shapes and "jawOpen" in shape_dict:
		basic_shapes["relaxed"] *= clamp(1.0 - shape_dict["jawOpen"], 0.0, 1.0)

	if "relaxed" in basic_shapes and "blinkLeft" in basic_shapes and "blinkRight" in basic_shapes:
		# Override blinks.
		if "eyeBlinkLeft" in basic_shapes:
			basic_shapes["blinkLeft"] *= 1.0 - basic_shapes["relaxed"]
		if "eyeBlinkRight" in basic_shapes:
			basic_shapes["blinkRight"] *= 1.0 - basic_shapes["relaxed"]

	# Eye stuff
	if ("eyeLookUpLeft" in shape_dict) and ("eyeLookUpRight" in shape_dict):
		basic_shapes["lookUp"] = lerp(
			shape_dict["eyeLookUpLeft"],
			shape_dict["eyeLookUpRight"], 0.5)
	if ("eyeLookDownLeft" in shape_dict) and ("eyeLookDownRight" in shape_dict):
		basic_shapes["lookDown"] = lerp(
			shape_dict["eyeLookDownLeft"],
			shape_dict["eyeLookDownRight"], 0.5)
	if ("eyeLookInLeft" in shape_dict) and ("eyeLookOutRight" in shape_dict):
		basic_shapes["lookRight"] = lerp(
			shape_dict["eyeLookInLeft"],
			shape_dict["eyeLookOutRight"], 0.5)
	if ("eyeLookInRight" in shape_dict) and ("eyeLookOutLeft" in shape_dict):
		basic_shapes["lookLeft"] = lerp(
			shape_dict["eyeLookOutLeft"],
			shape_dict["eyeLookInRight"], 0.5)

	return basic_shapes

static func apply_blendshape_scale(shape_dict, scale):
	for name in shape_dict.keys():
		shape_dict[name] *= scale

static func apply_blendshape_scale_offset_dict(
	shape_dict : Dictionary,
	scale_dict : Dictionary,
	offset_dict : Dictionary) -> void:

	var shape_names : Array = shape_dict.keys()
	for shape : String in shape_names:
		if shape in scale_dict:
			shape_dict[shape] *= scale_dict[shape]
		if shape in offset_dict:
			shape_dict[shape] += offset_dict[shape]

		# FIXME: Should we be doing this here? Where's it normally done?
		shape_dict[shape] = clampf(shape_dict[shape], 0.0, 1.0)

static func apply_smoothing(shape_dict_last_frame, shape_dict_from_tracker, delta):

	var shape_dict_new = shape_dict_last_frame.duplicate()

	for shape_name in shape_dict_from_tracker.keys():

		# FIXME: Get rid of the hard-coded speed!!!

		if shape_name in shape_dict_last_frame:

			# This shape existed last frame. LERP to the new value, if necessary.
			
			var old = shape_dict_last_frame[shape_name]
			var new = shape_dict_from_tracker[shape_name]
			
			# Update at higher rate for mouth shapes, so we can maybe get some
			# better lip syncing.
			# FIXME: Make which bones this applies to configurable.
			var basic_vrm_mouth_shape_names = ["ou", "oh", "aa", "ih", "ee"]
			if shape_name.begins_with("mouth") or shape_name in basic_vrm_mouth_shape_names:
				# Exaggerate mouth shapes other than "close".
				# FIXME: Make scale amount configurable!!!!!
				if shape_name != "mouthClose":
					new = clamp(new * 2.0, 0.0, 1.0)
				shape_dict_new[shape_name] = new
			else:
				# FIXME: Don't use a hardcoded blend speed!
				shape_dict_new[shape_name] = lerp(old, new,
					clamp(delta * 30.0, 0.0, 1.0))

		else:
			# This shape didn't exist last frame at all. Just snap directly to
			# it.
			shape_dict_new[shape_name] = \
				clamp(shape_dict_from_tracker[shape_name], 0.0, 1.0) * 1.0

	return shape_dict_new

static func fixup_eyes(shape_dict_new : Dictionary):

	shape_dict_new = shape_dict_new.duplicate()

	# Prevent eyes from pointing in opposite directions.
	if ("eyeLookOutLeft" in shape_dict_new) and \
		("eyeLookOutRight" in shape_dict_new) and \
		("eyeLookInLeft" in shape_dict_new) and \
		("eyeLookInRight" in shape_dict_new):

		var out_left = shape_dict_new["eyeLookOutLeft"]
		var out_right = shape_dict_new["eyeLookOutRight"]
		var in_left = shape_dict_new["eyeLookInLeft"]
		var in_right = shape_dict_new["eyeLookInRight"]

		var eye_pos_left = out_left - in_left
		var eye_pos_right = in_right - out_right

		var eye_apart_amount = eye_pos_left - eye_pos_right

		if eye_apart_amount > 0.0:
			var eye_avg = (eye_pos_left + eye_pos_right) / 2.0
			shape_dict_new["eyeLookOutLeft"] = (eye_avg + in_left)
			shape_dict_new["eyeLookOutRight"] = -(eye_avg - in_right)

#	# Prevent eyes from pointing in opposite directions, vertically.
#	if ("eyeLookUpLeft" in blend_shape_last_values) and \
#		("eyeLookUpRight" in blend_shape_last_values) and \
#		("eyeLookDownLeft" in blend_shape_last_values) and \
#		("eyeLookDownRight" in blend_shape_last_values):
#
#		var up_avg = (blend_shape_last_values["eyeLookUpLeft"] + blend_shape_last_values["eyeLookUpRight"])
#		var down_avg = (blend_shape_last_values["eyeLookDownLeft"] + blend_shape_last_values["eyeLookDownRight"])
#		blend_shape_last_values["eyeLookDownLeft"] = down_avg
#		blend_shape_last_values["eyeLookDownRight"] = down_avg
#		blend_shape_last_values["eyeLookUpLeft"] = up_avg
#		blend_shape_last_values["eyeLookUpRight"] = up_avg

	# Clamp some eye values now that we've messed with them.
	for shape in [
		"eyeLookUpRight",   "eyeLookUpLeft",
		"eyeLookDownRight", "eyeLookDownLeft",
		"eyeLookInRight",   "eyeLookInLeft",
		"eyeLookOutRight",  "eyeLookOutLeft"]:
		if shape in shape_dict_new:
			shape_dict_new[shape] = clamp(shape_dict_new[shape], 0.0, 1.0)

	return shape_dict_new

static func apply_animations(model, shape_dict):

	# Merge blend shapes with overridden stuff.
	var combined_blend_shape_last_values = shape_dict.duplicate()

	# FIXME: Should we restore this, or just rely on other mods down the stack?
#	for k in overridden_blend_shape_values.keys():
#		if k in combined_blend_shape_last_values:
#			combined_blend_shape_last_values[k] = max(
#				overridden_blend_shape_values[k],
#				combined_blend_shape_last_values[k])
#		else:
#			combined_blend_shape_last_values[k] =  overridden_blend_shape_values[k]

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
	var anim_list : PackedStringArray = anim_player.get_animation_list()
	var anim_root = anim_player.get_node(anim_player.root_node)

	anim_player.play("RESET")
	anim_player.advance(0)
	anim_player.stop()

	if anim_player:
		#print("list...")
		#print(anim_player.get_animation_list())

		# Figure out the maximum blend shape values for each animation.
		#if "lookLeft" in combined_blend_shape_last_values:
			#combined_blend_shape_last_values = {
				#"lookLeft" : combined_blend_shape_last_values["lookLeft"]
			#}

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

static func apply_rest_shapes(
	shape_dict_last_frame : Dictionary,
	delta : float, speed : float) -> Dictionary:

	var new_dict = {}

	var keys = shape_dict_last_frame.keys()
	for key in keys:
		new_dict[key] = clamp(
			lerp(
				shape_dict_last_frame[key],
				0.0, speed * delta), 0.0, 1.0)

	return new_dict
