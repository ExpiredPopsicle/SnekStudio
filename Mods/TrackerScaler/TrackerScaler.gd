extends Mod_Base

# FIXME: This is getting all messed up because PoseIK seems to mess with the
# trackers. :c

var tracker_scale: float = 1.0
var should_use_automatic_scale: bool = true
var show_debug_trackers: bool = false

func _ready() -> void:
	add_tracked_setting("tracker_scale", "Scale", { "min": 0.0, "max": 100.0 });
	add_tracked_setting("should_use_automatic_scale", "Use automatic height scale");
	add_tracked_setting("show_debug_trackers", "Show debug trackers")

func _process(_delta: float) -> void:
	
	var tracker_scale_to_use: float = tracker_scale
	var model_height_scale: float = get_model_height_scale()
	if should_use_automatic_scale:
		tracker_scale_to_use *= model_height_scale
	
	var trackers: Dictionary = get_global_mod_data("trackers")
	for tracker_name: String in ["head", "hand_left", "hand_right" ]:
		var tracker = trackers[tracker_name]
		tracker.transform.origin *= tracker_scale_to_use
	for finger_name: String in trackers["finger_positions"]:
		trackers["finger_positions"][finger_name] *= tracker_scale_to_use

	$DebugHead.global_transform = trackers["head"].transform
	$DebugLeftHand.global_transform = trackers["hand_left"].transform
	$DebugRightHand.global_transform = trackers["hand_right"].transform

	# Scale the debug objects based on the height of the model.
	var scaling_basis: Basis = Basis.from_scale(Vector3(model_height_scale, model_height_scale, model_height_scale))
	$DebugHead.global_transform.basis *= scaling_basis
	$DebugLeftHand.global_transform.basis *= scaling_basis
	$DebugRightHand.global_transform.basis *= scaling_basis

	# Update visibility.
	$DebugLeftHand.visible = show_debug_trackers
	$DebugRightHand.visible = show_debug_trackers
	$DebugHead.visible = show_debug_trackers
