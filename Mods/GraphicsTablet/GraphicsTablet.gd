extends Mod_Base

func _process(delta: float) -> void:

	var mouse_pos_in_window : Vector2 = get_viewport().get_mouse_position()
	var window_position : Vector2 = get_viewport().get_window().position

	var pos : Vector2 = window_position + mouse_pos_in_window

	# FIXME: Add mapping values.
	var pos_normalized : Vector2 = Vector2(
		-(pos.x / 1920.0 - 0.5),
		-(pos.y / 1080.0 - 0.5))

	pos_normalized.x = clamp(pos_normalized.x, -0.5, 0.5)
	pos_normalized.y = clamp(pos_normalized.y, -0.5, 0.5)

	%Pen_Transform.transform.origin.x = pos_normalized.x * 0.4064
	%Pen_Transform.transform.origin.z = pos_normalized.y * 0.2286

	var tracker_dict : Dictionary = get_global_mod_data("trackers")


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



	for side in ["right"]:

		# Don't crash without tracking data.
		if not tracker_dict.has("hand_" + side):
			continue

		if not tracker_dict["hand_" + side]["active"]:

			var hand_tracker : Node3D = %Hand

			tracker_dict["hand_" + side]["active"] = true
			tracker_dict["hand_" + side]["transform"] = hand_tracker.global_transform

			for tracker_name in mediapipe_hand_landmark_names:
				var tracker_node : Node3D = hand_tracker.find_child(tracker_name)
				if tracker_node:
					tracker_dict["finger_positions"][side + "_" + tracker_name] = tracker_node.global_transform.origin
