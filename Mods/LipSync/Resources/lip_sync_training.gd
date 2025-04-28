@tool
class_name LipSyncTraining
extends Resource


# Maximum deviation
const MAX_DEVIATION := 1000.0


## Dictionary of phonemes
## 
## This dictionary maps a phoneme to an array of speech fingerprints.
@export var training : Dictionary

## Dictionary of weights
##
## This dictionary maps visemes to weights (deviation radius)
@export var weights : Dictionary


func _init():
	training = {}
	weights = {}


## Calculate a match between the fingerprint and phonemes
func match_phonemes(fingerprint: LipSyncFingerprint, matches: Array):
	# Ensure the matches array is the correct size
	matches.resize(Phonemes.PHONEME.COUNT)

	# Iterate over all phonemes
	for phoneme in Phonemes.PHONEME.COUNT:
		# If no training set for phoneme then ignore
		if not phoneme in training:
			matches[phoneme] = MAX_DEVIATION
			continue

		# Find minimum deviation in phomene patters
		var min_deviation := MAX_DEVIATION
		for pattern in training[phoneme]:
			var deviation = LipSyncFingerprint.deviation(fingerprint, pattern)
			min_deviation = min(deviation, min_deviation)

		# Update match
		matches[phoneme] = min_deviation


## Calculate a match between the fingerprint and visemes
func match_visemes(fingerprint: LipSyncFingerprint, matches: Array):
	# Ensure the matches array is the correct size
	matches.resize(Visemes.VISEME.COUNT)

	# Iterate over all visemes
	for viseme in Visemes.VISEME.COUNT:
		var min_deviation := MAX_DEVIATION

		# Iterate over all associated phonemes
		for phoneme in Visemes.VISEME_PHONEME_MAP[viseme]:
			# Skip phonemes without training data
			if not phoneme in training:
				continue

			# Update minimum deviation
			for pattern in training[phoneme]:
				var deviation = LipSyncFingerprint.deviation(fingerprint, pattern)
				min_deviation = min(deviation, min_deviation)

		# Get the viseme weight
		var weight := 0.001
		if viseme in weights:
			weight = weights[viseme]

		# Convert to weight
		weight = remap(min_deviation, 0.0, weight, 1.0, 0.0)
		weight = clamp(weight, 0.0, 1.0)

		# Save in the results
		matches[viseme] = weight
