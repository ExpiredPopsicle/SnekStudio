extends Mod_Base



# HOTAS.gd handles the position of the Devices and passes Properties from the Settings to the Mod
# DeviceSlot.gd keeps track of the device, and animates the device. Kept as separate action as the smoothing may happen in HOTAS.gd
# tickDriver.gd simply keeps track of the AnimationBlendTree and passes parameters to it when its functions are called
#region props
var last_input_left : Vector3 = Vector3(0.0, 0.0, 0.0)
var last_input_right : Vector3 = Vector3(0.0, 0.0, 0.0)

## Distance between the two models.
var model_distance : float = 0.5

## Height of the models off the floor.
var model_height : float = 2.8

## Horizontal shift.
var model_xoffset : float = 0.0

## Depth shift.
var model_zoffset : float = 0.0

var right_device : Array = [""]
var right_device_model : Array = [""]

var left_device : Array = [""]
var left_device_model : Array = [""]

var right_device_axis_x : int = JoyAxis.JOY_AXIS_LEFT_X
var right_device_axis_x_invert: bool = false
var right_device_axis_y : int = JoyAxis.JOY_AXIS_LEFT_Y
var right_device_axis_y_invert: bool = false
var right_device_axis_z : int = -1
var right_device_axis_z_invert: bool = false

var left_device_axis_y : int = JoyAxis.JOY_AXIS_RIGHT_Y
var left_device_axis_y_invert: bool = false

var left_device_axis_x : int = JoyAxis.JOY_AXIS_RIGHT_X
var left_device_axis_x_invert: bool = false

var left_device_axis_z : int = -1
var left_device_axis_z_invert: bool = false

#endregion
#region constants and privates

var _device_list : Array = []

const _device_model_type_str : Array = [
	"None",
	"Right Joystick",
	"Right Omnistick",
	"Right Throttle",
	"Left Joystick",
	"Left Omnistick",
	"Left Throttle"
]
const _device_model_type_res : Array = [
	"",
	"res://Mods/HOTAS/FlightStick/RightStick.tscn",
	"res://Mods/HOTAS/FlightStick/RightOmniStick.tscn",
	"res://Mods/HOTAS/FlightStick/RightThrottle.tscn",
	"res://Mods/HOTAS/FlightStick/LeftStick.tscn",
	"res://Mods/HOTAS/FlightStick/LeftOmniStick.tscn",
	"res://Mods/HOTAS/FlightStick/LeftThrottle.tscn",
]

#endregion

@onready
var _left_slot: DeviceSlot = %LeftDeviceSlot
@onready
var _right_slot: DeviceSlot = %RightDeviceSlot

func _on_settings_update() -> void:
	# Update a device slot with the new parameters
	_left_slot.device_index = _device_list.find(left_device[0])
	_left_slot.axis_x = left_device_axis_x
	_left_slot.axis_y = left_device_axis_y 
	_left_slot.axis_z = left_device_axis_z
	_left_slot.invert_x = left_device_axis_x_invert
	_left_slot.invert_y = left_device_axis_y_invert
	_left_slot.invert_z = left_device_axis_z_invert
	
	# Update the right device slot with the new parameters
	_right_slot.device_index = _device_list.find(right_device[0])
	_right_slot.axis_x = right_device_axis_x
	_right_slot.axis_y = right_device_axis_y 
	_right_slot.axis_z = right_device_axis_z
	_right_slot.invert_x = right_device_axis_x_invert
	_right_slot.invert_y = right_device_axis_y_invert
	_right_slot.invert_z = right_device_axis_z_invert
	# Set devices as default if any are found.
	
	var left_model_index = _device_model_type_str.find(left_device_model[0])
	var right_model_index = _device_model_type_str.find(right_device_model[0])
	
	if left_model_index <= 0:
		_left_slot.remove_device()
	else:
		var Model: PackedScene = load(_device_model_type_res[left_model_index])
		_left_slot.replace_device(Model.instantiate())

	if right_model_index <= 0:
		_right_slot.remove_device()
	else:
		var Model: PackedScene = load(_device_model_type_res[right_model_index])
		_right_slot.replace_device(Model.instantiate())

func side_filter(side: String) -> Callable:
	var comparitor: Callable = func(val: Variant):
		return val.contains(side)
	return comparitor

func _ready() -> void:
	if len(_device_list):
		right_device = [_device_list[0]]
		left_device = [_device_list[0]]
	
	var _left_device_models = _device_model_type_str.filter(side_filter("Left"))
	_left_device_models.push_front("")
	var _right_device_models = _device_model_type_str.filter(side_filter("Right"))
	_right_device_models.push_front("")
	# Connect setting updates to a separate event 
	on_settings_update.connect(_on_settings_update)
	
	# TODO : compress settings in UI
	add_tracked_setting(
		"model_distance", "Distance between throttle and stick",
		{ "min" : 0.0, "max" : 5.0, "step" : 0.01 })
	add_tracked_setting(
		"model_height", "Height of the throttle and stick",
		{ "min" : 0.0, "max" : 10.0, "step" : 0.01 })
	add_tracked_setting(
		"model_xoffset", "Model X offset (left/right)",
		{ "min" : -10.0, "max" : 10.0, "step" : 0.01 })
	add_tracked_setting(
		"model_zoffset", "Model Z offset (forward/backward)",
		{ "min" : -10.0, "max" : 10.0, "step" : 0.01 })
 
	# Enumerate attached joystick devices.
	var connected_device_indices : Array = Input.get_connected_joypads()
	for device_index : int in connected_device_indices:
		_device_list.push_back(Input.get_joy_name(device_index))

	# Todo, compressing UI
	add_tracked_setting(
		"right_device_model", "Right Device Model", {
			"values": _right_device_models,
			"combobox" : true,
		}
	)
	add_tracked_setting(
		"right_device", "Right Device", { 
		 	"values" : _device_list,
		 	"combobox" : true,
		}
	)
	
	add_tracked_setting(
		"left_device_model", "Left Device Model", {
			"values": _left_device_models,
			"combobox" : true,
		})
	
	add_tracked_setting(
		"left_device", "Left Device", {
			"values" : _device_list,
			"combobox" : true,
		})
	
	add_tracked_setting("left_device_axis_y", "LeftDevice Y axis.  -1 to disable", { "min" : -1, "max" : 10, "step" : 1 })
	add_tracked_setting("left_device_axis_y_invert", " Invert Throttle Y Axis")
	
	add_tracked_setting("left_device_axis_x", "LeftDevice X axis. -1 to disable", { "min" : -1, "max" : 10, "step" : 1})
	add_tracked_setting("left_device_axis_x_invert", "Invert Throttle X Axis")
	
	add_tracked_setting("left_device_axis_z", "LeftDevice Twist Axis, -1 to disable", { "min" : -1, "max" : 10, "step" : 1})
	add_tracked_setting("left_device_axis_z_invert", "Invert Throttle Z Axis")
	
	add_tracked_setting("right_device_axis_y", "RightDevice Y axis (usually throttle). -1 to disable", { "min" : -1, "max" : 10, "step" : 1})
	add_tracked_setting("right_device_axis_y_invert", "Invert Stick Y Axis")
	
	add_tracked_setting("right_device_axis_x", "RightDevice X axis. -1 to disable", { "min" : -1, "max" : 10, "step" : 1})
	add_tracked_setting("right_device_axis_x_invert", "Invert Stick X Axis")
	
	add_tracked_setting("right_device_axis_z", "RightDevice Twist. -1 to disable", { "min" : -1, "max" : 10, "step" : 1})
	add_tracked_setting("right_device_axis_z_invert", "Invert Stick Z Axis")

func _process(delta: float) -> void:

	%RightDeviceSlot.transform.origin.x = -model_distance / 2.0
	%LeftDeviceSlot.transform.origin.x = model_distance / 2.0

	%RightDeviceSlot.transform.origin.y = model_height / 2.0
	%LeftDeviceSlot.transform.origin.y = model_height / 2.0

	%RightDeviceSlot.transform.origin.x += model_xoffset
	%LeftDeviceSlot.transform.origin.x += model_xoffset

	%RightDeviceSlot.transform.origin.z = model_zoffset
	%LeftDeviceSlot.transform.origin.z = model_zoffset

	var tracker_dict : Dictionary = get_global_mod_data("trackers")

	var device_index : int = _device_list.find(right_device[0])

	if device_index != -1:
		var current_input_left: Vector3 = last_input_left
		current_input_left = lerp(current_input_left, _left_slot.get_device_vector(), 0.5) 

		last_input_left = current_input_left
		_left_slot.animate(current_input_left, %Hand_Left, tracker_dict)
		
		var new_input_stick : Vector3 = _right_slot.get_device_vector()

		# FIXME: Hardcoded blend speed.
		var current_input_right : Vector3 = lerp(last_input_right, new_input_stick, 0.5)

		last_input_right = current_input_right
		_right_slot.animate(current_input_right, %Hand_Right, tracker_dict)
