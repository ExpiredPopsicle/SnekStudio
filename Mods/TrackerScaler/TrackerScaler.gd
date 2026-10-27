extends Mod_Base

# FIXME: This is getting all messed up because PoseIK seems to mess with the
# trackers. :c

var tracker_scale: float = 1.0

func _ready() -> void:
	add_tracked_setting("tracker_scale", "Scale", { "min": 0.0, "max": 100.0 });

func _process(delta: float) -> void:
	var trackers: Dictionary = get_global_mod_data("trackers")
	for tracker_name: String in ["head", "hand_left", "hand_right" ]:
		var tracker = trackers[tracker_name]
		tracker.transform.origin *= tracker_scale
	for finger_name: String in trackers["finger_positions"]:
		trackers["finger_positions"][finger_name] *= tracker_scale

	$DebugHead.global_transform = trackers["head"].transform
	$DebugLeftHand.global_transform = trackers["hand_left"].transform
	$DebugRightHand.global_transform = trackers["hand_right"].transform

	#print($DebugRightHand.global_transform.origin)
