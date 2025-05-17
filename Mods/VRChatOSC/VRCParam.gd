extends Node
class_name VRCParam

var key : String
var type : String
var value : Variant
var full_path : String
var avatar_id : String
var param_binary : bool = false
var param_float : bool = false
var binary_key : String
var binary_exponent : int
var is_dirty : bool = false

func _init(param_path : String, pkey : String, ptype : String, pavatar_id : String, pvalue) -> void:
	full_path = param_path
	key = pkey
	type = ptype
	value = pvalue
	avatar_id = pavatar_id
	param_binary = is_binary()
	param_float = is_float()
	if param_binary:
		if key.ends_with("Negative"):
			binary_key = key.replace("Negative", "")
			# Negative exponent is "0".
			binary_exponent = 0
		else:
			if key.ends_with("16") or key.ends_with("32") or key.ends_with("64"):
				binary_exponent = int(key.substr(len(key) - 2))
				binary_key = key.substr(0, len(key) - 2)
			else:
				binary_exponent = int(key.substr(len(key) - 1))
				binary_key = key.substr(0, len(key) - 1)
	else:
		# Helps with searching.
		binary_key = key

func is_binary() -> bool:
	var key_name = key.ends_with("Negative") \
					or key.ends_with("1") \
					or key.ends_with("2") \
					or key.ends_with("4") \
					or key.ends_with("8") \
					or key.ends_with("16") \
					or key.ends_with("32") \
					or key.ends_with("64") 
	var val_type = type == "T"
	return key_name and val_type

func is_float() -> bool:
	return type == "f"

func update_value(new_value : Variant) -> void:
	value = new_value
	is_dirty = true

func reset_dirty() -> void:
	is_dirty = false

func to_osc() -> PackedByteArray:
	return PackedByteArray()
