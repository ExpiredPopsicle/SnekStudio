extends Mod_Base

var min_x: int = 0
var min_y: int = 0
var max_x: int = 1920
var max_y: int = 1080
var maintain_z_offset: bool = true
var z_offset: float = 0.4
var maintain_y_offset: bool = false
var y_offset: float = 1.0
var maintain_x_offset: bool = false
var x_offset: float = 0.0

var use_right_hand: bool = true
var use_left_hand: bool = false

func _ready() -> void:
	add_tracked_setting("min_x", "Left pixel position")
	add_tracked_setting("min_y", "Top pixel position")
	add_tracked_setting("max_x", "Right pixel position")
	add_tracked_setting("max_y", "Bottom pixel position")

	add_tracked_setting("use_right_hand", "Right hand")
	add_tracked_setting("use_left_hand", "Left hand")

	add_tracked_setting("maintain_z_offset", "Maintain Z offset from model")
	add_tracked_setting("z_offset", "Z offset", {"min" : -10, "max": 10, "step": 0.02})
	add_tracked_setting("maintain_y_offset", "Maintain Y offset from model")
	add_tracked_setting("y_offset", "Y offset", {"min" : -10, "max": 10, "step": 0.02})
	add_tracked_setting("maintain_x_offset", "Maintain X offset from model")
	add_tracked_setting("x_offset", "X offset", {"min" : -10, "max": 10, "step": 0.02})

func _process(delta: float) -> void:

	var model: Node3D = get_app().get_model()

	if maintain_z_offset:
		$Tablet.transform.origin.z = model.transform.origin.z + z_offset
	if maintain_y_offset:
		$Tablet.transform.origin.y = model.transform.origin.y + y_offset
	if maintain_x_offset:
		$Tablet.transform.origin.x = model.transform.origin.x + x_offset

	var mouse_pos_in_window : Vector2 = get_viewport().get_mouse_position()
	var window_position : Vector2 = get_viewport().get_window().position

	var pos : Vector2 = window_position + mouse_pos_in_window

	# FIXME: Add mapping values.
	var pos_normalized : Vector2 = Vector2(
		-((pos.x - min_x) / (max_x - min_x) - 0.5),
		-((pos.y - min_y) / (max_y - min_y) - 0.5))

	pos_normalized.x = clamp(pos_normalized.x, -0.5, 0.5)
	pos_normalized.y = clamp(pos_normalized.y, -0.5, 0.5)

	%Pen_Transform.transform.origin.x = pos_normalized.x * 0.4064
	%Pen_Transform.transform.origin.z = pos_normalized.y * 0.2286

	var tracker_dict : Dictionary = get_global_mod_data("trackers")

	%pen_left.visible = use_left_hand and tracker_dict["hand_left"]["active"] == false
	if use_left_hand:
		update_tracker("left", %Hand_left, tracker_dict)

	%pen_right.visible = use_right_hand and tracker_dict["hand_right"]["active"] == false
	if use_right_hand:
		update_tracker("right", %Hand_right, tracker_dict)

func update_tracker(side: String, hand_tracker: Node3D, tracker_dict: Dictionary):

	var mediapipe_hand_landmark_names : Array = [
		"wrist",

		"thumb_cmc", # carpometacarpal
		"thumb_mcp", # metacarpal
		"thumb_ip", # interphalangeal
		"thumb_tip", # tip

		"index_finger_mcp",
		"index_finger_pip", # proximal something something
		"index_finger_dip", # distal something something
		"index_finger_tip",

		"middle_finger_mcp",
		"middle_finger_pip",
		"middle_finger_dip",
		"middle_finger_tip",

		"ring_finger_mcp",
		"ring_finger_pip",
		"ring_finger_dip",
		"ring_finger_tip",

		"pinky_finger_mcp",
		"pinky_finger_pip",
		"pinky_finger_dip",
		"pinky_finger_tip",
	]

	if not tracker_dict["hand_" + side]["active"]:

		tracker_dict["hand_" + side]["active"] = true
		tracker_dict["hand_" + side]["transform"] = hand_tracker.global_transform

		for tracker_name in mediapipe_hand_landmark_names:
			var tracker_node : Node3D = hand_tracker.find_child(tracker_name)
			if tracker_node:
				tracker_dict["finger_positions"][side + "_" + tracker_name] = tracker_node.global_transform.origin
