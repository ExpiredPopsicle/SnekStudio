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
	
func _ready():
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
	#print(engine.visemes[Visemes.VISEME.VISEME_CH])
#	pass
	_update_viseme_progressbars()

func _update_viseme_progressbars():
	var blend_shapes : Dictionary = get_global_mod_data("BlendShapes")
	var model : Node3D = get_model()
	
	var anim_player : AnimationPlayer = model.find_child("AnimationPlayer", false, false)

	# Can't continue if there's no animation player.
	if not anim_player:
		return

	var anim_list : PackedStringArray = anim_player.get_animation_list()
	var anim_root = anim_player.get_node(anim_player.root_node)
	
	for vis in range(Visemes.VISEME.COUNT):
		var viseme_value =  engine.visemes[vis]
		var name = viseme_names[vis]
		var progressbar : ProgressBar = viseme_progressbars[name]
		progressbar.value = viseme_value
		
