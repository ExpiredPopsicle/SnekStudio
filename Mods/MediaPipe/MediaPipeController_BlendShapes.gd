extends Object

static func apply_rest_shapes(
	shape_dict_last_frame : Dictionary,
	delta : float, speed : float) -> Dictionary:

	var new_dict = {}

	var keys = shape_dict_last_frame.keys()
	for key in keys:
		new_dict[key] = clamp(
			lerp(
				shape_dict_last_frame[key],
				0.0, speed * delta), 0.0, 1.0)

	return new_dict
