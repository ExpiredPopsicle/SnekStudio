extends Control

@export var controller : ModelController
@export var camera_boom : Node3D

var dragging_camera = false

func _get_root():
	return get_node("../..")

func _process(_delta):
	# TODO: Use this technique to get mouse info when cursor is outside window.
	# TODO: Test it on Windows and maybe Mac.
	#print(Vector2(get_viewport().get_position()) + get_viewport().get_mouse_position())
	pass

func _on_files_dropped(files):
	# TODO: We'll hook this up to load VRMs and props
	print("FILES WERE DROPPED HERE: ", files)

func _reset_window_title():
	var full_title = ProjectSettings.get_setting("application/config/name")

	DisplayServer.window_set_title(
		full_title)

# Called when the node enters the scene tree for the first time.
func _ready():
	
	# TODO(LOADING): Restore UI visibility and hidden/shown windows.
	# TODO(SAVING): Save UI visibility and hidden/shown windows.
	
	_reset_window_title()
	
	set_process_unhandled_input(true)

	get_viewport().files_dropped.connect(_on_files_dropped)

func _on_vrm_load_file_dialog_file_selected(path):
	_get_root().load_vrm(path)

#func _input(event):
#	print("Normal input: ", event)
#	if event is InputEventKey:
#		if event.pressed:
#			if event.keycode == KEY_ESCAPE:
#				if not event.is_echo():
#					visible = !visible
#
#func _unhandled_input(event):
#	print("UNHANDLED: ", event)

func _gui_input(event):

	# TODO: Make these configurable?
	var rotation_scale = 0.5
	var pan_scale = 0.001
	var zoom_scale = 0.2

	if event is InputEventMouseButton:
		# FIXME: OffKai Steam-Deck hack!
		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				dragging_camera = true
			else:
				dragging_camera = false
			get_viewport().set_input_as_handled()
		
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_boom.zoom_camera(zoom_scale)
				get_viewport().set_input_as_handled()
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_boom.zoom_camera(-zoom_scale)
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		if dragging_camera:
			
			# FIXME: Adding "escape" here is an OffKai hack.
			if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_ENTER):
				
				# Pan camera.
				camera_boom.pan_camera(
					-event.relative.x * pan_scale,
					event.relative.y * pan_scale)
			else:
			
				# Rotate camera.
				camera_boom.rotate_camera_relative(
					-event.relative.y * rotation_scale,
					-event.relative.x * rotation_scale)
					



func _on_resized():
	# Go through all our sub-windows and make sure they don't slide off the edge
	# of the screen.
	for child in get_children():
		if child is BasicSubWindow:
			child._ensure_window_visibility()


# -----------------------------------------------------------------------------
# Menus

func _on_help_id_pressed(id):
	if id == 1:
		$HelpAboutWindow.show_window()
	if id == 0:
		$HelpControlsWindow.show_window()

func _on_file_id_pressed(id):

	# Load VRM
	if id == 0:
		$VRMFileLoadDialog.size = get_window().size / 2
		$VRMFileLoadDialog.position = get_window().size / 4
		$VRMFileLoadDialog.show()

	# Quit
	if id == 1:
		get_tree().quit()
		
	# Save settings.
	if id == 3:
		$SettingsSaveDialog.size = get_window().size / 2
		$SettingsSaveDialog.position = get_window().size / 4
		$SettingsSaveDialog.show()
	
	# Load settings.
	if id == 4:
		$SettingsLoadDialog.size = get_window().size / 2
		$SettingsLoadDialog.position = get_window().size / 4
		$SettingsLoadDialog.show()

func _on_settings_id_pressed(id):
	if id == 0:
		%SettingsWindow_General.show_window()
	if id == 1:
		%SettingsWindow_Colliders.show_window()
	if id == 2:
		%SettingsWindow_Sound.show_window()
	if id == 3:
		%SettingsWindow_Scene.show_window()
	if id == 4:
		%SettingsWindow_Window.show_window()

func _on_mods_id_pressed(id):
	if id == 0:
		%ModsWindow.show_window()
	if id == 1:
		%ChannelEvents.show_window()

func _on_settings_save_dialog_file_selected(path):
	_get_root().save_settings(path)

func _on_settings_load_dialog_file_selected(path):
	_get_root().load_settings(path)
