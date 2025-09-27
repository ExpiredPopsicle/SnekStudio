extends Mod_Base

var yaw_offset : float = 0.0;
var pitch_offset : float = 0.0; 

func _ready() -> void:
	add_tracked_setting("yaw_offset", "Yaw Offset", { "min" : -180.0, "max" : 180.0 })
	add_tracked_setting("pitch_offset", "Pitch Offset", { "min" : -180.0, "max" : 180.0 })

func _process(delta: float) -> void:

	var rotation_transform : Transform3D = Transform3D(
		Basis.from_euler(Vector3(pitch_offset * PI/180.0, yaw_offset * PI/180.0, 0.0)),
		Vector3(0.0, 0.0, 0.0))

	var trackers : Dictionary = get_global_mod_data("trackers")
	if "head" in trackers:
		if trackers["head"]["active"]:
			trackers["head"]["transform"] = rotation_transform * trackers["head"]["transform"]
			$Head.global_transform = trackers["head"]["transform"]

	if "hand_left" in trackers:
		if trackers["hand_left"]["active"]:
			trackers["hand_left"]["transform"] = rotation_transform * trackers["hand_left"]["transform"]
			$Hand_Left.global_transform = trackers["hand_left"]["transform"]
	if "hand_right" in trackers:
		if trackers["hand_right"]["active"]:
			trackers["hand_right"]["transform"] = rotation_transform * trackers["hand_right"]["transform"]
			$Hand_Right.global_transform = trackers["hand_right"]["transform"]

	#if "finger_positions" in trackers:
	#	for k in trackers["finger_positions"].keys():
	#		trackers["finger_positions"][k] = rotation_transform.basis * trackers["finger_positions"][k]
		
