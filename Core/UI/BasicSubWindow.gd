@tool
extends Control
class_name BasicSubWindow

var is_mouse_in_window = false
var is_move_dragging = false
var is_mouse_in_border = false

var is_size_dragging = false
var size_dragging_vertical_edge = 0 # -1, 0, 1 for top, middle, bottom
var size_dragging_horizontal_edge = 0 # -1, 0, 1 for left, middle, right

# Serializable dimensions and popout state
var popped_out: bool = false
var embed_window_pos: Vector2 = Vector2(0, 0)
var embed_window_size: Vector2 = Vector2(0, 0)
var popout_window_pos: Vector2i = Vector2i(0, 0)
var popout_window_size: Vector2i = Vector2i(0, 0)

# Native window if popped out
var popout_window: Window = null

# Position in parent.
var _drag_start_position = position
var _drag_start_size = size

# Drag position relative to start of drag.
var _drag_current_position = Vector2(0, 0)

@export var close_button_visible : bool = true
@export var label_text : String = "Window"

signal close_requested

func _ready():
	_on_resized()
	if not close_button_visible:
		_set_close_button_visible(close_button_visible)
	$WindowTitlePanel/WindowTitle.text = label_text

# Used to optionally add this subwindow to the list of
# savable subwindows in SnekStudio_Main. Dimensions,
# popout, and other state will be saved and restored.
func register_serializable_subwindow():
	_get_app_root().subwindows.push_back(self)
	$WindowTitlePanel/PopoutButton.show()

func _process(_delta):
	
	# FIXME: Is there a better way to do these than polling every frame?
	var child = _find_child()
	if child:
		var child_min_size = child.get_combined_minimum_size()
		if child_min_size.x > size.x:
			size.x = child_min_size.x
		if child_min_size.y > size.y:
			size.y = child_min_size.y

	if label_text != $WindowTitlePanel/WindowTitle.text:
		$WindowTitlePanel/WindowTitle.text = label_text

	if close_button_visible != $WindowTitlePanel/CloseButton.visible:
		_set_close_button_visible(close_button_visible)
		
func _find_child():
	for child in get_children():
		if child != $WindowTitlePanel and child != $WindowBorder:
			return child
	return null

func _on_resized() -> void:
	var current_title_size = $WindowTitlePanel.size
	$WindowTitlePanel.size = Vector2(size[0], current_title_size[1])
	$WindowTitlePanel/WindowTitle.size.x = \
		$WindowTitlePanel.size.x - \
		2 * $WindowTitlePanel/WindowTitle.position.x

	if $WindowTitlePanel/CloseButton.visible:
		$WindowTitlePanel/WindowTitle.size.x = \
			$WindowTitlePanel/WindowTitle.size.x - \
			$WindowTitlePanel/CloseButton.size.x

	var child = _find_child()
	if child:
		child.set_size(size)
		child.position = Vector2(0.0, 0.0)

func _get_minimum_size():
	var expected_minimum_size = Vector2(64, 64)
	var child = _find_child()
	var child_minimum_size = expected_minimum_size
	if child:
		child_minimum_size = child.get_combined_minimum_size()
	
	if expected_minimum_size.x < child_minimum_size.x:
		expected_minimum_size.x = child_minimum_size.x
	if expected_minimum_size.y < child_minimum_size.y:
		expected_minimum_size.y = child_minimum_size.y

	return expected_minimum_size

func _set_close_button_visible(_is_visible):
	$WindowTitlePanel/CloseButton.visible = _is_visible
	_on_resized()

# Clamps the window (at least the title bar) to the screen to make sure we don't
# accidentally drag something off-screen.
func _ensure_window_visibility():
	var minimum_visible_border = 16
	
	var min_position_x = -size.x + minimum_visible_border
	var max_position_x = get_parent().size.x - minimum_visible_border

	var min_position_y = $WindowTitlePanel.size.y
	var max_position_y = get_parent().size.y
	
	if position.x > max_position_x:
		position.x = max_position_x
	if position.x < min_position_x:
		position.x = min_position_x

	# Correct max (+y = lower) vertical position first, so if the bottom of the
	# window goes off the bottom of the screen, the title bar remains at the
	# top.
	if position.y > max_position_y:
		position.y = max_position_y
	if position.y < min_position_y:
		position.y = min_position_y

func _input(event):
	if event is InputEventMouseMotion:
		if is_move_dragging:
			_drag_current_position += event.relative
			position = _drag_start_position + _drag_current_position
			_ensure_window_visibility()

func _on_mouse_entered():
	is_mouse_in_window = true

func _on_mouse_exited():
	is_mouse_in_window = false

func _on_focus_entered():
	get_parent().move_child(self, get_parent().get_child_count() - 1)

func _on_window_title_panel_gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			_on_focus_entered()
			grab_focus()
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_move_dragging = true
				_drag_start_position = position
				_drag_current_position = Vector2(0, 0)
				print("starting drag")
			else:
				is_move_dragging = false
				print("Stopping drag")

func _on_window_border_mouse_entered():
	is_mouse_in_border = true

func _on_window_border_mouse_exited():
	is_mouse_in_border = false

func _on_window_border_gui_input(event):

	var position_in_windowspace = Vector2(0.0, 0.0)
	if (event is InputEventMouseButton) or (event is InputEventMouseMotion):
		position_in_windowspace = event.position + $WindowBorder.position

	if event is InputEventMouseMotion:
		var potential_dragging_edge_horizontal = 0
		var potential_dragging_edge_vertical = 0
		
		if position_in_windowspace.x < 0:
			potential_dragging_edge_horizontal = -1
		elif position_in_windowspace.x > size.x:
			potential_dragging_edge_horizontal = 1
		else:
			potential_dragging_edge_horizontal = 0
			
		if position_in_windowspace.y < 0:
			potential_dragging_edge_vertical = -1
		elif position_in_windowspace.y > size.y:
			potential_dragging_edge_vertical = 1
		else:
			potential_dragging_edge_vertical = 0

		var cursor_shape = Input.CURSOR_ARROW
		if potential_dragging_edge_horizontal == 0 and potential_dragging_edge_vertical == 0:
			pass
		elif potential_dragging_edge_horizontal != 0 and potential_dragging_edge_vertical == 0:
			cursor_shape = Input.CURSOR_HSIZE
		elif potential_dragging_edge_horizontal == 0 and potential_dragging_edge_vertical != 0:
			cursor_shape = Input.CURSOR_VSIZE
		elif potential_dragging_edge_horizontal == potential_dragging_edge_vertical:
			cursor_shape = Input.CURSOR_FDIAGSIZE
		elif potential_dragging_edge_horizontal != potential_dragging_edge_vertical:
			cursor_shape = Input.CURSOR_BDIAGSIZE
			
		$WindowBorder.mouse_default_cursor_shape = cursor_shape
				


	if event is InputEventMouseButton:
		
		if event.pressed:
			_on_focus_entered()
			grab_focus()

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if not is_mouse_in_window:
					is_size_dragging = true
					_drag_start_position = position
					_drag_start_size = size
					_drag_current_position = Vector2(0.0, 0.0)
					
					if position_in_windowspace.x < 0:
						size_dragging_horizontal_edge = -1
					elif position_in_windowspace.x > size.x:
						size_dragging_horizontal_edge = 1
					else:
						size_dragging_horizontal_edge = 0
						
					if position_in_windowspace.y < 0:
						size_dragging_vertical_edge = -1
					elif position_in_windowspace.y > size.y:
						size_dragging_vertical_edge = 1
					else:
						size_dragging_vertical_edge = 0
			else:
				if is_size_dragging:
					_ensure_window_visibility()
					is_size_dragging = false

	if event is InputEventMouseMotion:
		if is_size_dragging:
			_drag_current_position += event.relative
			
			var output_size = size
			var output_position = position
			
			if size_dragging_horizontal_edge > 0:
				output_size.x = _drag_start_size.x + _drag_current_position.x
			if size_dragging_vertical_edge > 0:
				output_size.y = _drag_start_size.y + _drag_current_position.y

			if size_dragging_horizontal_edge < 0:
				output_size.x = _drag_start_size.x - _drag_current_position.x
				output_position.x = _drag_start_position.x + _drag_current_position.x
			if size_dragging_vertical_edge < 0:
				output_size.y = _drag_start_size.y - _drag_current_position.y
				output_position.y = _drag_start_position.y + _drag_current_position.y

			var min_size = get_combined_minimum_size()

			if output_size.x < min_size.x:
				if size_dragging_horizontal_edge < 0:
					output_position.x -= min_size.x - output_size.x
				output_size.x = min_size.x

			if output_size.y < min_size.y:
				if size_dragging_vertical_edge < 0:
					output_position.y -= min_size.y - output_size.y
				output_size.y = min_size.y
			
			size = output_size
			position = output_position

func _on_close_button_pressed():
	if len(close_requested.get_connections()):
		emit_signal("close_requested")
	else:
		close_window()

func close_window():
	_save_current_window_state()

	if popped_out:
		popout_window.hide()
	else:
		hide()

func show_window():
	visible = true
	_on_resized()
	grab_focus()
	_on_focus_entered()

	# If popped out, show popup if not visible, or grab focus and bring window to front
	if popped_out:
		popout_window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
		popout_window.position = popout_window_pos
		popout_window.visible = true
		popout_window.grab_focus()

func _get_app_root():
	return find_parent("SnekStudio_Main")

# -----------------------------------------------------------------------------
# Virtual functions

#region Virtual functions

func serialize_window() -> Dictionary:
	return {}

func deserialize_window(dict: Dictionary) -> void:
	pass

func popout_state_changing(pop_out: bool) -> void:
	pass

#endregion

# -----------------------------------------------------------------------------
# Window serialization

#region Window state serialization

# Internal serialization called by SnekStudio_Main when saving subwindows
func _serialize_window() -> Dictionary:
	_save_current_window_state()

	var subwindow: Dictionary = {
		"popped_out": popped_out,
		"embed_window_pos": [embed_window_pos.x, embed_window_pos.y],
		"embed_window_size": [embed_window_size.x, embed_window_size.y],
		"popout_window_pos": [popout_window_pos.x, popout_window_pos.y],
		"popout_window_size": [popout_window_size.x, popout_window_size.y]
	}

	var window_settings: Dictionary = serialize_window()
	if window_settings.size() != 0:
		subwindow["settings"] = window_settings

	return subwindow

# Internal deserialization called by SnekStudio_Main when loading subwindows
func _deserialize_window(subwindow_dict: Dictionary) -> void:
	var pop_out = subwindow_dict.get("popped_out")
	if pop_out is bool:
		embed_window_pos = Vector2(subwindow_dict["embed_window_pos"][0],
								   subwindow_dict["embed_window_pos"][1])
		embed_window_size = Vector2(subwindow_dict["embed_window_size"][0],
									subwindow_dict["embed_window_size"][1])
		popout_window_pos = Vector2i(subwindow_dict["popout_window_pos"][0],
									 subwindow_dict["popout_window_pos"][1])
		popout_window_size = Vector2i(subwindow_dict["popout_window_size"][0],
									  subwindow_dict["popout_window_size"][1])
		if pop_out != popped_out:
			_set_popped_out(pop_out)
		else:
			_load_window_state(pop_out)

	var settings = subwindow_dict.get("settings")
	if settings is Dictionary:
		deserialize_window(settings)

#endregion

# -----------------------------------------------------------------------------
# Window state

#region Window state

func _save_current_window_state() -> void:
	if popped_out:
		popout_window_pos = popout_window.position
		popout_window_size = popout_window.size
	else:
		embed_window_pos = position
		embed_window_size = size

func _load_window_state(pop_out: bool) -> void:
	if pop_out:
		popout_window.position = popout_window_pos
		popout_window.size = popout_window_size
	else:
		position = embed_window_pos
		size = embed_window_size

#endregion

# -----------------------------------------------------------------------------
# Popout functionality

#region Popout handling

func _set_popped_out(pop_out: bool) -> void:
	if popped_out == pop_out:
		return

	popped_out = pop_out

	if pop_out:
		# ---------------------------------------
		# Create menu bar

		var colorrect = ColorRect.new()
		colorrect.color = Color.BLACK
		colorrect.custom_minimum_size = Vector2(0, 32)

		var hboxcontainer = HBoxContainer.new()
		var popin_button = Button.new()
		popin_button.text = "Pop in"
		popin_button.focus_mode = Control.FOCUS_NONE
		popin_button.flat = true
		popin_button.pressed.connect(_on_popin_button_pressed)

		hboxcontainer.add_child(popin_button)
		colorrect.add_child(hboxcontainer)

		# ---------------------------------------
		# Create native window

		popout_window = Window.new()
		popout_window.title = label_text
		popout_window.transient = true
		popout_window.close_requested.connect(func(): close_window())

		# Check to see if saved position is outside of the usable screen area.
		# If it is, reset position and center window instead.
		if popout_window_pos != Vector2i(0, 0) && popout_window_size != Vector2i(0, 0):
			var inside_screen: bool = false

			for screen_idx in DisplayServer.get_screen_count():
				var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_idx)
				var tl: Vector2i = popout_window_pos
				if screen_rect.has_point(tl):
					inside_screen = true
					break

			if !inside_screen:
				popout_window_pos = Vector2i(0, 0)

		# Try to use the current size if it hasn't been popped out before
		if popout_window_size == Vector2i(0, 0):
			popout_window_size = Vector2i(size + Vector2(16, 16))

		# Center window if it hasn't been popped out before
		if popout_window_pos == Vector2i(0, 0):
			popout_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
		else:
			popout_window.initial_position = Window.WINDOW_INITIAL_POSITION_ABSOLUTE
			popout_window.position = popout_window_pos

		popout_window.size = popout_window_size
		popout_window.visible = visible

		# Add popout window as child of UI_Root
		get_parent().add_child(popout_window)

		# ---------------------------------------
		# Add containers and controls to window

		# Put subwindow within a control in order to get padding via anchor offsets
		var bare_control = Control.new()
		bare_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bare_control.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var container = VBoxContainer.new()
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		container.add_child(colorrect)
		container.add_child(bare_control)

		popout_window.add_child(container)

		# ---------------------------------------
		# Reparent to the empty control in popup window
		#
		# Also, always reparent last to ensure scene ownership and thus
		# unique name access

		reparent(bare_control)

		# ---------------------------------------
		# Hide embed decorations, reset dimensions, add anchors/padding

		$WindowBorder.visible = false
		$WindowTitlePanel.visible = false
		position = Vector2(0, 0)
		set_anchors_preset(Control.PRESET_FULL_RECT)
		set_offset(SIDE_LEFT, 8)
		set_offset(SIDE_TOP, 8)
		set_offset(SIDE_BOTTOM, -8)
		set_offset(SIDE_RIGHT, -8)

	else:
		# ---------------------------------------
		# Restore embedded decorations and dimensions, remove anchors/padding

		# Check to see if embedded position is outside of visible viewport area.
		# If it is, reset embedded position to 0,0.
		var ui_root = _get_app_root().get_node("%UI_Root")
		if !Rect2(Vector2(0, 0), ui_root.size).has_point(embed_window_pos):
			embed_window_pos = Vector2(0, 0)

		$WindowBorder.visible = true
		$WindowTitlePanel.visible = true
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		set_offset(SIDE_LEFT, 0)
		set_offset(SIDE_TOP, 0)
		set_offset(SIDE_BOTTOM, 0)
		set_offset(SIDE_RIGHT, 0)
		position = embed_window_pos
		size = embed_window_size

		# ---------------------------------------
		# Reparent to UI root

		reparent(ui_root)

		# ---------------------------------------
		# Free popout window

		popout_window.queue_free()

func _on_popin_button_pressed() -> void:
	_save_current_window_state()
	popout_state_changing(false)
	_set_popped_out(false)

func _on_popout_button_pressed() -> void:
	_save_current_window_state()
	popout_state_changing(true)
	_set_popped_out(true)

#endregion
