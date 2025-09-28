extends Node
class_name VRCParams

var _params : Array[VRCParam] = []
var _has_changed_avi : bool = false
var _avatar_id : String
var _raw_params : Dictionary
var _binary_params : Dictionary
var _float_params : Dictionary

func reset():
	_params = []
	_has_changed_avi = false
	_avatar_id = ""
	_raw_params = {}
	_float_params = {}
	_binary_params = {}

func initialize(raw_avatar_params : Dictionary, avatar_id : String, has_changed_avi : bool):
	_raw_params = raw_avatar_params
	_avatar_id = avatar_id
	_has_changed_avi = has_changed_avi
	
	if raw_avatar_params.has("FT"):
		raw_avatar_params = raw_avatar_params["FT"]["CONTENTS"]
		_raw_params = raw_avatar_params
	
	if raw_avatar_params.has("v2"):
		raw_avatar_params = raw_avatar_params["v2"]["CONTENTS"]
		_raw_params = raw_avatar_params

	# Only if we are wanting to update/change param values do we progress here.
	var param_names = raw_avatar_params.keys()
	for key in param_names:
		# Verify this is a type/value parameter.
		if not "TYPE" in raw_avatar_params[key] or not "VALUE" in raw_avatar_params[key]:
			continue
		# FIXME: Len of Value can actually be >0, or == 0.
		var param = VRCParam.new(
				raw_avatar_params[key]["FULL_PATH"],
				key, 
				raw_avatar_params[key]["TYPE"], 
				avatar_id, 
				raw_avatar_params[key]["VALUE"][0]
			)
		if param.param_binary:
			if not _binary_params.has(param.binary_key):
				_binary_params[param.binary_key] = []
			_binary_params[param.binary_key].append(param)
		elif param.param_float:
			assert(not _float_params.has(param.key), "Already existing float parameter with key %s" % param.key)
			_float_params[param.key] = param
		_params.append(
			param
		)
	pass
	
func valid_params_from_dict(dict : Dictionary) -> Array[String]:
	var keys = dict.keys()
	var valid = _params.filter(func (p : VRCParam): return p.binary_key in keys)
	var shapes : Array[String] = []
	for valid_param in valid:
		shapes.append(valid_param.binary_key)
	return shapes

## Updates a particular key to the supplied value.
## This func takes care of the exchange between binary/float parameters in VRC tracking.
func update_value(key : String, value):
	
	# TODO: Add cache for binary_key -> VRCParam. Make sure to reset in .reset method.
	var params : Array[VRCParam] = _params.filter(func (p : VRCParam): return p.binary_key == key)
	if len(params) == 0:
		return

	var param : VRCParam = params[0]
	
	if param.is_binary():
		# This is actually an Array[VRCParam] but ... Godot...
		var param_group : Array = _binary_params[param.binary_key]

		# Convert key to binary.
		var is_neg = value < 0.0

		# Important to normalize to positive.
		var val_pos = absf(value)

		# Make sure we take care of neg.
		var neg_params : Array = param_group.filter(func (p : VRCParam): return p.binary_exponent == 0)
		if len(neg_params) == 1:
			neg_params[0].update_value(is_neg)
		

		param_group.sort_custom(
			func (a : VRCParam, b : VRCParam):
				return a.binary_exponent < b.binary_exponent
		)
		
		# 1. Determine N (number of magnitude bits)
		var N : int = len(param_group.filter(func (p : VRCParam): return p.binary_exponent != 0))

		# 2. Convert val_pos (0.0-1.0 float) to an integer representation (0 to 2^N - 1)
		var integer_representation : int
		if N == 0:
			integer_representation = 0
		else:
			# Scale val_pos to the range [0, 2^N]. Example N=3, range [0,8].
			var scaled_value : float = val_pos * pow(2.0, float(N)) 
			# Take the floor to get the discrete step.
			integer_representation = floori(scaled_value)
			# Clamp the integer_representation to be within [0, 2^N - 1].
			# (e.g. if N=3, max_val is 7).
			var max_representable_int_val : int = int(pow(2.0, float(N))) - 1
			integer_representation = mini(integer_representation, max_representable_int_val)
			integer_representation = maxi(integer_representation, 0)

		# 3. Set bits for each magnitude parameter
		var num = 0
		for exp_param : VRCParam in param_group:
			if exp_param.binary_exponent == 0:
				continue
			var bit : int = integer_representation & (1 << num)
			exp_param.update_value(not bit == 0)
			num += 1
		pass
	elif param.is_float():
		param.update_value(value)

## Get all parameters that have had values change since last use.
## Caller should reset is_dirty flag on the parameter after sending.
func get_dirty() -> Array[VRCParam]:
	return _params.filter(func (p : VRCParam): return p.is_dirty)

func get_all() -> Array[VRCParam]:
	return _params

func has(shape_key : String) -> bool:
	var params : Array[VRCParam] = _params.filter(func (p : VRCParam): return p.binary_key == shape_key)
	return len(params) > 0
