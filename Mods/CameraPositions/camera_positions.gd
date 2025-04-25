extends Mod_Base

const MOD_NAME: String = "Camera_Positions"

var camera_position_name: Array = Array()
var cam_positions: Dictionary = {}
var last_camera_selected: String
var should_track_last_camera: bool

func _log(str: String):
	print_log(str)
	
func _ready():
	var name_vals: Array[String]
	
	for i in range(1, 10):
		name_vals.append("Camera %d" % i)
	
	add_tracked_setting("camera_position_name", "Saved positions", 
		{ 
			"allow_multiple": false, 
			"combobox": true, 
			"values": name_vals 
		})
	add_tracked_setting("should_track_last_camera", "Load last camera used on program start")
	
	update_settings_ui()
	
	# Add loading/saving.
	var load_button : Button = Button.new()
	load_button.text = "Load Selected Position"
	get_settings_window().add_child(load_button)
	load_button.pressed.connect(_load_position)
	
	var save_button : Button = Button.new()
	save_button.text = "Save Current Position"
	get_settings_window().add_child(save_button)
	save_button.pressed.connect(_save_position)
	
	_log("Initialized mod.")

func _get_camera() -> Node3D:
	var app = get_app()
	var cam_child: Node3D = app.camera_boom
	assert(cam_child != null)
	return cam_child

func _get_selected_camera_name(default_text: String = "Camera 1") -> String: 
	var selected_cam_name = default_text
	if (len(camera_position_name) > 0):
		# Only set if relevant
		selected_cam_name = camera_position_name[0]
	return selected_cam_name

func _load_camera_position(camera_name: String):
	var cam = _get_camera()
	var cam_pos = cam_positions[camera_name]
	
	cam.load_settings(cam_pos)
	
func _load_position():
	var selected_cam_name = _get_selected_camera_name()
	_log("Loading %s position." % selected_cam_name)
	
	if not cam_positions.has(selected_cam_name):
		_log("Failed to load %s position - does not exist yet!" % selected_cam_name)
		return
		
	_load_camera_position(selected_cam_name)
	last_camera_selected = selected_cam_name
	
	_log("Loaded %s position." % selected_cam_name)
	
	
func _save_position():
	var selected_cam_name = _get_selected_camera_name()
	
	_log("Saving %s position." % selected_cam_name)
	
	var cam = _get_camera()
	var cam_pos = cam.save_settings()
	
	cam_positions[selected_cam_name] = cam_pos
	last_camera_selected = selected_cam_name
	
	_log("Saved %s position." % selected_cam_name)

func save_before(_settings_current : Dictionary):
	_log("Saving %d camera positions" % len(cam_positions))
	_settings_current["%s_cam_positions" % MOD_NAME] = cam_positions
	
	if len(last_camera_selected) > 0:
		_log("Saving %s as last camera" % last_camera_selected)
		_settings_current["%s_last_cam" % MOD_NAME] = last_camera_selected 
	else:
		_log("No last camera was selected!")
		
func load_before(_settings_old : Dictionary, _settings_new : Dictionary):
	if _settings_new.has("%s_cam_positions" % MOD_NAME):
		_log("Loading camera positions from settings...")
		cam_positions = _settings_new["%s_cam_positions" % MOD_NAME]
		_log("Loaded %d camera position(s)" % len(cam_positions))
	else:
		_log("New settings did not contain any camera positions.")
	
	if _settings_new.has("%s_last_cam" % MOD_NAME):
		_log("Loading last camera from settings...")
		last_camera_selected = _settings_new["%s_last_cam" % MOD_NAME]
	else:
		_log("No last camera was saved.")
	
func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	if should_track_last_camera and len(last_camera_selected) > 0:
		_log("Changing (load_after) camera position to: %s" % last_camera_selected)
		_load_camera_position(last_camera_selected)
		_log("Changed (load_after) camera position to: %s" % last_camera_selected)
	
