extends Mod_Base

var max_yaw : float = 60.0
var max_pitch : float = 45.0
var mirror_yaw : bool = false
var mirror_pitch : bool = false

var _target_screen_origin: Vector2
var _target_screen_size: Vector2

var screen_info: Array = []
var screens_list: Array = []
var selected_screen_index : Array = []
var prev_selected_screen_index : Array = []

func _ready():
	add_tracked_setting("max_yaw", "Max Yaw (left/right) (deg)", { "min": 1.0, "max": 360.0 })
	add_tracked_setting("max_pitch", "Max Pitch (up/down) (deg)", { "min": 1.0, "max": 360.0 })
	add_tracked_setting("mirror_yaw", "Mirror Yaw (left/right)")
	add_tracked_setting("mirror_pitch", "Mirror Pitch (up/down)")

	for i in DisplayServer.get_screen_count():
		var s_pos: Vector2i = DisplayServer.screen_get_position(i)
		var s_size: Vector2i = DisplayServer.screen_get_size(i)
		screens_list.append({ "index": i, "x": s_pos.x, "pos": s_pos, "size": s_size })

	# Sort screens by X position (Left -> Right)
	screens_list.sort_custom(func(a, b): return a["x"] < b["x"])

	for s in screens_list:
		screen_info.append("%s %s" % [s["pos"], s["size"]])

	add_tracked_setting("selected_screen_index", "Screens to track (left to right, choose multiple)", 
		{ 
			"allow_multiple": true,
			"values": screen_info
		})

	var widget : ItemList = _settings_widgets_by_setting_name["selected_screen_index"]
	widget.custom_minimum_size.y = 100.0
	update_settings_ui()

func _change_screens(screen_info_texts: Array):
	# godot... Why not consts for these? #2411
	var min_x : int = (1 << 31) - 1
	var min_y : int = (1 << 31) - 1
	var max_x : int = -(1 << 31)
	var max_y : int = -(1 << 31)

	for text_id in screen_info_texts:
		var idx = screen_info.find(text_id)
		var s = screens_list[idx]

		# Update Minimums (Top-Left origin)
		if s["pos"].x < min_x: min_x = s["pos"].x
		if s["pos"].y < min_y: min_y = s["pos"].y

		# Update Maximums (Bottom-Right edge)
		var right_edge = s["pos"].x + s["size"].x
		var bottom_edge = s["pos"].y + s["size"].y

		if right_edge > max_x: max_x = right_edge
		if bottom_edge > max_y: max_y = bottom_edge
		
	# Total size is the difference between the furthest point and the origin
	_target_screen_origin = Vector2(min_x, min_y)
	_target_screen_size = Vector2(max_x - min_x, max_y - min_y)

func _change_screen_center():
	if screens_list.is_empty(): return
	var center_array_index: int = floor(screens_list.size() / 2.0)
	var screen_info_text = screen_info[center_array_index]

	selected_screen_index = [screen_info_text]
	prev_selected_screen_index = selected_screen_index

	_change_screens(selected_screen_index)
	update_settings_ui()
	
func _process(delta: float) -> void:
	if len(selected_screen_index) == 0:
		_change_screen_center()
	elif selected_screen_index != prev_selected_screen_index and len(selected_screen_index) > 0:
		_change_screens(selected_screen_index)
		prev_selected_screen_index = selected_screen_index

	var mouse_pos_in_window : Vector2 = get_viewport().get_mouse_position()
	var window_position : Vector2 = get_viewport().get_window().position
	var global_pos : Vector2 = window_position + mouse_pos_in_window

	# Calculate position relative to the Bounding Box of all selected screens
	var relative_pos: Vector2 = global_pos - _target_screen_origin

	# Normalize based on the Total Size of valid screens
	var pos_normalized: Vector2 = Vector2(
		-(relative_pos.x / _target_screen_size.x - 0.5),
		-(relative_pos.y / _target_screen_size.y - 0.5)
	)
	pos_normalized.x = clamp(pos_normalized.x, -0.5, 0.5)
	pos_normalized.y = clamp(pos_normalized.y, -0.5, 0.5)

	if mirror_yaw:
		pos_normalized.x = -pos_normalized.x
	if mirror_pitch:
		pos_normalized.y = -pos_normalized.y

	var tracker_dict : Dictionary = get_global_mod_data("trackers")
	var head = tracker_dict["head"]
	if not head["active"]:
		return

	var trans : Transform3D = head["transform"]

	var angle_yaw : float = pos_normalized.x * 2 * deg_to_rad(max_yaw)
	var angle_pitch : float = -pos_normalized.y * 2 * deg_to_rad(max_pitch)

	trans.basis = Basis.from_euler(Vector3(angle_pitch, angle_yaw, 0.0), 2)
	tracker_dict["head"]["transform"] = trans

func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray = []
	if check_mod_dependency("Mod_PoseIK", false):
		errors.append("No PoseIK mod, or MouseHeadTracker is not above PoseIK.")
	if check_mod_dependency("Mod_MediaPipeController", true):
		errors.append("No MediaPipeController, or MouseHeadTracker is not below it.")
	return errors
