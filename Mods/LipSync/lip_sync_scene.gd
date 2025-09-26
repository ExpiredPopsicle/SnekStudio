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

var input_device : Array = Array()

var viseme_progressbars : Dictionary = {}
var has_mediapipe_controller : bool = false

func _ready():
	var input_devices : Array = AudioServer.get_input_device_list()
	
	add_tracked_setting("input_device", "Input device", 
		{ 
			"allow_multiple": false, 
			"combobox": true, 
			"values": input_devices 
		})
	add_tracked_setting("is_basic_vrm_shapes", "Use basic VRM shapes")
	add_tracked_setting("prefer_mediapipe_tracker", "Prefer MediaPipe data (must be enabled) over lipsync")
	add_tracked_setting("prefer_mediapipe_greater_than_value_perc", 
		"Prefer lipsync data when MediaPipe blendshape value is less than X%", 
		{ "min": 1.0, "max": 100.0 })

	add_setting_group("lipsync_engine", "Engine")
	add_tracked_setting("engine_precision", 
		"Precision (higher is better)", 
		{ "min": 0.01, "max": 1.0 }, 
		"lipsync_engine")
	add_tracked_setting("engine_slew", 
		"Slew (lower is better)", 
		{ "min": 1, "max": 100 }, 
		"lipsync_engine")
	add_tracked_setting("engine_viseme_weight_multiplier", 
		"Viseme weight multiplier", 
		{ "min": 1, "max": 20 }, 
		"lipsync_engine")

	add_setting_group("lipsync_visemes", "Visemes")

	# Add the visemes to the settings UI for debug.
	for vis in range(Visemes.VISEME.COUNT):
		var vis_name = engine.VISEME_NAMES[vis]
		var label : Label = Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = vis_name + " Value"
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

		viseme_progressbars[vis_name] = progressbar

	update_settings_ui()

func _process(_delta : float):
	if len(input_device) > 0 and AudioServer.input_device != input_device[0]:
		AudioServer.set_input_device(input_device[0])

	for vis in range(Visemes.VISEME.COUNT):
		var viseme_value = clampf(engine.visemes[vis] * 
								engine_viseme_weight_multiplier, -1.0, 1.0)
		var vis_name = engine.VISEME_NAMES[vis]
		var progressbar : ProgressBar = viseme_progressbars[vis_name]
		progressbar.value = viseme_value

	var blendshapes : Dictionary =  get_global_mod_data("BlendShapes")

	var mediapipe_vals : Dictionary = engine.current_mediapipe_values
	if is_basic_vrm_shapes:
		mediapipe_vals = engine.current_basic_vrm_values

	if prefer_mediapipe_tracker and has_mediapipe_controller:
		for val : String in mediapipe_vals.duplicate():
			# Check to see if we have significant differences.
			if mediapipe_vals[val] < 0.001 or not blendshapes.has(val) \
				or blendshapes[val] > (prefer_mediapipe_greater_than_value_perc / 100.0):
				mediapipe_vals.erase(val)

	# Always merge at the end.
	blendshapes.merge(mediapipe_vals, true)

func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray = []

	if not ProjectSettings.get_setting("audio/driver/enable_input"):
		errors.append("Audio input not enabled in project, verify project settings -> Advanced Settings -> Audio -> Driver -> \"Enable Input\" is enabled.")

	if not check_mod_dependency("Mod_AnimationApplier", true):
		errors.append("No AnimationApplier detected, or detected before LipSync. Blend shapes will not function as expected.")

	has_mediapipe_controller = check_mod_dependency("Mod_MediaPipeController", false)

	return errors
