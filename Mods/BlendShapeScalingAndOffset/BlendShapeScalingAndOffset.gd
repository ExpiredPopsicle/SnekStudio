extends Mod_Base

const blendshape_names_mediapipe : PackedStringArray = [
	"_neutral",
	"browDownLeft",
	"browDownRight",
	"browInnerUp",
	"browOuterUpLeft",
	"browOuterUpRight",
	"cheekPuff",
	"cheekSquintLeft",
	"cheekSquintRight",
	"eyeBlinkLeft",
	"eyeBlinkRight",
	"eyeLookDownLeft",
	"eyeLookDownRight",
	"eyeLookInLeft",
	"eyeLookInRight",
	"eyeLookOutLeft",
	"eyeLookOutRight",
	"eyeLookUpLeft",
	"eyeLookUpRight",
	"eyeSquintLeft",
	"eyeSquintRight",
	"eyeWideLeft",
	"eyeWideRight",
	"jawForward",
	"jawLeft",
	"jawOpen",
	"jawRight",
	"mouthClose",
	"mouthDimpleLeft",
	"mouthDimpleRight",
	"mouthFrownLeft",
	"mouthFrownRight",
	"mouthFunnel",
	"mouthLeft",
	"mouthLowerDownLeft",
	"mouthLowerDownRight",
	"mouthPressLeft",
	"mouthPressRight",
	"mouthPucker",
	"mouthRight",
	"mouthRollLower",
	"mouthRollUpper",
	"mouthShrugLower",
	"mouthShrugUpper",
	"mouthSmileLeft",
	"mouthSmileRight",
	"mouthStretchLeft",
	"mouthStretchRight",
	"mouthUpperUpLeft",
	"mouthUpperUpRight",
	"noseSneerLeft",
	"noseSneerRight",
]

const blendshape_names_vrm1 : PackedStringArray = [
	"happy", "angry", "sad", "relaxed", "surprised",
	"aa", "ih", "ou", "ee", "oh",
	#"blink", # Disabled because we only use left/right.
	"blinkLeft", "blinkRight",
	"lookUp", "lookDown",
	"lookLeft", "lookRight",
	"neutral"
]

const blendshape_names_all : PackedStringArray = \
	blendshape_names_mediapipe + blendshape_names_vrm1

var blendshape_scales : Dictionary = {}
var blendshape_offsets : Dictionary = {}
var blendshape_smoothing : Dictionary = {}
var blendshape_progressbars : Dictionary = {}
var blendshape_progressbar_update_index : int = 0
# FIXME: Get rid of the hard-coded speed!!!
var blendshape_smoothing_scale : float = 0.05

var output_blendshape_data_last_frame : Dictionary = {}

func _add_tracked_settings_for_blendshapes(names : PackedStringArray, group_name : String):

	var group_internal_name : String = "blendshapes_scale_offset_" + group_name

	add_setting_group(
		group_internal_name,
		group_name)

	for blendshape_name in names:

		var label : Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = blendshape_name + " scale/offset/smoothing"
		# FIXME: Direct use of internal (indented private, not protected) variables.
		_settings_groups[group_internal_name].add_setting_control(label)

		var progressbar : ProgressBar = ProgressBar.new()
		progressbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progressbar.show_percentage = false
		progressbar.value = randf()
		progressbar.min_value = 0.0
		progressbar.max_value = 1.0
		progressbar.custom_minimum_size = Vector2(0, 32.0)
		# FIXME: Direct use of internal variables.
		_settings_groups[group_internal_name].add_setting_control(progressbar)

		# Mouth shapes start with scale doubled by default.
		if blendshape_name.begins_with("mouth") or blendshape_name.begins_with("jaw"):
			blendshape_scales[blendshape_name] = 2.0

		add_tracked_setting(
			"blendshape_scale_" + blendshape_name, "",  { "min" : 0.0, "max" : 5.0 },
			group_internal_name)
		add_tracked_setting(
			"blendshape_offset_" + blendshape_name, "",  { "min" : -2.0, "max" : 2.0 },
			group_internal_name)
		add_tracked_setting(
			"blendshape_smoothing_" + blendshape_name, "",  { "min" : 0.0, "max" : 10.0 },
			group_internal_name)

		blendshape_progressbars[blendshape_name] = progressbar

func _ready() -> void:

	_add_tracked_settings_for_blendshapes(blendshape_names_mediapipe, "MediaPipe")
	_add_tracked_settings_for_blendshapes(blendshape_names_vrm1, "VRM")

		# TODO: Link together left/right sides (optionally?)

	update_settings_ui()

func _process(delta: float) -> void:
	var blend_shapes_to_convert : Dictionary = get_global_mod_data("BlendShapes")

	apply_blendshape_scale_offset_dict(
		blend_shapes_to_convert, blendshape_scales, blendshape_offsets)

	# Update a few of the progress bars.
	var shape_keys : Array = blendshape_progressbars.keys()
	for i in range(0, 5):

		var shape_name : String = \
			shape_keys[blendshape_progressbar_update_index]

		if shape_name in blend_shapes_to_convert:
			blendshape_progressbars[shape_name].value = \
				blend_shapes_to_convert[shape_name]
		else:
			blendshape_progressbars[shape_name].value = 0.0

		blendshape_progressbar_update_index += 1
		blendshape_progressbar_update_index %= len(shape_keys)

	# Apply smoothing.
	var smoothed_shapes = apply_smoothing(
		output_blendshape_data_last_frame,
		blend_shapes_to_convert,
		delta)

	blend_shapes_to_convert.merge(smoothed_shapes, true)
	output_blendshape_data_last_frame = blend_shapes_to_convert.duplicate()


func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray
	if not check_mod_dependency("Mod_AnimationApplier", true):
		errors.append("No AnimationApplier detected.")
	return errors

func _get_property_list() -> Array[Dictionary]:

	var properties : Array[Dictionary] = []

	for blend_shape : String in blendshape_names_all:
		var new_entry_scale : Dictionary = {
			"name" : "blendshape_scale_" + blend_shape,
			"type" : TYPE_FLOAT
		}
		var new_entry_offset : Dictionary = {
			"name" : "blendshape_offset_" + blend_shape,
			"type" : TYPE_FLOAT
		}
		var new_entry_smoothing : Dictionary = {
			"name" : "blendshape_smoothing_" + blend_shape,
			"type" : TYPE_FLOAT
		}
		properties.append(new_entry_scale)
		properties.append(new_entry_offset)
		properties.append(new_entry_smoothing)

	return properties

func _get(property: StringName) -> Variant:

	if property.begins_with("blendshape_scale_"):
		var blendshape_name : String = property.substr(len("blendshape_scale_"))
		if blendshape_name in blendshape_names_all:
			if blendshape_name in blendshape_scales:
				return blendshape_scales[blendshape_name]
			else:
				return 1.0
		else:
			return null

	if property.begins_with("blendshape_offset_"):
		var blendshape_name : String = property.substr(len("blendshape_offset_"))
		if blendshape_name in blendshape_names_all:
			if blendshape_name in blendshape_offsets:
				return blendshape_offsets[blendshape_name]
			else:
				return 0.0
		else:
			return null

	if property.begins_with("blendshape_smoothing_"):
		var blendshape_name : String = property.substr(len("blendshape_smoothing_"))
		if blendshape_name in blendshape_names_all:
			if blendshape_name in blendshape_smoothing:
				return blendshape_smoothing[blendshape_name]
			else:
				return 0.0
		else:
			return null

	return null

func _set(property: StringName, value: Variant) -> bool:

	if property.begins_with("blendshape_smoothing_"):
		var blendshape_name : String = property.substr(len("blendshape_smoothing_"))
		if blendshape_name in blendshape_names_all:
			if value == 0.0:
				blendshape_smoothing.erase(blendshape_name)
			else:
				blendshape_smoothing[blendshape_name] = value
			return true
		else:
			return false

	if property.begins_with("blendshape_scale_"):
		var blendshape_name : String = property.substr(len("blendshape_scale_"))
		if blendshape_name in blendshape_names_all:
			if value == 1.0:
				blendshape_scales.erase(blendshape_name)
			else:
				blendshape_scales[blendshape_name] = value
			return true
		else:
			return false

	if property.begins_with("blendshape_offset_"):
		var blendshape_name : String = property.substr(len("blendshape_offset_"))
		if blendshape_name in blendshape_names_all:
			if value == 0.0:
				blendshape_offsets.erase(blendshape_name)
			else:
				blendshape_offsets[blendshape_name] = value
			return true
		else:
			return false

	return false

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

func apply_smoothing(
	shape_dict_last_frame : Dictionary,
	shape_dict_from_tracker : Dictionary,
	delta : float):

	var shape_dict_new = shape_dict_last_frame.duplicate()

	for shape_name in shape_dict_from_tracker.keys():

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
