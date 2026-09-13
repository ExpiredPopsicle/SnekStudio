class_name DeviceSlot extends Node3D


const StickDriver = preload("res://Mods/HOTAS/FlightStick/StickDriver.gd")

@export
var side: String = "left"

var device_index: int = -1
var axis_y: int = -1
var axis_x: int = -1
var axis_z: int = -1

var invert_y: bool = false
var invert_x: bool = false
var invert_z: bool = false

var device_node: StickDriver = StickDriver.new()

# Moved off being reiniated every frame.
# FIXME: De-duplicate this array from all over the place.
# TODO: May need some simplification: 
# Perhaps just 1-4 than medical terms that may be harder to wrap head around
const _mediapipe_hand_landmark_names : Array = [
	"wrist",

	"thumb_cmc", # carpometacarpal
	"thumb_mcp", # metacarpal
	"thumb_ip", # interphalangeal
	"thumb_tip", # tip

	"index_finger_mcp",
	"index_finger_pip", # proximal interphalangeal
	"index_finger_dip", # distal interphalangeal
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

func get_device_axis(axis_index: int, invert: bool) -> float:
	if device_index == -1 || axis_index == -1:
		return 0
	var value = Input.get_joy_axis(device_index, axis_index)
	if invert: 
		return -value
	return value 
	
func get_device_vector() -> Vector3:
	var x = get_device_axis(axis_x, invert_x)
	var y = get_device_axis(axis_y, invert_y)
	var z = get_device_axis(axis_z, invert_z)
	
	return Vector3(x, y, z)

func remove_children():
	for child in self.get_children():
		self.remove_child(child)
		child.queue_free()

func remove_device() -> void:
	remove_children()
	device_node = null
	
func replace_device(new_node: StickDriver) -> void:
	remove_device()
	self.add_child(new_node)
	device_node = new_node

func animate(vec: Vector3, hand_tracker: Node3D, tracker_dict: Dictionary) -> void:
	if device_index == -1 or device_node == null: return
	device_node.set_animation(vec)
	
	var device = get_child(0)
	var wrist_position = device.find_child("hand")
	
	if tracker_dict["hand_" + side]["active"] == false and device != null and wrist_position != null:
		tracker_dict["hand_" + side]["active"] = true
		tracker_dict["hand_" + side]["transform"] = wrist_position.global_transform

		for tracker_name in _mediapipe_hand_landmark_names:
			var tracker_node : Node3D = device.find_child(tracker_name)
			if tracker_node:
				tracker_dict["finger_positions"][side + "_" + tracker_name] = tracker_node.global_transform.origin
