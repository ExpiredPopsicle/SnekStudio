extends Mod_Base

@onready var left_hand_reference: Node3D = $LeftHandRestReference
@onready var right_hand_reference: Node3D = $RightHandRestReference

@onready var head_tacker: Node3D = $Head
@onready var left_hand_tacker: Node3D = $Hand_Left
@onready var right_hand_tacker: Node3D = $Hand_Right

var visible_trackers: bool = false
var arm_rest_angle: float = 69
var arm_reset_speed: float = 6.0
var arm_length_scale: float = 1.0

func _ready() -> void:
	add_tracked_setting("visible_trackers", "Visible rest position trackers")
	add_tracked_setting("arm_rest_angle", "Arm rest angle", { "min": 0.0, "max": 180.0 })
	add_tracked_setting("arm_reset_speed", "Arm reset speed", { "min": 0.0, "max": 50.0 })
	add_tracked_setting("arm_length_scale", "Arm length scale", { "min": 0.0, "max": 5.0, "step": 0.01 })
	update_settings_ui()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	left_hand_reference.visible = visible_trackers
	right_hand_reference.visible = visible_trackers
	_update_arm_rest_positions()

func scene_init() -> void:
	# Transfer rest position trackers to skeleton.
	var root = get_skeleton().get_parent()
	remove_child(left_hand_reference)
	remove_child(right_hand_reference)
	root.add_child(left_hand_reference)
	root.add_child(right_hand_reference)
	_update_arm_rest_positions()

func scene_shutdown() -> void:
	# Transfer position trackers back to us.
	var root = get_skeleton().get_parent()
	root.remove_child(left_hand_reference)
	root.remove_child(right_hand_reference)
	add_child(left_hand_reference)
	add_child(right_hand_reference)

func _update_single_arm_rest_position(side: String, rotation_axis: Vector3, rest_tracker: Node3D):
	var skel : Skeleton3D = get_skeleton()
	
	if skel:
		# Rotate the shoulder down so the arm is resting at a specific angle
		var shoulder_index = skel.find_bone(side + "Shoulder")
		var hand_index = skel.find_bone(side + "Hand")
		var shoulder_origin : Vector3 = skel.get_bone_global_rest(shoulder_index).origin
		var hand_origin : Vector3 = skel.get_bone_global_rest(hand_index).origin
		var rotation_basis = Basis(rotation_axis, deg_to_rad(arm_rest_angle))
		var new_offset : Vector3 = (hand_origin - shoulder_origin).rotated(
				rotation_axis, deg_to_rad(arm_rest_angle))
		rest_tracker.transform.origin = shoulder_origin + new_offset * arm_length_scale
		rest_tracker.transform.basis = rotation_basis

func _update_arm_rest_positions():
	_update_single_arm_rest_position("Left", Vector3(0.0, 0.0, -1.0), left_hand_reference)
	_update_single_arm_rest_position("Right", Vector3(0.0, 0.0, 1.0), right_hand_reference)

func _update_tracker(
	tracker_name: String, tracker_object: Node3D, reference_object: Node3D,
	delta: float):

	var trackers : Dictionary = get_global_mod_data("trackers")

	if trackers.has(tracker_name) and trackers[tracker_name]["active"]:
		# Tracker active. Copy data directly over.
		tracker_object.transform = trackers[tracker_name]["transform"]
	else:
		# Tracker inactive. Lerp back to rest.
		tracker_object.global_transform = tracker_object.global_transform.interpolate_with(
			reference_object.global_transform, arm_reset_speed * delta)

	# Copy from *our* proxy tracker object back to the tracker data.
	if trackers.has(tracker_name):
		trackers[tracker_name]["transform"] = tracker_object.global_transform

func _process(delta: float) -> void:

	_update_tracker("hand_left", left_hand_tacker, left_hand_reference, delta)
	_update_tracker("hand_right", right_hand_tacker, right_hand_reference, delta)
