extends HBoxContainer
class_name VectorSettingWidget

# FIXME: Make this and BasicSliderWithNumber both use the same base class.

var value : Vector3 = Vector3(0.0, 0.0, 0.0) : set = _set_value
var min_value : float = 0.0 : set = _set_min_value
var max_value : float = 100.0  : set = _set_max_value
var step : float = 1.0  : set = _set_step


signal value_changed(value)

# Called when the node enters the scene tree for the first time.
func _ready():

	$SpinBox0.value_changed.connect(
		_on_spin_box_value_changed.bind(0))
	$SpinBox1.value_changed.connect(
		_on_spin_box_value_changed.bind(1))
	$SpinBox2.value_changed.connect(
		_on_spin_box_value_changed.bind(2))

	_update_widgets_with_new_values()

var _dont_handle_change_temporarily = false

func _update_widgets_with_new_values():
	_dont_handle_change_temporarily = true

	$SpinBox0.value = value[0]
	$SpinBox1.value = value[1]
	$SpinBox2.value = value[2]

	$SpinBox0.min_value = min_value
	$SpinBox1.min_value = min_value
	$SpinBox2.min_value = min_value

	$SpinBox0.max_value = max_value
	$SpinBox1.max_value = max_value
	$SpinBox2.max_value = max_value

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

func _set_min_value(new_min_value):
	_dont_handle_change_temporarily = true
	min_value = new_min_value
	_dont_handle_change_temporarily = false
	_update_widgets_with_new_values()

func _set_max_value(new_max_value):
	_dont_handle_change_temporarily = true
	max_value = new_max_value
	_dont_handle_change_temporarily = false
	_update_widgets_with_new_values()

func _set_step(new_step):
	_dont_handle_change_temporarily = true
	step = new_step
	_dont_handle_change_temporarily = false
	_update_widgets_with_new_values()
