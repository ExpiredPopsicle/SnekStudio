extends Mod_Base

var light_ambient_color = Color(1.0, 1.0, 1.0, 1.0)
var light_ambient_multiplier = 0.3
var light_directional_color = Color(1.0, 1.0, 1.0, 1.0)
var light_directional_multiplier = 0.7

var light_directional_pitch = 1.0
var light_directional_yaw = 1.0

var draw_ground_plane = true

func _read_settings_from_scene():

	light_ambient_color = $WorldEnvironment.environment.ambient_light_color
	light_ambient_multiplier = $WorldEnvironment.environment.ambient_light_energy
	light_directional_color = $DirectionalLight3D.light_color
	light_directional_multiplier = $DirectionalLight3D.light_energy

	var directional_light_euler = $DirectionalLight3D.transform.basis.get_euler()	
	light_directional_pitch = directional_light_euler[0] / (PI / 180.0)
	light_directional_yaw = directional_light_euler[1] / (PI / 180.0)

	draw_ground_plane = $GroundPlane.visible

func _save_settings_to_scene():
		
	$GroundPlane.visible = draw_ground_plane

	# Load lighting settings.
	$WorldEnvironment.environment.ambient_light_color = light_ambient_color
	$WorldEnvironment.environment.ambient_light_energy = light_ambient_multiplier
	$DirectionalLight3D.light_color = light_directional_color
	$DirectionalLight3D.light_energy = light_directional_multiplier
	
	# Load directional light direction.
	var directional_light_euler = $DirectionalLight3D.transform.basis.get_euler()	
	directional_light_euler[0] = light_directional_pitch * PI / 180.0
	directional_light_euler[1] = light_directional_yaw * PI / 180.0
	$DirectionalLight3D.transform.basis = Basis.from_euler(directional_light_euler)

func _ready():

	_read_settings_from_scene()
	
	add_tracked_setting("light_ambient_color", "Directional Light Color")
	add_tracked_setting("light_ambient_multiplier", "Ambient Light Energy", {"min": 0.0, "max": 2.0})
	add_tracked_setting("light_directional_color", "Directional Light Color")
	add_tracked_setting("light_directional_multiplier", "Directional Light Energy", {"min": 0.0, "max": 2.0})
	add_tracked_setting("light_directional_pitch", "Directional Light Pitch", {"min": -180.0, "max": 180.0})
	add_tracked_setting("light_directional_yaw", "Directional Light Yaw", {"min": -180.0, "max": 180.0})
	add_tracked_setting("draw_ground_plane", "Draw Ground Plane")

	update_settings_ui()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	_save_settings_to_scene()
