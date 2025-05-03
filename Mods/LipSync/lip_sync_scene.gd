extends Mod_Base
class_name LipSyncScene

@export var engine : LipSync

var is_tracking : bool = true
var is_basic_vrm_shapes : bool = false
var prefer_mediapipe_tracker : bool = true
var prefer_mediapipe_greater_than_value_perc : float = 8:
	set(new_percent):
		if new_percent <= 0:
			return
		prefer_mediapipe_greater_than_value_perc = new_percent
	get:
		return prefer_mediapipe_greater_than_value_perc
var engine_precision : float = 1.0:
	set(new_prec):
		engine_precision = new_prec
		engine.precision = engine_precision
	get:
		return engine_precision
var engine_slew : float = 15:
	set(new_slew):
		engine_slew = new_slew
		engine.slew = engine_slew
	get:
		return engine_slew
var engine_viseme_weight_multiplier : float = 4.0:
	set(new_multiplier):
		engine_viseme_weight_multiplier = new_multiplier
		engine.viseme_weight_multiplier = engine_viseme_weight_multiplier
	get:
		return engine_viseme_weight_multiplier

var viseme_progressbars : Dictionary = {}

var vrm_mapping = [
	"sil",
	"",
	"",
	"E",
	"",
	"ih",
	"oh",
	"",
	"",
	"",
	"",
	"ou",
	"aa",
	"",
	""
]
var vrm_mapping_basic = [
	"sil",
	"",
	"",
	"ee",
	"",
	"ih",
	"oh",
	"",
	"",
	"",
	"",
	"ou",
	"aa",
	"",
	""
]

func scene_shutdown():
	get_global_mod_data("VisemeBlendShapes").clear()
	
func _ready():
	add_tracked_setting("is_basic_vrm_shapes", "Use basic VRM shapes")
	add_tracked_setting("prefer_mediapipe_tracker", "Prefer real tracker over lipsync")
	add_tracked_setting("prefer_mediapipe_greater_than_value_perc", "Prefer lipsync when tracking value is less than ...", { "min": 1.0, "max": 100.0 })
	add_setting_group("lipsync_engine", "Engine")
	add_tracked_setting("engine_precision", "Precision (higher is better)", { "min": 0.01, "max": 1.0 }, "lipsync_engine")
	add_tracked_setting("engine_slew", "Slew (lower is better)", { "min": 1, "max": 100 }, "lipsync_engine")
	add_tracked_setting("engine_viseme_weight_multiplier", "Viseme weight multiplier", { "min": 1, "max": 20 }, "lipsync_engine")
	
	add_setting_group("lipsync_visemes", "Visemes")
	
	# Add the visemes to the settings UI for debug.
	for vis in range(Visemes.VISEME.COUNT):
		var name = engine.VISEME_NAMES[vis]
		var label : Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = name + " Value"
		# FIXME: Direct use of internal (indented private, not protected) variables.
		_settings_groups["lipsync_visemes"].add_setting_control(label)

		var progressbar : ProgressBar = ProgressBar.new()
		progressbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progressbar.show_percentage = false
		progressbar.value = randf()
		progressbar.min_value = 0.0
		progressbar.max_value = 1.0
		progressbar.custom_minimum_size = Vector2(0, 32.0)
		# FIXME: Direct use of internal variables.
		_settings_groups["lipsync_visemes"].add_setting_control(progressbar)
		
		viseme_progressbars[name] = progressbar
		
	update_settings_ui()

func _process(delta : float):
	for vis in range(Visemes.VISEME.COUNT):
		var viseme_value = clampf(engine.visemes[vis] * 5, -1.0, 1.0)
		var name = engine.VISEME_NAMES[vis]
		var progressbar : ProgressBar = viseme_progressbars[name]
		progressbar.value = viseme_value
		
	var blendshapes : Dictionary =  get_global_mod_data("BlendShapes")
	
	var mediapipe_vals = engine.current_mediapipe_values
	if is_basic_vrm_shapes:
		mediapipe_vals = engine.current_basic_vrm_values

	if prefer_mediapipe_tracker:
		for val in mediapipe_vals.duplicate():
			# Check to see if we have significant differences.
			if mediapipe_vals[val] < 0.001 or not blendshapes.has(val) \
				or blendshapes[val] > (prefer_mediapipe_greater_than_value_perc / 100.0):
				mediapipe_vals.erase(val)
			

	# Always merge at the end.
	blendshapes.merge(mediapipe_vals, true)
