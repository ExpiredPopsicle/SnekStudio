extends Mod_Base

var image_path: String
var image: Image

var proceduralSky = ProceduralSkyMaterial.new()
var panoramicSky = PanoramaSkyMaterial.new()

var tonemapper = ["Linear"]
var tonemaps = {
	"Linear": Environment.ToneMapper.TONE_MAPPER_LINEAR,
	"Reinhardt": Environment.ToneMapper.TONE_MAPPER_REINHARDT,
	"Filmic": Environment.ToneMapper.TONE_MAPPER_FILMIC,
	"ACES": Environment.ToneMapper.TONE_MAPPER_ACES
}

var exposure = 1.0

var light_ambient_source = ["Disabled"]
var ambient_sources = {
	"Disabled": Environment.AmbientSource.AMBIENT_SOURCE_DISABLED,
	"Color": Environment.AmbientSource.AMBIENT_SOURCE_COLOR,
	"Sky": Environment.AmbientSource.AMBIENT_SOURCE_SKY
}

var light_reflection_source = ["Disabled"]
var reflection_sources = {
	"Disabled": Environment.ReflectionSource.REFLECTION_SOURCE_DISABLED,
	"Sky": Environment.ReflectionSource.REFLECTION_SOURCE_SKY,
}

var light_ambient_color = Color(1.0, 1.0, 1.0, 1.0)
var light_ambient_multiplier = 0.3
var light_directional_color = Color(1.0, 1.0, 1.0, 1.0)
var light_directional_multiplier = 0.7

var light_directional_pitch = 1.0
var light_directional_yaw = 1.0

var draw_ground_plane = true

func _read_settings_from_scene():
	
	tonemapper[0] = tonemaps.find_key($WorldEnvironment.environment.get_tonemapper())
	exposure = $WorldEnvironment.environment.get_tonemap_exposure()

	light_ambient_source[0] = ambient_sources.find_key($WorldEnvironment.environment.get_ambient_source())
	light_reflection_source[0] = reflection_sources.find_key($WorldEnvironment.environment.get_reflection_source())
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
	$WorldEnvironment.environment.set_tonemapper(tonemaps.get(tonemapper[0]))
	$WorldEnvironment.environment.set_tonemap_exposure(exposure)
	
	$WorldEnvironment.environment.set_ambient_source(ambient_sources.get(light_ambient_source[0]))
	$WorldEnvironment.environment.set_reflection_source(reflection_sources.get(light_reflection_source[0]))
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
	
	add_tracked_setting("tonemapper", "Tonemapper", {"values" : tonemaps.keys(), "combobox" : true})
	add_tracked_setting("exposure", "Tonemap Exposure", {"min": 0.1, "max": 10.0})
	add_tracked_setting("light_reflection_source", "Reflection Source", {"values" : reflection_sources.keys(), "combobox" : true})
	add_tracked_setting("light_ambient_source", "Ambient Light Source", {"values" : ambient_sources.keys(), "combobox" : true})
	add_tracked_setting("light_ambient_color", "Ambient Light Color")
	add_tracked_setting("light_ambient_multiplier", "Ambient Light Energy", {"min": 0.0, "max": 10.0})
	add_tracked_setting("light_directional_color", "Directional Light Color")
	add_tracked_setting("light_directional_multiplier", "Directional Light Energy", {"min": 0.0, "max": 10.0})
	add_tracked_setting("light_directional_pitch", "Directional Light Pitch", {"min": -180.0, "max": 180.0})
	add_tracked_setting("light_directional_yaw", "Directional Light Yaw", {"min": -180.0, "max": 180.0})
	add_tracked_setting("image_path", "Custom Panorama (HDRI)", {"is_fileaccess": true, "file_filters": PackedStringArray(["*.exr,*.hdr,*.png;Panoramic HDR Images"])})
	add_tracked_setting("draw_ground_plane", "Draw Ground Plane")

	update_settings_ui()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary) -> void:

	if _settings_old["image_path"] != _settings_new["image_path"] or \
		_settings_old["light_reflection_source"] != _settings_new["light_reflection_source"] or \
		_settings_old["light_ambient_multiplier"] != _settings_new["light_ambient_multiplier"] or \
		_settings_old["light_ambient_source"] != _settings_new["light_ambient_source"]:

		# This setting is only relevant if either sources are actually set to sky
		if ambient_sources.get(light_ambient_source[0]) == Environment.AMBIENT_SOURCE_SKY || reflection_sources.get(light_reflection_source[0]) == Environment.REFLECTION_SOURCE_SKY:
			# Fallback to procedural sky if image is invalid
			image = Image.load_from_file(ProjectSettings.localize_path(image_path))
			if !image:
				$WorldEnvironment.environment.sky.set_material(proceduralSky)
			else:
				$WorldEnvironment.environment.sky.set_material(panoramicSky)
				$WorldEnvironment.environment.sky.sky_material.set_panorama(ImageTexture.create_from_image(image))
				$WorldEnvironment.environment.sky.sky_material.energy_multiplier = light_ambient_multiplier

	_save_settings_to_scene()

# FIXME: It would be really cool if we could use the 3D transform here to rotate
# the reflections as well.
func needs_3D_transform() -> bool:
	return true
