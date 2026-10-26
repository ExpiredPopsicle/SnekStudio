extends Mod_Base

@onready var left_hand_reference: Node3D = $LeftHandRestReference
@onready var right_hand_reference: Node3D = $RightHandRestReference

var visible_trackers: bool = false

func _ready() -> void:
	add_tracked_setting("visible_trackers", "Visible trackers")

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	left_hand_reference.visible = visible_trackers
	right_hand_reference.visible = visible_trackers

func scene_init() -> void:
	# Transfer rest position trackers to skeleton.
	var root = get_skeleton().get_parent()
	remove_child(left_hand_reference)
	remove_child(right_hand_reference)
	root.add_child(left_hand_reference)
	root.add_child(right_hand_reference)

func scene_shutdown() -> void:
	# Transfer position trackers back to us.
	var root = get_skeleton().get_parent()
	root.remove_child(left_hand_reference)
	root.remove_child(right_hand_reference)
	add_child(left_hand_reference)
	add_child(right_hand_reference)
