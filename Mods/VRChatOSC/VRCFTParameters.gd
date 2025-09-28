class_name ParameterMappings
extends Node

enum COMBINATION_TYPE {
	RANGE = 1,
	COPY = 2,
	AVERAGE = 3,
	WEIGHTED = 4,
	RANGE_AVERAGE = 5,
	MAX = 6,
	MIN = 7,
	SUBTRACT = 8,
	WEIGHTED_ADD = 9
}
enum SHAPE_KEY_TYPE {
	MEDIAPIPE = 1,
	UNIFIED = 2
}
enum DIRECTION { 
	POSITIVE = 1,
	NEGATIVE = 2
}

static var simplified_parameter_mapping : Dictionary = {
	"MouthFrown": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "MouthFrownRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "MouthFrownLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"MouthSmile": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "MouthSmileRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "MouthSmileLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"MouthStretch": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "MouthStretchRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "MouthStretchLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"EyeWide": {
		"combination_type": COMBINATION_TYPE.MAX,
		"combination_shapes": [
			{
				"shape": "EyeWideLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "EyeWideRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"EyeSquint": {
		"combination_type": COMBINATION_TYPE.MAX,
		"combination_shapes": [
			{
				"shape": "EyeSquintLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "EyeSquintRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"EyesSquint": {
		"combination_type": COMBINATION_TYPE.MAX,
		"combination_shapes": [
			{
				"shape": "EyeSquintLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "EyeSquintRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
		"BrowUpRight": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "BrowOuterUpRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.6
			},
			{
				"shape": "BrowInnerUpRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.4
			},
		]
	},
	"BrowUpLeft": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "BrowOuterUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.6
			},
			{
				"shape": "BrowInnerUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.4
			},
		]
	},
	"BrowUp": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "BrowUpRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "BrowUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"BrowDown": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "BrowDownRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "BrowDownLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"BrowOuterUp": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "BrowOuterUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "BrowOuterUpRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"BrowExpressionRight": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [
					{
						"shape": "BrowInnerUpRight"
					},
					{
						"shape": "BrowOuterUpRight"
					}
				],
				"negative": [
					{
						"shape": "BrowDownRight"
					}
				]
			}
		]
	},
	"BrowExpressionLeft": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [
					{
						"shape": "BrowInnerUpLeft"
					},
					{
						"shape": "BrowOuterUpLeft"
					}
				],
				"negative": [
					{
						"shape": "BrowDownLeft"
					}
				]
			}
		]
	},
	"BrowExpression": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "BrowExpressionRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "BrowExpressionLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"CheekSquint": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "CheekSquintLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "CheekSquintRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthUpperX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthUpperUpRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthUpperUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"MouthUpperUp": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "MouthUpperUpRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.5
			},
			{
				"shape": "MouthUpperUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.5
			},
		]
	},
	"MouthLowerDown": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "MouthLowerDownRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.5
			},
			{
				"shape": "MouthLowerDownLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.5
			},
		]
	},
	"MouthOpen": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "MouthUpperUpRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.25
			},
			{
				"shape": "MouthUpperUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.25
			},
			{
				"shape": "MouthLowerDownRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.25
			},
			{
				"shape": "MouthLowerDownLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.25
			},
		]
	},
	"MouthX": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": true,
				"positive": [{
					"shape": "MouthUpperRight",
				}],
				"negative": [{
					"shape": "MouthLowerRight"
				}]
			}
		]
	},
	"JawX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "JawRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "JawLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"JawZ": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "JawForward",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "JawBackward",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"EyeLidRight": {
		"combination_type": COMBINATION_TYPE.COPY,
		"combination_shapes": [
			{
				"shape": "EyeClosedRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"inverse": true
			},
			{
				"shape": "EyeLidRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"EyeLidLeft": {
		"combination_type": COMBINATION_TYPE.COPY,
		"combination_shapes": [
			{
				"shape": "EyeClosedLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"inverse": true
			},
			{
				"shape": "EyeLidLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"EyeLid": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "EyeLidLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "EyeLidRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"MouthPress": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "MouthPressRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "MouthPressLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"MouthDimple": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "MouthDimpleRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "MouthDimpleLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"NoseSneer": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "NoseSneerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "NoseSneerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"EyeRightX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "EyeLookOutRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "EyeLookInRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"RightEyeX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "EyeLookOutRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "EyeLookInRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"EyeRightY": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "EyeLookUpRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "EyeLookDownRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"EyeLeftX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "EyeLookInLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "EyeLookOutLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"LeftEyeX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "EyeLookInLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "EyeLookOutLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"EyeLeftY": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "EyeLookUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "EyeLookDownLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"EyeX": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "EyeRightX",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "EyeLeftX",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
		]
	},
	"EyeY": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "EyeRightY",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "EyeLeftY",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
		]
	},
	"EyesY": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "EyeRightY",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "EyeLeftY",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
		]
	},
}
# These are mostly taken from the mapper here: 
# https://github.com/benaclejames/VRCFaceTracking/blob/a4a66fcd7ee776b1740512a481aecac686224af0/VRCFaceTracking.Core/Params/Expressions/Legacy/Lip/UnifiedSRanMapper.cs
static var legacy_parameter_mapping : Dictionary = {
	"SmileFrownRight": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthSmileRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthFrownRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"SmileFrownLeft": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthSmileLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthFrownLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"SmileFrown": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "SmileFrownRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "SmileFrownLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"SmileSadRight": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthSmileRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthSadRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"SmileSadLeft": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthSmileLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthSadLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"SmileSad": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "SmileSadRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "SmileSadLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthApeShape": {
		"combination_type": COMBINATION_TYPE.WEIGHTED_ADD,
		"combination_shapes": [
			{
				"shape": "MouthClosed",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 1.0
			}
		]
	},
	"MouthSmileRight": {
		"combination_type": COMBINATION_TYPE.MAX,
		"combination_shapes": [
			{
				"shape": "MouthSmileRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "MouthDimpleRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthSmileLeft": {
		"combination_type": COMBINATION_TYPE.MAX,
		"combination_shapes": [
			{
				"shape": "MouthSmileLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "MouthDimpleLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthLowerOverlay": {
		"combination_type": COMBINATION_TYPE.WEIGHTED_ADD,
		"combination_shapes": [
			{
				"shape": "MouthRaiserLower",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 1.0
			}
		]
	},
	
	# -------- START SIMPLIFIED LEGACY PARAMETERS --------
	# These are done at the end of the mapping for the
	# sole purpose of simplification of legacy parameters.
	# -------- START SIMPLIFIED LEGACY PARAMETERS --------
	"JawOpenSuck": {
		"combination_type": COMBINATION_TYPE.COPY,
		"combination_shapes": [
			{
				"shape": "JawOpen",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "JawOpenSuck",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
		]
	},
	"JawOpenApe": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "JawOpen",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthApeShape",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"JawOpenForward": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "JawOpen",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "JawForward",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"JawOpenOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "JawOpen",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthLowerOverlay",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"JawOpenPuff": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [
					{
						# Defaults to shape type unified.
						"shape": "JawOpen"
					}
				],
				"negative": [
					{
						"shape": "CheekPuffLeft"
					},
					{
						"shape": "CheekPuffRight"
					}
				]
			},
		]
	},
	"MouthUpperUpRightUpperInside": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpRight" },
			{ "shape": "MouthUpperInside", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpRightPuffRight": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpRight" },
			{ "shape": "CheekPuffRight", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpRightApe": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpRight" },
			{ "shape": "MouthApeShape", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpRightPout": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpRight" },
			{ "shape": "MouthPout", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpRightOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpRight" },
			{ "shape": "MouthLowerOverlay", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpLeftUpperInside": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpLeft" },
			{ "shape": "MouthUpperInside", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpLeftApe": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpLeft" },
			{ "shape": "MouthApeShape", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpLeftPout": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpLeft" },
			{ "shape": "MouthPout", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpLeftOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpLeft" },
			{ "shape": "MouthLowerOverlay", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpUpperInside": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "MouthUpperInside" } ]
			}
		]
	},
	"MouthUpperUpInside": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": true,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "MouthUpperInside" }, { "shape": "MouthLowerInside" } ]
			}
		]
	},
	"MouthUpperUpApe": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "MouthApeShape" } ]
			}
		]
	},
	"MouthUpperUpPout": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "MouthPout" } ]
			}
		]
	},
	"MouthUpperUpOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "MouthLowerOverlay" } ]
			}
		]
	},
	"MouthUpperUpSuck": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "CheekSuck" } ]
			}
		]
	},
	"MouthLowerDownRightLowerInside": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownRight" },
			{ "shape": "MouthLowerInside", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownRightApe": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownRight" },
			{ "shape": "MouthApeShape", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownRightPout": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownRight" },
			{ "shape": "MouthPout", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownRightOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownRight" },
			{ "shape": "MouthLowerOverlay", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownLeftLowerInside": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownLeft" },
			{ "shape": "MouthLowerInside", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownLeftApe": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownLeft" },
			{ "shape": "MouthApeShape", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownLeftPout": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownLeft" },
			{ "shape": "MouthPout", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownLeftOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownLeft" },
			{ "shape": "MouthLowerOverlay", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownLowerInside": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "MouthLowerInside" } ]
			}
		]
	},
	"MouthLowerDownInside": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": true,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "MouthUpperInside" }, { "shape": "MouthLowerInside" } ]
			}
		]
	},
	"MouthLowerDownApe": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "MouthApeShape" } ]
			}
		]
	},
	"MouthLowerDownPout": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "MouthPout" } ]
			}
		]
	},
	"MouthLowerDownOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "MouthLowerOverlay" } ]
			}
		]
	},
	"MouthUpperInsideOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperInside" },
			{ "shape": "MouthUpperOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerInsideOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerInside" },
			{ "shape": "MouthLowerOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileRightUpperOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileRight" },
			{ "shape": "MouthUpperOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileRightLowerOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileRight" },
			{ "shape": "MouthLowerOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileRightOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthSmileRight" } ],
				"negative": [ { "shape": "MouthUpperOverturn" }, { "shape": "MouthLowerOverturn" } ]
			}
		]
	},
	"SmileRightApe": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileRight" },
			{ "shape": "MouthApeShape", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileRightOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileRight" },
			{ "shape": "MouthLowerOverlay", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileRightPout": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileRight" },
			{ "shape": "MouthPout", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileLeftUpperOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileLeft" },
			{ "shape": "MouthUpperOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileLeftLowerOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileLeft" },
			{ "shape": "MouthLowerOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileLeftOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthSmileLeft" } ],
				"negative": [ { "shape": "MouthUpperOverturn" }, { "shape": "MouthLowerOverturn" } ]
			}
		]
	},
	"SmileLeftApe": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileLeft" },
			{ "shape": "MouthApeShape", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileLeftOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileLeft" },
			{ "shape": "MouthLowerOverlay", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileLeftPout": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthSmileLeft" },
			{ "shape": "MouthPout", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"SmileUpperOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthSmileLeft" }, { "shape": "MouthSmileRight" } ],
				"negative": [ { "shape": "MouthUpperOverturn" } ]
			}
		]
	},
	"SmileLowerOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthSmileLeft" }, { "shape": "MouthSmileRight" } ],
				"negative": [ { "shape": "MouthLowerOverturn" } ]
			}
		]
	},
	"SmileOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthSmileLeft" }, { "shape": "MouthSmileRight" } ],
				"negative": [ { "shape": "MouthUpperOverturn" }, { "shape": "MouthLowerOverturn" } ]
			}
		]
	},
	"SmileApe": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthSmileLeft" }, { "shape": "MouthSmileRight" } ],
				"negative": [ { "shape": "MouthApeShape" } ]
			}
		]
	},
	"SmileOverlay": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthSmileLeft" }, { "shape": "MouthSmileRight" } ],
				"negative": [ { "shape": "MouthLowerOverlay" } ]
			}
		]
	},
	"SmilePout": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthSmileLeft" }, { "shape": "MouthSmileRight" } ],
				"negative": [ { "shape": "MouthPout" } ]
			}
		]
	},
}
