extends Object


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

static func apply_smoothing(
	shape_dict_last_frame : Dictionary, shape_dict_from_tracker : Dictionary, delta : float,
	blendshape_smoothing_scale : float, blendshape_smoothing : Dictionary):

	var shape_dict_new = shape_dict_last_frame.duplicate()

	for shape_name in shape_dict_from_tracker.keys():

		# FIXME: Get rid of the hard-coded speed!!!

		if shape_name in shape_dict_last_frame:

			# This shape existed last frame. LERP to the new value, if necessary.

			var old = shape_dict_last_frame[shape_name]
			var new = shape_dict_from_tracker[shape_name]

			var total_scale : float = blendshape_smoothing_scale

			if shape_name in blendshape_smoothing:
				total_scale *= blendshape_smoothing[shape_name]
			else:
				total_scale = 0.0

			if total_scale <= 0.0:
				shape_dict_new[shape_name] = new
			else:
				shape_dict_new[shape_name] = lerp(old, new,
					clamp(delta / blendshape_smoothing_scale, 0.0, 1.0))

		else:
			# This shape didn't exist last frame at all. Just snap directly to
			# it.
			shape_dict_new[shape_name] = \
				clamp(shape_dict_from_tracker[shape_name], 0.0, 1.0) * 1.0

	return shape_dict_new

static func fixup_eyes(
	shape_dict_new : Dictionary,
	eyes_prevent_opposite_directions : bool,
	eyes_link_vertical : bool,
	eyes_link_horizontal : bool,
	eyes_link_blink : bool) -> Dictionary:

	shape_dict_new = shape_dict_new.duplicate()

	# Prevent eyes from pointing in opposite directions, horizontally.
	if eyes_prevent_opposite_directions:
		if ("eyeLookOutLeft" in shape_dict_new) and \
			("eyeLookOutRight" in shape_dict_new) and \
			("eyeLookInLeft" in shape_dict_new) and \
			("eyeLookInRight" in shape_dict_new):

			var out_left : float = shape_dict_new["eyeLookOutLeft"]
			var out_right : float = shape_dict_new["eyeLookOutRight"]
			var in_left : float = shape_dict_new["eyeLookInLeft"]
			var in_right : float = shape_dict_new["eyeLookInRight"]

			var eye_pos_left : float = out_left - in_left
			var eye_pos_right : float = in_right - out_right

			var eye_apart_amount : float = eye_pos_left - eye_pos_right

			if eye_apart_amount > 0.0:
				var eye_avg : float = (eye_pos_left + eye_pos_right) / 2.0
				shape_dict_new["eyeLookOutLeft"] = (eye_avg + in_left)
				shape_dict_new["eyeLookOutRight"] = -(eye_avg - in_right)

	# Link eye vertical movement.
	if eyes_link_vertical:
		if ("eyeLookUpLeft" in shape_dict_new) and \
			("eyeLookUpRight" in shape_dict_new) and \
			("eyeLookDownLeft" in shape_dict_new) and \
			("eyeLookDownRight" in shape_dict_new):

			var up_avg : float = (shape_dict_new["eyeLookUpLeft"] + shape_dict_new["eyeLookUpRight"]) / 2.0
			var down_avg : float = (shape_dict_new["eyeLookDownLeft"] + shape_dict_new["eyeLookDownRight"]) / 2.0
			shape_dict_new["eyeLookUpLeft"] = up_avg
			shape_dict_new["eyeLookUpRight"] = up_avg
			shape_dict_new["eyeLookDownLeft"] = down_avg
			shape_dict_new["eyeLookDownRight"] = down_avg

	# Link eye horizontal movement.
	if eyes_link_horizontal:
		if ("eyeLookOutLeft" in shape_dict_new) and \
			("eyeLookOutRight" in shape_dict_new) and \
			("eyeLookInLeft" in shape_dict_new) and \
			("eyeLookInRight" in shape_dict_new):

			var left_avg : float = (shape_dict_new["eyeLookOutLeft"] + shape_dict_new["eyeLookInRight"]) / 2.0
			var right_avg : float = (shape_dict_new["eyeLookInLeft"] + shape_dict_new["eyeLookOutRight"]) / 2.0
			shape_dict_new["eyeLookOutLeft"] = left_avg
			shape_dict_new["eyeLookInLeft"] = right_avg
			shape_dict_new["eyeLookInRight"] = left_avg
			shape_dict_new["eyeLookOutRight"] = right_avg

	# Link eyes blinking.
	if eyes_link_blink:
		if ("eyeBlinkLeft" in shape_dict_new) and \
			("eyeBlinkRight" in shape_dict_new):

			# We can't just use the average value between the eyes here, because
			# the common situation where one eye doesn't fully close would then
			# just cause *both* eyes to never fully close.
			#
			# So instead we're going to try to guess whether the eyes are more
			# open or closed, and then go with the more-open or more-closed
			# value based on that.
			#
			# This will end up with a distribution where eye blink states end up
			# leaning more fully open or fully closed, where the average would
			# just have it looking partially-clased all the time.

			var eye_blink_new : float = 0.5

			# First we need to see if we're mostly-blinking or mostly-open.
			var eye_blink_avg : float = \
				(shape_dict_new["eyeBlinkLeft"] +
				shape_dict_new["eyeBlinkRight"]) / 2.0

			# If we're mostly-open, then take the blink value from the
			# more-open eye and use that. Otherwise, if we're mostly-closed,
			# take the blink value from the mostly-closed eye and use that.
			if eye_blink_avg < 0.5:
				eye_blink_new = min(shape_dict_new["eyeBlinkLeft"], shape_dict_new["eyeBlinkRight"])
			else:
				eye_blink_new = max(shape_dict_new["eyeBlinkLeft"], shape_dict_new["eyeBlinkRight"])

			# Finally, override our blink values with the ones we calculated.
			shape_dict_new["eyeBlinkRight"] = eye_blink_new
			shape_dict_new["eyeBlinkLeft"] = eye_blink_new

	# Clamp some eye values now that we've messed with them.
	for shape : String in [
		"eyeLookUpRight",   "eyeLookUpLeft",
		"eyeLookDownRight", "eyeLookDownLeft",
		"eyeLookInRight",   "eyeLookInLeft",
		"eyeLookOutRight",  "eyeLookOutLeft"]:
		if shape in shape_dict_new:
			shape_dict_new[shape] = clamp(shape_dict_new[shape], 0.0, 1.0)

	return shape_dict_new

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
