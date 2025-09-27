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
	"BrowInnerUp": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "BrowInnerUpLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "BrowInnerUpRight",
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
	"CheekPuffSuckLeft": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "CheekPuffLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "CheekSuckLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"CheekPuffSuckRight": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "CheekPuffRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "CheekSuckRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"CheekPuffSuck": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [
					{
						"shape": "CheekPuffRight"
					},
					{
						"shape": "CheekPuffLeft"
					}
				],
				"negative": [
					{
						"shape": "CheekSuckRight"
					},
					{
						"shape": "CheekSuckLeft"
					}
				]
			}
		]
	},
	"CheekSuck": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "CheekSuckLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "CheekSuckRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthUpperX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"MouthLowerX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"LipSuckUpper": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipSuckUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipSuckUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipSuckLower": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipSuckLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipSuckLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipSuck": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipSuckUpper",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipSuckLower",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipFunnelUpper": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipFunnelUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipFunnelLower": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipFunnelLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipFunnel": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipFunnelUpper",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelLower",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipPuckerUpper": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipPuckerUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipPuckerUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipPuckerLower": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipPuckerLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipPuckerLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipPuckerRight": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipPuckerUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipPuckerLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipPuckerLeft": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipPuckerUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipPuckerLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipPucker": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipPuckerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipPuckerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipSuckFunnelUpper": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "LipSuckUpper",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelUpper",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipSuckFunnelLower": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "LipSuckLower",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelLower",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipSuckFunnelLowerLeft": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "LipSuckLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipSuckFunnelLowerRight": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "LipSuckLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipSuckFunnelUpperLeft": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "LipSuckUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"LipSuckFunnelUpperRight": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "LipSuckUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthTightenerStretch": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "MouthTightener",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "MouthStretch",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthTightenerStretchLeft": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "MouthTightenerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "MouthStretchLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthTightenerStretchRight": {
		"combination_type": COMBINATION_TYPE.SUBTRACT,
		"combination_shapes": [
			{
				"shape": "MouthTightenerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "MouthStretchRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthCornerYLeft": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthCornerSlantLeft",
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
	"MouthCornerYRight": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthCornerSlantRight",
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
	"MouthCornerY": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "MouthCornerYLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "MouthCornerYRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
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
	"TongueX": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "TongueRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "TongueLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"TongueY": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "TongueUp",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "TongueDown",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"TongueArchY": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "TongueCurlUp",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "TongueBendDown",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			}
		]
	},
	"TongueShape": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "TongueFlat",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "TongueSquish",
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
	"BrowDownRight": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "BrowLowererRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.75
			},
			{
				"shape": "BrowPinchRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.25
			},
		]
	},
	"BrowDownLeft": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "BrowLowererLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.75
			},
			{
				"shape": "BrowPinchLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.25
			},
		]
	},
	"MouthSmileRight": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "MouthCornerPullRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.8
			},
			{
				"shape": "MouthCornerSlantRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.2
			},
		]
	},
	"MouthSmileLeft": {
		"combination_type": COMBINATION_TYPE.WEIGHTED,
		"combination_shapes": [
			{
				"shape": "MouthCornerPullLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.8
			},
			{
				"shape": "MouthCornerSlantLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 0.2
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
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "MouthRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "MouthLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
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
	"MouthTightener": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "MouthTightenerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
			},
			{
				"shape": "MouthTightenerLeft",
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
}
# These are mostly taken from the mapper here: 
# https://github.com/benaclejames/VRCFaceTracking/blob/a4a66fcd7ee776b1740512a481aecac686224af0/VRCFaceTracking.Core/Params/Expressions/Legacy/Lip/UnifiedSRanMapper.cs
static var legacy_parameter_mapping : Dictionary = {
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
	"MouthUpperOverturn": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipFunnelUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthLowerOverturn": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipFunnelLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipFunnelLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthPout": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipPuckerUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipPuckerUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipPuckerLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipPuckerLowerRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
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
	"CheekPuffLeft": {
		"combination_type": COMBINATION_TYPE.WEIGHTED_ADD,
		"combination_shapes": [
			{
				"shape": "CheekPuffLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 1.0
			}
		]
	},
	"CheekSuck": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "CheekSuckLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "CheekSuckRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthUpperInside": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipSuckUpperLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipSuckUpperRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			}
		]
	},
	"MouthLowerInside": {
		"combination_type": COMBINATION_TYPE.AVERAGE,
		"combination_shapes": [
			{
				"shape": "LipSuckLowerLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED
			},
			{
				"shape": "LipSuckLowerRight",
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
	"TongueLongStep1": {
		"combination_type": COMBINATION_TYPE.WEIGHTED_ADD,
		"combination_shapes": [
			{
				"shape": "TongueOut",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"weight": 2.0
			}
		]
	},
	
	# -------- START SIMPLIFIED LEGACY PARAMETERS --------
	# These are done at the end of the mapping for the
	# sole purpose of simplification of legacy parameters.
	# -------- START SIMPLIFIED LEGACY PARAMETERS --------
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
			},
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
			},
		]
	},
	"PuffSuckRight": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "CheekPuffRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "CheekSuck",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"PuffSuckLeft": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "CheekPuffLeft",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "CheekSuck",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"PuffSuck": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": true,
				"positive": [
					{
						"shape": "CheekPuffLeft"
					},
					{
						"shape": "CheekPuffRight"
					}
				],
				"negative": [
					{
						"shape": "CheekSuck"
					}
				]
			},
		]
	},
	"JawOpenSuck": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "JawOpen",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "CheekSuck",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
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
	"JawOpenPuffRight": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "JawOpen",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "CheekPuffRight",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.NEGATIVE
			},
		]
	},
	"JawOpenPuffLeft": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{
				"shape": "JawOpen",
				"shape_type": SHAPE_KEY_TYPE.UNIFIED,
				"direction": DIRECTION.POSITIVE
			},
			{
				"shape": "CheekPuffLeft",
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
	"MouthUpperUpRightSuck": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpRight" },
			{ "shape": "CheekSuck", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpLeftUpperInside": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpLeft" },
			{ "shape": "MouthUpperInside", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthUpperUpLeftPuffLeft": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpLeft" },
			{ "shape": "CheekPuffLeft", "direction": ParameterMappings.DIRECTION.NEGATIVE }
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
	"MouthUpperUpLeftSuck": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthUpperUpLeft" },
			{ "shape": "CheekSuck", "direction": ParameterMappings.DIRECTION.NEGATIVE }
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
	"MouthUpperUpPuff": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "CheekPuffLeft" }, { "shape": "CheekPuffRight" } ]
			}
		]
	},
	"MouthUpperUpPuffLeft": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "CheekPuffLeft" } ]
			}
		]
	},
	"MouthUpperUpPuffRight": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthUpperUpLeft" }, { "shape": "MouthUpperUpRight" } ],
				"negative": [ { "shape": "CheekPuffRight" } ]
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
	"MouthLowerDownRightPuffRight": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownRight" },
			{ "shape": "CheekPuffRight", "direction": ParameterMappings.DIRECTION.NEGATIVE }
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
	"MouthLowerDownRightSuck": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownRight" },
			{ "shape": "CheekSuck", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownLeftLowerInside": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownLeft" },
			{ "shape": "MouthLowerInside", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"MouthLowerDownLeftPuffLeft": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownLeft" },
			{ "shape": "CheekPuffLeft", "direction": ParameterMappings.DIRECTION.NEGATIVE }
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
	"MouthLowerDownLeftSuck": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "MouthLowerDownLeft" },
			{ "shape": "CheekSuck", "direction": ParameterMappings.DIRECTION.NEGATIVE }
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
	"MouthLowerDownPuff": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "CheekPuffLeft" }, { "shape": "CheekPuffRight" } ]
			}
		]
	},
	"MouthLowerDownPuffLeft": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "CheekPuffLeft" } ]
			}
		]
	},
	"MouthLowerDownPuffRight": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "CheekPuffRight" } ]
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
	"MouthLowerDownSuck": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "MouthLowerDownLeft" }, { "shape": "MouthLowerDownRight" } ],
				"negative": [ { "shape": "CheekSuck" } ]
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
	"PuffRightUpperOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "CheekPuffRight" },
			{ "shape": "MouthUpperOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"PuffRightLowerOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "CheekPuffRight" },
			{ "shape": "MouthLowerOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"PuffRightOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": true,
				"positive": [ { "shape": "CheekPuffRight" } ],
				"negative": [ { "shape": "MouthUpperOverturn" }, { "shape": "MouthLowerOverturn" } ]
			}
		]
	},
	"PuffLeftUpperOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "CheekPuffLeft" },
			{ "shape": "MouthUpperOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"PuffLeftLowerOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE,
		"combination_shapes": [
			{ "shape": "CheekPuffLeft" },
			{ "shape": "MouthLowerOverturn", "direction": ParameterMappings.DIRECTION.NEGATIVE }
		]
	},
	"PuffLeftOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": true,
				"positive": [ { "shape": "CheekPuffLeft" } ],
				"negative": [ { "shape": "MouthUpperOverturn" }, { "shape": "MouthLowerOverturn" } ]
			}
		]
	},
	"PuffUpperOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "CheekPuffRight" }, { "shape": "CheekPuffLeft" } ],
				"negative": [ { "shape": "MouthUpperOverturn" } ]
			}
		]
	},
	"PuffLowerOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": false,
				"positive": [ { "shape": "CheekPuffRight" }, { "shape": "CheekPuffLeft" } ],
				"negative": [ { "shape": "MouthLowerOverturn" } ]
			}
		]
	},
	"PuffOverturn": {
		"combination_type": COMBINATION_TYPE.RANGE_AVERAGE,
		"combination_shapes": [
			{
				"use_max_value": true,
				"positive": [ { "shape": "CheekPuffRight" }, { "shape": "CheekPuffLeft" } ],
				"negative": [ { "shape": "MouthUpperOverturn" }, { "shape": "MouthLowerOverturn" } ]
			}
		]
	}
}
