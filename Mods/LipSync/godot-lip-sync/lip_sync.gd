# Author: Malcolm Nixon https://github.com/Malcolmnixon
# GitHub Project Page: To be released as a addon for the Godot Engine
# License: MIT
# Slight edits by Elliesaur to integrate mediapipe/basic vrm shapes.

class_name LipSync
extends Node


##  Overview
##
## This module provides lip-sync services by classifying mouth shapes using a 
## spectrum analyzer listening to the microphone.
##
##
## Node Usage
## 
## This node constructs the necessary audio components to detect visemes when
## processed. It does require the project have the Audio Input Enabled option
## turned on.
##
## This module outputs the following fields:
##  - energy_raw[] for instantaneous energy (tuning/debugging)
##  - fingerprint[] for audio fingerprint (tuning/debugging)
##  - visemes[] for viseme weights


# List of standard visemes
enum VISEME {
	VISEME_SILENT = 0,	# Mouth closed (silent)
	VISEME_CH = 1,		# /tS/ (CHeck, CHoose) /dZ/ (Job, aGe) /S/ (She, puSh)
	VISEME_DD = 2,		# /t/ (Take, haT) /d/ (Day, haD)
	VISEME_E = 3,		# /e/ (Ever, bEd)
	VISEME_FF = 4,		# /f/ (Fan) /v/ (Van)
	VISEME_I = 5,		# /ih/ (fIx, offIce)
	VISEME_O = 6,		# /o/ (Otter, stOp)
	VISEME_PP = 7,		# /p/ (Pat, Put) /b/ (Bat, tuBe) /m/ (Mat, froM)
	VISEME_RR = 8,		# /r/ (Red, fRom)
	VISEME_SS = 9,		# /s/ (Sir, See) /z/ (aS, hiS)
	VISEME_TH = 10,		# /th/ (THink, THat)
	VISEME_U = 11,		# /ou/ (tOO, feW)
	VISEME_AA = 12,		# /A:/ (cAr, Art)
	VISEME_KK = 13,		# /k/ (Call, weeK) /g/ (Gas, aGo)
	VISEME_NN = 14,		# /n/ (Not, aNd) /l/ (Lot, chiLd)
	COUNT = 15
}

# Detection band ranges
const BANDS_RANGE = [
	[140.0, 20.0],
	[168.0, 37.0],
	[210.0, 47.0],
	[262.0, 56.0],
	[322.0, 64.0],
	[389.0, 70.0],
	[462.0, 76.0],
	[541.0, 82.0],
	[626.0, 87.0],
	[716.0, 92.0],
	[811.0, 97.0],
	[911.0, 102.0],
	[1014.0, 106.0],
	[1123.0, 110.0],
	[1235.0, 114.0],
	[1351.0, 118.0],
	[1471.0, 121.0],
	[1595.0, 125.0],
	[1722.0, 129.0],
	[1853.0, 132.0]
]

# Detection bands count
const BANDS_COUNT = 20

# Table of reference fingerprints for the different mouth-shape sounds. Note that
# if the frequency bands or filtering is modified then these reference sounds will
# need to be updated. Additionally it is possible to add as many reference 
# audio-fingerprints to each mouth-shape, and doing so may increase the accuracy
# of the lip-sync results at the cost of increased computation.
const REFERENCES = {
	VISEME.VISEME_SILENT: [
		# Silence
		[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	],
	
	VISEME.VISEME_CH: [
		# /tS/ (CHeck, CHoose)
		[0.331393, 0.33275, 0.253321, 0.130307, 0.079765, 0.080146, 0.093726, 0.071365, 0.036568, 0.029173, 0.073779, 0.234833, 0.629822, 1.369062, 2.931183, 4.353563, 4.009357, 2.444066, 1.503539, 1.012282],
		# /dZ/ (Job, aGe)
		[1.280537, 0.903482, 0.848113, 1.116231, 1.461342, 1.157044, 0.819549, 0.246756, 0.082959, 0.076089, 0.061447, 0.049661, 0.096743, 0.242846, 0.51475, 0.846728, 1.505489, 3.43426, 3.34717, 1.908804],
		# /S/ (She, puSh)
		[0.306909, 0.276335, 0.228509, 0.138123, 0.103924, 0.065274, 0.042298, 0.042707, 0.032633, 0.046343, 0.118309, 0.29523, 0.647315, 1.181237, 2.239751, 3.771025, 4.004829, 2.82239, 2.037923, 1.598937],
	],
	
	# Can't detect stop sound at this point
	VISEME.VISEME_DD: [
	#	# /t/ (Take, haT)
	#	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	#	# /d/ (Day, haD)
	#	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	#],
	# changed to TH - for the time being as it produces more accurate results
		# /th/ (THink, THat)
		[2.110933, 2.316846, 2.515543, 2.492, 2.550038, 1.938401, 1.603606, 1.257377, 0.957248, 0.498176, 0.269357, 0.213727, 0.167422, 0.125585, 0.13604, 0.206383, 0.228375, 0.160131, 0.131596, 0.121217],
	],

	VISEME.VISEME_E: [
		# /e/ (Ever, bEd)
		[0.759317, 1.03422, 0.993064, 0.840904, 0.724346, 0.829064, 1.178726, 1.818102, 1.757318, 1.174653, 0.698386, 0.563963, 0.50052, 0.409161, 0.372759, 0.425037, 0.611813, 1.080413, 1.9324, 2.295833],
	],

	VISEME.VISEME_FF: [
		# /f/ (Fan)
		[0.812064, 1.068569, 0.662637, 0.401738, 0.2697, 0.243979, 0.228582, 0.182503, 0.128521, 0.129925, 0.108127, 0.088296, 0.122193, 0.193164, 0.32572, 0.402012, 0.416264, 0.35249, 0.25197, 0.278215],
		# /v/ (Van)
		[2.048738, 1.875497, 1.906306, 2.055243, 1.48738, 1.31985, 1.089788, 0.625834, 0.296596, 0.257242, 0.401387, 0.588103, 0.787247, 0.998962, 1.129882, 0.87166, 0.538438, 0.475295, 0.574971, 0.67158],
	],
	
	VISEME.VISEME_I: [
		# /ih/ (fIx, offIce)
		[3.819456, 1.490971, 1.559814, 0.817711, 1.240422, 2.512404, 2.841696, 1.249588, 0.376978, 0.164269, 0.1208, 0.128241, 0.122829, 0.142754, 0.170965, 0.127468, 0.120068, 0.24908, 0.727598, 2.016886],
	],

	VISEME.VISEME_O: [
		# /o/ (Otter, stOp)
		[2.299085, 1.516347, 1.27705, 1.585337, 1.527834, 2.200922, 2.558533, 1.976737, 1.760438, 1.70541, 0.99135, 0.332096, 0.06122, 0.040424, 0.03447, 0.02233, 0.025097, 0.026078, 0.028166, 0.031076],
	],
	
	VISEME.VISEME_PP: [
		# /p/ (Pat, Put) - Can't detect stop sound at this point
		#[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		# /b/ (Bat, tuBe) - Can't detect stop sound at this point
		#[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
		# /m/ (Mat, froM)
		#[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	],
	
	VISEME.VISEME_RR: [
		# /r/ (Red, fRom)
		[0.546634, 1.349722, 1.393094, 1.101319, 1.243814, 1.727409, 1.319761, 0.493505, 0.234735, 0.244634, 0.198879, 0.537947, 1.287981, 1.187151, 0.472414, 0.243829, 0.461804, 0.584654, 0.319658, 0.051056],
	],
	
	VISEME.VISEME_SS: [
		# /s/ (Sir, See)
		[2.364879, 3.019137, 3.172685, 2.719487, 2.243495, 1.795036, 1.443101, 0.641021, 0.373922, 0.379378, 0.266498, 0.246805, 0.139123, 0.1446, 0.20929, 0.217226, 0.193001, 0.204947, 0.142112, 0.084259],
		# /z/ (aS, hiS)
		[2.680416, 2.469168, 2.508934, 2.095277, 1.830716, 1.302396, 1.010842, 0.723001, 0.362613, 0.251272, 0.16882, 0.151334, 0.208299, 0.451061, 1.291996, 1.501316, 0.73635, 0.133891, 0.07655, 0.045748],
	],

	VISEME.VISEME_TH: [
		# /th/ (THink, THat)
		[2.110933, 2.316846, 2.515543, 2.492, 2.550038, 1.938401, 1.603606, 1.257377, 0.957248, 0.498176, 0.269357, 0.213727, 0.167422, 0.125585, 0.13604, 0.206383, 0.228375, 0.160131, 0.131596, 0.121217],
	],
	
	VISEME.VISEME_U: [
		# /ou/ (tOO, feW)
		[1.866078, 1.950338, 2.858065, 3.592716, 3.167674, 2.273636, 0.621558, 0.407428, 0.417302, 0.553176, 0.823899, 0.899631, 0.373637, 0.038068, 0.020733, 0.023822, 0.024902, 0.026612, 0.031865, 0.028861],
	],
	
	VISEME.VISEME_AA: [
		# /A:/ (cAr, Art)
		[1.340902, 0.968838, 0.824241, 0.972814, 0.856258, 0.736672, 0.740674, 1.191061, 1.678072, 1.782172, 1.389946, 1.680797, 2.374798, 2.006197, 0.750535, 0.311128, 0.173483, 0.091624, 0.068027, 0.061763],
	],
	
	# Can't detect stop sound at this point
	VISEME.VISEME_KK: [
	#	# /k/ (Call, weeK)
	#	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	#	# /g/ (Gas, aGo)
	#	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
	#],
	# changed to AA - for the time being as it produces more accurate results
		# /A:/ (cAr, Art)
		[1.340902, 0.968838, 0.824241, 0.972814, 0.856258, 0.736672, 0.740674, 1.191061, 1.678072, 1.782172, 1.389946, 1.680797, 2.374798, 2.006197, 0.750535, 0.311128, 0.173483, 0.091624, 0.068027, 0.061763],
	],
	
	VISEME.VISEME_NN: [
		# /n/ (Not, aNd)
		[2.510794, 2.901495, 3.21757, 3.113629, 2.037741, 0.945989, 0.471688, 0.444989, 0.240321, 0.185946, 0.118187, 0.089931, 0.058493, 0.129972, 0.443778, 0.618475, 0.612963, 0.646815, 0.650293, 0.56093],
		# /l/ (Lot, chiLd)
		[2.188797, 1.760084, 1.65888, 1.951933, 1.95294, 2.637529, 2.507263, 0.83378, 0.502384, 0.445373, 0.296525, 0.641325, 1.188579, 0.950362, 0.270992, 0.059314, 0.046548, 0.037362, 0.032174, 0.037855],
	],
}

# Bands default array
const BANDS_DEF = [
	0.0, 0.0, 0.0, 0.0, 0.0, 
	0.0, 0.0, 0.0, 0.0, 0.0, 
	0.0, 0.0, 0.0, 0.0, 0.0, 
	0.0, 0.0, 0.0, 0.0, 0.0 ]
const VISEMES_DEF = [ 
	0.0, 0.0, 0.0, 0.0, 0.0, 
	0.0, 0.0, 0.0, 0.0, 0.0, 
	0.0, 0.0, 0.0, 0.0, 0.0 ]


## Audio bus name
@export var audio_bus_name := "Mic"

## Add microphone to bus
@export var add_microphone := true

## Mute the audio
@export var mute_audio := true

## Audio-Match precision
@export var precision := 0.3

## Slew rate
@export var slew := 20.0

## Silence threshold
@export var silence := 0.15

@export var viseme_weight_multiplier : float = 4.0

# Raw energy for each band (0..1)
var energy_raw := BANDS_DEF.duplicate()

# Audio fingerprint
var fingerprint := BANDS_DEF.duplicate()

# Visemes
var visemes := VISEMES_DEF.duplicate()

var current_energy_average := 0.0

var current_energy_sum := 0.0

var prev_energy_sum := 0.0

# Audio stream player
var _player : AudioStreamPlayer

# Spectrum analyzer effect instance
var _effect : AudioEffectSpectrumAnalyzerInstance

const VISEME_NAMES_LOWER : Array[String] = [
	"silent",
	"ch",
	"dd",
	"e",
	"ff",
	"i",
	"o",
	"pp",
	"rr",
	"ss",
	"th",
	"u",
	"aa",
	"kk",
	"nn"
]

const VISEME_NAMES : Array[String] = [
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
const BASIC_VRM_MAPPING = [
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

var viseme_to_mediapipe_map = {
	"ch": {
		"mouthPucker": 0.4,
		"mouthFunnel": 0.1,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.1, "mouthLowerDownRight": 0.1,
		"jawOpen": 0.15
	},
	"dd": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.0, "mouthLowerDownRight": 0.0,
		"jawOpen": 0.1
	},
	"th": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.0, "mouthLowerDownRight": 0.0,
		"jawOpen": 0.1
	},
 	"nn": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.0, "mouthLowerDownRight": 0.0,
		"jawOpen": 0.0
	},
	"ss": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.3, "mouthRight": 0.3,
		"mouthLowerDownLeft": 0.0, "mouthLowerDownRight": 0.0,
		"jawOpen": 0.05
	},
	 "kk": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.0, "mouthLowerDownRight": 0.0,
		"jawOpen": 0.15
	},
	 "ff": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.1, "mouthRight": 0.1,
		# Might need 'mouthShrugLower' if available, or simulate by slightly lowering lip
		"mouthLowerDownLeft": 0.1, "mouthLowerDownRight": 0.1,
		"jawOpen": 0.1
	},
	"rr": {
		"mouthPucker": 0.1,
		"mouthFunnel": 0.2,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.0, "mouthLowerDownRight": 0.0,
		"jawOpen": 0.1
	},
	"e": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.7, "mouthRight": 0.7,
		"mouthLowerDownLeft": 0.1, "mouthLowerDownRight": 0.1,
		"jawOpen": 0.1
	},
	"i": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.4, "mouthRight": 0.4,
		"mouthLowerDownLeft": 0.1, "mouthLowerDownRight": 0.1,
		"jawOpen": 0.2
	},
	"aa": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.2, "mouthLowerDownRight": 0.2,
		"jawOpen": 0.8
	},
	"u": {
		"mouthPucker": 0.9,
		"mouthFunnel": 0.1,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.0, "mouthLowerDownRight": 0.0,
		"jawOpen": 0.1
	},
	"o": {
		"mouthPucker": 0.1,
		"mouthFunnel": 0.8,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.1, "mouthLowerDownRight": 0.1,
	 	"jawOpen": 0.3
	},
	"silent": {
		"mouthPucker": 0.0,
		"mouthFunnel": 0.0,
		"mouthLeft": 0.0, "mouthRight": 0.0,
		"mouthLowerDownLeft": 0.0, "mouthLowerDownRight": 0.0,
		"jawOpen": 0.0
	}
}

var all_mediapipe_keys : Array = [
	"mouthPucker",
	"mouthFunnel",
	"mouthLeft",
	"mouthRight",
	"mouthLowerDownLeft",
	"mouthLowerDownRight",
	"jawOpen"
]

var current_mediapipe_values : Dictionary = {}
var current_basic_vrm_values : Dictionary = {}

# Sort class for sorting [shape,distance] array by distance
class DistanceSorter:
	static func sort_ascending(a: Array, b: Array) -> bool:
		return true if a[1] < b[1] else false


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Verify audio input is enabled
	if not ProjectSettings.get_setting("audio/driver/enable_input"):
		printerr("LipSync: Audio input not enabled in project")
		return

	# Get and configure the audio bus
	var bus := _get_or_create_audio_bus(audio_bus_name)
	if mute_audio:
		AudioServer.set_bus_mute(bus, true)

	# Get and configure the spectrum analyzer
	var idx := _get_or_create_spectrum_analyzer(bus)
	var spectrum_cfg := AudioServer.get_bus_effect(bus, idx) as AudioEffectSpectrumAnalyzer
	spectrum_cfg.buffer_length = 512.0 / AudioServer.get_mix_rate()
	spectrum_cfg.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_512

	# Get the spectrum analyzer instance
	_effect = AudioServer.get_bus_effect_instance(bus, idx)

	# Create the audio stream player
	if add_microphone:
		_player = AudioStreamPlayer.new()
		_player.set_name("LipSyncInput")
		_player.stream = AudioStreamMicrophone.new()
		_player.bus = audio_bus_name
		add_child(_player)
	
		# Start playing the microphone into the audio bus
		_player.play()

# Process the lip-sync audio
func _process(_delta: float) -> void:
	# Calculate absolute energy
	var energy := BANDS_DEF.duplicate()
	var energy_sum := 0.0
	for i in BANDS_COUNT:
		var center_hz: float = BANDS_RANGE[i][0]
		var width_hz: float = BANDS_RANGE[i][1]
		var magnitude := _effect.get_magnitude_for_frequency_range(center_hz - width_hz, center_hz + width_hz, 0)
		var e := magnitude.length() * center_hz
		energy[i] = e
		energy_sum += e

	# Calculate fingerprint
	var energy_avg := energy_sum / BANDS_COUNT
	var energy_scale := 0.0 if energy_avg <= silence else 1.0 / energy_avg
	for i in BANDS_COUNT:
		fingerprint[i] = energy[i] * energy_scale
		
	var slew_scale = slew * _delta
	current_energy_average = energy_avg
	var c_energy_sum = 0.0 if energy_avg <= silence else energy_sum
	current_energy_sum = lerp(prev_energy_sum, c_energy_sum, slew_scale)
	
	# Construct new visemes scores
	var scores := VISEMES_DEF.duplicate()
	var score_sum := precision
	for shape in REFERENCES:
		# Calculate the shortest distance from the fingerprint to the mouth-shape
		var distance := 1000.0
		for reference in REFERENCES[shape]:
			distance = min(distance, _fingerprint_distance(fingerprint, reference))

		# Save the distance
		var score = 1.0 / max(0.01, distance)
		scores[shape] = score
		score_sum += score

	# Update viseme scores
	var score_scale = 1.0 / score_sum
	
	for i in VISEME.COUNT:
		var old_weight: float = visemes[i]
		var new_weight: float = scores[i] * score_scale
		visemes[i] = lerp(old_weight, new_weight, slew_scale)
		if BASIC_VRM_MAPPING[i] == "":
			continue
		current_basic_vrm_values[BASIC_VRM_MAPPING[i]] = visemes[i]
		
	_convert_visemes_to_mediapipe_shapes()

	prev_energy_sum = current_energy_sum

func _convert_visemes_to_mediapipe_shapes():
	for mp_key in all_mediapipe_keys:
		current_mediapipe_values[mp_key] = 0.0

	for i in range(VISEME.COUNT):
		var viseme_weight: float = visemes[i]

		# Skip if this viseme has negligible weight
		if viseme_weight < 0.001:
			continue

		var viseme_name: String = VISEME_NAMES_LOWER[i]

		if not viseme_to_mediapipe_map.has(viseme_name):
			continue
			
		viseme_weight *= viseme_weight_multiplier
		
		var target_shapes_for_this_viseme: Dictionary = viseme_to_mediapipe_map[viseme_name]

		for mediapipe_shape_name in target_shapes_for_this_viseme:
			# Check if this MediaPipe shape is one we are tracking (it should be if all_mediapipe_keys is correct)
			if current_mediapipe_values.has(mediapipe_shape_name):
				var target_value: float = target_shapes_for_this_viseme[mediapipe_shape_name]
				# Add the contribution: (viseme's weight) * (target value for this shape in this viseme)
				current_mediapipe_values[mediapipe_shape_name] += viseme_weight * target_value
				current_mediapipe_values[mediapipe_shape_name] = clampf(current_mediapipe_values[mediapipe_shape_name], -1.0, 1.0)
			
# Get or create an audio bus with the specified name
static func _get_or_create_audio_bus(name: String) -> int:
	# Find the audio bus
	var bus := AudioServer.get_bus_index(name)
	if bus >= 0:
		print("LipSync: Found existing audio bus ", bus, " (", name, ")")
		return bus

	# Create new bus	
	bus = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus, name)

	# Return bus
	print("LipSync: Created new audio bus ", bus, " (", name, ")")
	return bus


# Get or create a spectrum analyzer on the specified audio bus
static func _get_or_create_spectrum_analyzer(bus: int) -> int:
	# Search through existing effects
	for i in AudioServer.get_bus_effect_count(bus):
		var effect := AudioServer.get_bus_effect(bus, i) as AudioEffectSpectrumAnalyzer
		if effect:
			print("LipSync: Found existing spectrum analyzer effect ", bus, ":", i)
			return i

	# Create the spectrum analyzer
	var idx := AudioServer.get_bus_effect_count(bus)
	AudioServer.add_bus_effect(bus, AudioEffectSpectrumAnalyzer.new())

	# Return spectrum analyzer effect
	print("LipSync: Created new spectrum analyzer effect ", bus, ":", idx)
	return idx


# Calculate the distance between two fingerprints
static func _fingerprint_distance(a: Array, b: Array) -> float:
	# Calculate the sum-of-squares of the error between bins
	var distance := 0.0
	for i in BANDS_COUNT:
		var err: float = a[i] - b[i];
		distance += err * err

	# Return the distance (squared)
	return distance
