extends Mod_Base

var blendshape_name : String
var blendshape_value : float = 1.0

func _ready() -> void:
	add_tracked_setting("blendshape_name", "Blendshape Name", {}, "")
	add_tracked_setting("blendshape_value", "Value", { "min" : 0.0, "max" : 1.0 }, "")

func _clear_shape() -> void:
	get_app().get_controller().reset_blend_shapes()
	var blend_shape_dict : Dictionary = get_global_mod_data("BlendShapes")
	if blend_shape_dict.has(blendshape_name):
		blend_shape_dict.erase(blendshape_name)

func scene_shutdown() -> void:
	_clear_shape()

func load_before(_settings_old : Dictionary, _settings_new : Dictionary):
	_clear_shape()

func _process(delta: float) -> void:
	var blend_shape_dict : Dictionary = get_global_mod_data("BlendShapes")
	blend_shape_dict[blendshape_name] = blendshape_value

func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray = []

	if check_mod_dependency("Mod_AnimationApplier", false):
		errors.append("This mod needs to be ordered before the AnimationApplier mod.")

	return errors
