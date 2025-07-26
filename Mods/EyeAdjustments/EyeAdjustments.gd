extends Mod_Base

var eyes_link_vertical : bool = false
var eyes_link_horizontal : bool = false
var eyes_link_blink : bool = false
var eyes_prevent_opposite_directions : bool = true

func check_configuration() -> PackedStringArray:

	var errors : PackedStringArray
	if not check_mod_dependency("Mod_MediaPipeController", false):
		errors.append("Missing MediaPipeController. This only works on MediaPipe Blendshapes.")

	if check_mod_dependency("Mod_MediaPipeToVRMShapes", false):
		errors.append("MediaPipeToVRMShapes is before this. Fixed eye shapes will not be considered in VRM shapes.")

	if not check_mod_dependency("Mod_AnimationApplier", true):
		errors.append("No AnimationApplier detected.")

	return errors

func _ready() -> void:
	
	add_tracked_setting(
		"eyes_prevent_opposite_directions", "Prevent eyes looking outwards")
	add_tracked_setting(
		"eyes_link_vertical", "Link eyes vertical direction")
	add_tracked_setting(
		"eyes_link_horizontal", "Link eyes horizontal direction")
	add_tracked_setting(
		"eyes_link_blink", "Link eyes blinking")
	
	update_settings_ui()

func _process(_delta: float) -> void:

	var blend_shapes_to_adjust : Dictionary = get_global_mod_data("BlendShapes")
	var new_shapes : Dictionary = fixup_eyes(blend_shapes_to_adjust)

	blend_shapes_to_adjust.merge(new_shapes, true)

func fixup_eyes(shape_dict_new : Dictionary) -> Dictionary:

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
