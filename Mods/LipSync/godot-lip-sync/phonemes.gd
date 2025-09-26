class_name Phonemes

## Table of phonemes used in the detection of visemes
enum PHONEME {
	## Voiceless postalveolar affricate [tS]
	## CHeck, CHoose, beaCH, marCH
	PHONEME_TS = 0,

	## Voiced postalveolar affricate [dZ]
	## Job, aGe, maJor, Joy, Jump
	PHONEME_DZ = 1,

	## Voiceless postalveolar fricative [S]
	## SHe, puSH, SHeep
	PHONEME_SH = 2,

	## Voiceless alveolar plosive [t]
	## Take, haT, sTew
	PHONEME_T = 3,

	## Voiced alveolar plosive [d]
	## Day, haD, Dig
	PHONEME_D = 4,

	## Close-mid front unrounded vowel [e]
	## Ever, bEd
	PHONEME_E = 5,

	## Voiceless labiodental fricative [f]
	## Fan, Five
	PHONEME_F = 6,

	## Voiced labiodental fricative [v]
	## VafIx, offIce, kItn, Vest
	PHONEME_V = 7,

	## Near-close front unrounded vowel [I]
	## 
	PHONEME_I = 8,

	## Open-mid back rounded vowel [O]
	## Otter, stOp, nOt
	PHONEME_O = 9,

	## Voiceless bilabial plosive [p]
	## Pat, Put, Pack
	PHONEME_P = 10,

	## Voiced bilabial plosive [b]
	## Bat, tuBe, Bed
	PHONEME_B = 11,

	## Bilabial nasal [m]
	## Mat, froM, Mouse
	PHONEME_M = 12,

	## Alveolar trill [r]
	## Red, fRom, Ram
	PHONEME_R = 13,

	## Voiceless alveolar fricative [s]
	## Sir, See, Seem
	PHONEME_S = 14,

	## Voiced alveolar fricative [z]
	## aS, hiS, Zoo
	PHONEME_Z = 15,

	## Voiceless dental fricative [T]
	## THink, THat, THin
	PHONEME_TH = 16,

	## Close back rounded vowel [u]
	## tOO, feW, bOOm
	PHONEME_OU = 17,

	## Open back unrounded vowel [A]
	## cAr, Art, fAther
	PHONEME_A = 18,

	## Voiceless velar plosive [k]
	## Call, weeK, sCat
	PHONEME_K = 19,

	## Voiced velar plosive [g]
	## Gas, aGo, Game
	PHONEME_G = 20,

	## Alveolar nasal [n]
	## Not, aNd, Nap
	PHONEME_N = 21,

	## Alveolar lateral approximant [l]
	## Lot, chiLd, Lay
	PHONEME_L = 22,

	## Count of phonemes
	COUNT = 23
}

