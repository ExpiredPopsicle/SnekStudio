extends Mod_Base

var remove_other_shapes : bool = false

func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray
	if not check_mod_dependency("Mod_MediaPipeController", false):
		errors.append("Missing MediaPipeController.")
	if not check_mod_dependency("Mod_AnimationApplier", true):
		errors.append("No AnimationApplier detected.")
	return errors

func _ready() -> void:
	add_tracked_setting("remove_other_shapes", "Exclude other shapes")

func _process(delta: float) -> void:

	var blend_shapes_to_convert : Dictionary = get_global_mod_data("BlendShapes")
	var output_shapes : Dictionary = convert_mediapipe_shapes_to_vrm_standard(blend_shapes_to_convert)

	if remove_other_shapes:
		blend_shapes_to_convert.clear()

	blend_shapes_to_convert.merge(output_shapes)

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
