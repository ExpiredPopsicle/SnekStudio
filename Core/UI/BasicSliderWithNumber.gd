@tool
extends HBoxContainer
class_name BasicSliderWithNumber

@export var min_value : float = 0.0 : set = _set_min_value
@export var max_value : float = 100.0  : set = _set_max_value
@export var value : float = 1.0 : set = _set_value
@export var step : float = 1.0  : set = _set_step
@export var disabled : bool = true : set = _set_disabled

signal value_changed(value)

# Called when the node enters the scene tree for the first time.
func _ready():
	_update_widgets_with_new_values()

var _dont_handle_change_temporarily = false

func _update_widgets_with_new_values():
	_dont_handle_change_temporarily = true
	$HSlider.value = value
	$HSlider.min_value = min_value
	$HSlider.max_value = max_value
	$HSlider.step = step
	$SpinBox.value = value
	$SpinBox.min_value = min_value
	$SpinBox.max_value = max_value
	$SpinBox.step = step
	_dont_handle_change_temporarily = false

func _set_value(new_value):
	_dont_handle_change_temporarily = true
	value = new_value
	_dont_handle_change_temporarily = false
	_update_widgets_with_new_values()
	_handle_value_change(value)

func set_value_no_signal(new_value):
	_dont_handle_change_temporarily = true
	value = new_value
	_dont_handle_change_temporarily = false
	_update_widgets_with_new_values()
	
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

func _handle_value_change(new_value):
	value_changed.emit(new_value)

func _on_h_slider_value_changed(new_value):
	if _dont_handle_change_temporarily:
		return
	_dont_handle_change_temporarily = true
	value = new_value
	$SpinBox.value = value
	_dont_handle_change_temporarily = false
	_handle_value_change(value)

func _on_spin_box_value_changed(new_value):
	if _dont_handle_change_temporarily:
		return
	_dont_handle_change_temporarily = true
	value = new_value
	$HSlider.value = value
	_dont_handle_change_temporarily = false
	_handle_value_change(value)

func _set_disabled(new_disabled : bool):
	$HSlider.editable = not new_disabled
	$SpinBox.editable = not new_disabled
