class_name LipSyncFingerprint


## Fingerprint frequency bands.
##
## Each entry is from-Hz, to-Hz, middle-Hz
const BANDS_RANGE := [
	[120.0, 180.0, 150.0],
	[122.0, 232.0, 177.0],
	[148.0, 290.0, 219.0],
	[186.0, 356.0, 271.0],
	[236.0, 426.0, 331.0],
	[292.0, 504.0, 398.0],
	[356.0, 586.0, 471.0],
	[428.0, 674.0, 551.0],
	[504.0, 766.0, 635.0],
	[586.0, 864.0, 725.0],
	[674.0, 966.0, 820.0],
	[766.0, 1072.0, 919.0],
	[864.0, 1182.0, 1023.0],
	[966.0, 1296.0, 1131.0],
	[1072.0, 1416.0, 1244.0],
	[1182.0, 1538.0, 1360.0],
	[1298.0, 1662.0, 1480.0],
	[1416.0, 1792.0, 1604.0],
	[1538.0, 1924.0, 1731.0],
	[1662.0, 4000.0, 2831.0],
]

## Count of frequency bands
const BANDS_COUNT := 20

## Average energy level for silence
const SILENCE := 0.1

## Fingerprint description
var description: String = ""

## Fingerprint values
var values: Array = [
	0.0, 0.0, 0.0, 0.0, 0.0,
	0.0, 0.0, 0.0, 0.0, 0.0,
	0.0, 0.0, 0.0, 0.0, 0.0,
	0.0, 0.0, 0.0, 0.0, 0.0]


## Populate this fingerprint from a spectrum analyzer instance
func populate(spectrum: AudioEffectSpectrumAnalyzerInstance):
	# Populate values with energy
	var energy_max := 0.0
	for i in BANDS_COUNT:
		var from_hz: float = BANDS_RANGE[i][0]
		var to_hz: float = BANDS_RANGE[i][1]
		var center_hz: float = BANDS_RANGE[i][2]
		var magnitude := spectrum.get_magnitude_for_frequency_range(from_hz, to_hz, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
		var e := magnitude.length() * center_hz
		values[i] = e
		energy_max = max(energy_max, e)

	# Calculate fingerprint
	var energy_scale := 0.0 if energy_max <= SILENCE else 1.0 / energy_max
	for i in BANDS_COUNT:
		values[i] *= energy_scale


## Calculate deviation between two fingerprints
static func deviation(a: LipSyncFingerprint, b: LipSyncFingerprint) -> float:
	# Calculate sum of squares of error
	var sum := 0.0
	for i in BANDS_COUNT:
		var delta: float = b.values[i] - a.values[i]
		sum += delta * delta
	
	# Return sum as deviation
	return sum
