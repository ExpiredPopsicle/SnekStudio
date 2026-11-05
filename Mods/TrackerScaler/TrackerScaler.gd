extends Mod_Base

# FIXME: This is getting all messed up because PoseIK seems to mess with the
# trackers. :c

var tracker_scale: float = 1.0
var should_use_automatic_scale: bool = true
var show_debug_trackers: bool = false

## Scale the feature points of the hands within the hand's coordinate space.
var hand_point_scale: float = 1.0

func _ready() -> void:
	add_tracked_setting("tracker_scale", "Scale", { "min": 0.0, "max": 100.0 });
	add_tracked_setting("should_use_automatic_scale", "Use automatic height scale");
	add_tracked_setting("show_debug_trackers", "Show debug trackers")
	add_tracked_setting("hand_point_scale", "Hand feature point scale", { "min": 0.0, "max": 100.0, "step": 0.01 })

func _process(_delta: float) -> void:
	
	var tracker_scale_to_use: float = tracker_scale
	var model_height_scale: float = get_model_height_scale()
	if should_use_automatic_scale:
		tracker_scale_to_use *= model_height_scale
	
	var trackers: Dictionary = get_global_mod_data("trackers")
	for tracker_name: String in ["head", "hand_left", "hand_right" ]:
		if trackers.has(tracker_name):
			var tracker: Dictionary = trackers[tracker_name]
			tracker.transform.origin *= tracker_scale_to_use

	if trackers.has("finger_positions"):
		for side in ["left", "right"]:
			for point_name: String in trackers["finger_positions"]:

				if not point_name.begins_with(side):
					continue

				trackers["finger_positions"][point_name] *= tracker_scale_to_use
				
				var position_in_hand_space: Vector3 = \
					trackers["finger_positions"][point_name] - trackers["finger_positions"][side + "_wrist"]
				position_in_hand_space *= hand_point_scale
				trackers["finger_positions"][point_name] = \
					position_in_hand_space + trackers["finger_positions"][side + "_wrist"]

	if trackers.has("head"):
		$DebugHead.global_transform = trackers["head"].transform
	if trackers.has("hand_left"):
		$DebugLeftHand.global_transform = trackers["hand_left"].transform
	if trackers.has("hand_right"):
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
