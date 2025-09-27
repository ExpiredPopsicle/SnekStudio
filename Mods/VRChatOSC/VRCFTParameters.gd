class_name ParameterMappings
extends Node

enum COMBINATION_TYPE {
	RANGE = 1,
	COPY = 2,
	AVERAGE = 3,
	WEIGHTED = 4
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

static var legacy_parameter_mapping : Dictionary = {
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
}
