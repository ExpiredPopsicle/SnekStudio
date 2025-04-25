extends HBoxContainer
class_name VectorSettingWidget

@export var vector2 := false
@export var custom_step: float = 0.01
@export var custom_min: float = -100.0
@export var custom_max: float = 100.0

# FIXME: Make this and BasicSliderWithNumber both use the same base class.

var value : Vector3 = Vector3(0.0, 0.0, 0.0) : set = _set_value

signal value_changed(value)

# Called when the node enters the scene tree for the first time.
func _ready():

	$SpinBox0.value_changed.connect(
		_on_spin_box_value_changed.bind(0))
	$SpinBox1.value_changed.connect(
		_on_spin_box_value_changed.bind(1))
	$SpinBox2.value_changed.connect(
		_on_spin_box_value_changed.bind(2))
	
	if not is_equal_approx(custom_step, 0.01):
		for sb: SpinBox in [$SpinBox0, $SpinBox1, $SpinBox2]:
			sb.step = custom_step
	if not is_equal_approx(custom_min, -100.0):
		for sb: SpinBox in [$SpinBox0, $SpinBox1, $SpinBox2]:
			sb.min_value = custom_min
	if not is_equal_approx(custom_max, 100.0):
		for sb: SpinBox in [$SpinBox0, $SpinBox1, $SpinBox2]:
			sb.max_value = custom_max
	
	$SpinBox2.visible = not vector2 # sorry

	_update_widgets_with_new_values()

var _dont_handle_change_temporarily = false

func _update_widgets_with_new_values():
	_dont_handle_change_temporarily = true
	$SpinBox0.value = value[0]
	$SpinBox1.value = value[1]
	$SpinBox2.value = value[2]
	_dont_handle_change_temporarily = false

func _set_value(new_value : Vector3):
	_dont_handle_change_temporarily = true
	value = new_value
	_dont_handle_change_temporarily = false
	_update_widgets_with_new_values()
	_handle_value_change(value)

func set_value_no_signal(new_value : Vector3):
	_dont_handle_change_temporarily = true
	value = new_value
	_dont_handle_change_temporarily = false
	_update_widgets_with_new_values()

func _handle_value_change(new_value : Vector3):
	value_changed.emit(new_value)

func _on_spin_box_value_changed(new_value : float, spinbox_index : int):
	if _dont_handle_change_temporarily:
		return
	_dont_handle_change_temporarily = true
	value[spinbox_index] = new_value
	_dont_handle_change_temporarily = false
	_handle_value_change(value)

func _set_disabled(new_disabled : bool):
	$SpinBox0.editable = not new_disabled
	$SpinBox1.editable = not new_disabled
	$SpinBox2.editable = not new_disabled
