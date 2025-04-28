extends Mod_Base
class_name LipSyncScene
@export var engine : LipSync

var viseme_progressbars : Dictionary = {}
var viseme_names = [
		"Silent",
		"CH",
		"DD",
		"E",
		"Ff",
		"I",
		"O",
		"PP",
		"RR",
		"SS",
		"TH",
		"U",
		"AA",
		"KK",
		"NN"
	]
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
func _ready():
	
	# Small tweaks
	engine.precision = 1.0
	engine.slew = 15
	
	#VISEME_SILENT = 0,	# Mouth closed (silent)
	#VISEME_CH = 1,		# /tS/ (CHeck, CHoose) /dZ/ (Job, aGe) /S/ (She, puSh)
	#VISEME_DD = 2,		# /t/ (Take, haT) /d/ (Day, haD)
	#VISEME_E = 3,		# /e/ (Ever, bEd)
	#VISEME_FF = 4,		# /f/ (Fan) /v/ (Van)
	#VISEME_I = 5,		# /ih/ (fIx, offIce)
	#VISEME_O = 6,		# /o/ (Otter, stOp)
	#VISEME_PP = 7,		# /p/ (Pat, Put) /b/ (Bat, tuBe) /m/ (Mat, froM)
	#VISEME_RR = 8,		# /r/ (Red, fRom)
	#VISEME_SS = 9,		# /s/ (Sir, See) /z/ (aS, hiS)
	#VISEME_TH = 10,		# /th/ (THink, THat)
	#VISEME_U = 11,		# /ou/ (tOO, feW)
	#VISEME_AA = 12,		# /A:/ (cAr, Art)
	#VISEME_KK = 13,		# /k/ (Call, weeK) /g/ (Gas, aGo)
	#VISEME_NN = 14,		# /n/ (Not, aNd) /l/ (Lot, chiLd)
	
	add_setting_group("lipsync_visemes", "Visemes")
	
	# Add the visemes to the settings UI for debug.
	for vis in range(Visemes.VISEME.COUNT):
		var name = viseme_names[vis]
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
	var viseme_shapes = get_global_mod_data("VisemeBlendShapes")
	var blendshapes =  get_global_mod_data("BlendShapes")
	var model : Node3D = get_model()
	
	#if len(blendshapes.keys()) == 0:
	#	return
		
	var anim_player : AnimationPlayer = model.find_child("AnimationPlayer", false, false)

	# Can't continue if there's no animation player.
	if not anim_player:
		return

	var anim_list : PackedStringArray = anim_player.get_animation_list()

	for vis in range(Visemes.VISEME.COUNT):
		var viseme_value = clampf(engine.visemes[vis] * 5, -1.0, 1.0)
		var name = viseme_names[vis]
		var vrm_blendshape = vrm_mapping[vis]
		
		var progressbar : ProgressBar = viseme_progressbars[name]
		progressbar.value = viseme_value

		# Silent is irrelevant.
		if vis == 0:
			continue
			
		#if vrm_blendshape in anim_list:
			#viseme_shapes[vrm_blendshape] = viseme_value
		#else:
			# MediaPipe blendshapes?
		blendshapes = _conv_blendshape_to_mediapipe(name, viseme_value, blendshapes)
		

func _conv_blendshape_to_mediapipe(name, value, blendshapes):
	#print("Converting")
	#if engine.current_energy_sum > 0.0:
	blendshapes["jawOpen"] = clampf(engine.current_energy_sum / 50.0, -1.0, 1.0)
	if name == viseme_names[Visemes.VISEME.VISEME_CH]:
		#_set_val(blendshapes, "jawOpen", value)
		_set_val(blendshapes, "mouthFunnel", value * 1.2)
		_set_val(blendshapes, "mouthShrugUpper", value * 1.0)
	elif name == viseme_names[Visemes.VISEME.VISEME_DD] \
		or name == viseme_names[Visemes.VISEME.VISEME_TH]:
		#_set_val(blendshapes, "jawOpen", value)
		pass
	elif name == viseme_names[Visemes.VISEME.VISEME_E]:
		#_set_val(blendshapes, "jawOpen", value * 0.5)
		_set_val(blendshapes, "mouthStretchLeft", value)
		_set_val(blendshapes, "mouthStretchRight", value)
	elif name == viseme_names[Visemes.VISEME.VISEME_I]:
		#_set_val(blendshapes, "jawOpen", value * 0.5)
		_set_val(blendshapes, "mouthStretchLeft", value)
		_set_val(blendshapes, "mouthStretchRight", value)
	elif name == viseme_names[Visemes.VISEME.VISEME_AA]:
		pass
		#_set_val(blendshapes, "jawOpen", value * 1.3)
		#_set_val(blendshapes, "jawOpen", value)
	elif name == viseme_names[Visemes.VISEME.VISEME_U]:
		#_set_val(blendshapes, "jawOpen", value * 0.2)
		_set_val(blendshapes, "mouthFunnel", value)
		_set_val(blendshapes, "mouthPucker", value * 0.5)
	elif name == viseme_names[Visemes.VISEME.VISEME_O]:
		_set_val(blendshapes, "mouthFunnel", value * 1.2)
		_set_val(blendshapes, "mouthPucker", value * 1.2)
		_set_val(blendshapes, "mouthPressLeft", value * 1.2)
		_set_val(blendshapes, "mouthPressRight", value * 1.2)
	elif name == viseme_names[Visemes.VISEME.VISEME_RR]:
		#_set_val(blendshapes, "jawOpen", value * 0.2)
		_set_val(blendshapes, "mouthFunnel", value * 1.6)
		_set_val(blendshapes, "mouthPucker", value * 1.5)
	elif name == viseme_names[Visemes.VISEME.VISEME_NN]:
		#_set_val(blendshapes, "jawOpen", value * 0.2)
		_set_val(blendshapes, "mouthFunnel", value * 1.4)
		_set_val(blendshapes, "mouthPucker", value * 0.5)
	elif name == viseme_names[Visemes.VISEME.VISEME_SS]:
		#_set_val(blendshapes, "jawOpen", value * 0.1)
		_set_val(blendshapes, "mouthStretchLeft", value * 1.2)
		_set_val(blendshapes, "mouthStretchRight", value * 1.2)
	elif name == viseme_names[Visemes.VISEME.VISEME_KK]:
		pass
		#_set_val(blendshapes, "jawOpen", value * 0.3)
	elif name == viseme_names[Visemes.VISEME.VISEME_FF]:
		#_set_val(blendshapes, "jawOpen", value * 0.1)
		_set_val(blendshapes, "mouthFunnel", value)
	
	return blendshapes

func _set_val(collection, key, new):
	if not collection.has(key):
		collection[key] = new
	var existing = collection[key]
	if existing + new == 0:
		return 0
	var avg = new #existing + new / 2
	collection[key] = avg
