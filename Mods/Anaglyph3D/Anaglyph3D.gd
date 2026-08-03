extends Mod_Base

var subviewport_left: SubViewport
var subviewport_right: SubViewport

## Inter-pupillary distance
var ipd: float = 0.0287 # realistic: 0.0064

## Blend between a grayscale version and version with color.
var luminance_vs_color: float = 0.5

var color_left: Color = Color(1.0, 0.0, 0.0)
var color_right: Color = Color(0.0, 0.75, 1.0)

## If set to true, doesn't rely on redeems to activate.
var always_active: bool = false

var redeem_name: String
var seconds_active_per_redeem: float = 60.0
var seconds_left: float = 0.0

var eye_inward_rotation: float = -2.1

func _get_enabled() -> bool:
	if always_active:
		return true

	if seconds_left > 0.0:
		return true

	return false

func handle_channel_point_redeem(_redeemer_username, _redeemer_display_name, _redeem_title, _user_input):
	if redeem_name == _redeem_title:
		if seconds_left < 0.0:
			seconds_left = 0.0

		# Just accumulate more time.
		seconds_left += seconds_active_per_redeem

func _ready() -> void:
	
	add_tracked_setting("ipd", "Inter Pupillary Distance (meters)", { "min" : -1.0, "max" : 1.0, "step" : 0.0001 })
	add_tracked_setting("eye_inward_rotation", "Eye inward rotation (degrees)", { "min" : -180.0, "max" : 180.0, "step" : 0.1 })
	add_tracked_setting("luminance_vs_color", "Luminance vs Color", { "min" : 0.0, "max" : 1.0, "step" : 0.01 })
	add_tracked_setting("color_left", "Left color")
	add_tracked_setting("color_right", "Right color")
	add_tracked_setting("always_active", "Always active")
	add_tracked_setting("redeem_name", "Redeem Name", {"is_redeem" : true})
	add_tracked_setting("seconds_active_per_redeem", "Seconds active", { "min" : 0.0, "max" : 3600.0 * 24.0 })
	update_settings_ui()

	subviewport_left = $SubViewport_Left
	subviewport_right = $SubViewport_Right

	# Use the same world_3d as the main viewport. So we can render the same
	# stuff.
	subviewport_left.world_3d = get_viewport().world_3d
	subviewport_right.world_3d = get_viewport().world_3d

	# Assign textures from the viewports to the shader.
	var mat = $ColorRect.material
	mat.set_shader_parameter("view_left", subviewport_left.get_texture())
	mat.set_shader_parameter("view_right", subviewport_right.get_texture())

func _process(delta: float) -> void:

	# Decrement timer.
	seconds_left -= delta

	# Update shader params.
	var mat = $ColorRect.material
	mat.set_shader_parameter("luminance_vs_color", luminance_vs_color)
	mat.set_shader_parameter("color_left", color_left)
	mat.set_shader_parameter("color_right", color_right)

	# Update viewport params.
	subviewport_left.size = get_viewport().size
	subviewport_right.size = get_viewport().size

	# Position cameras, initially copying main camera.
	var boom: Node3D = get_app().get_node("CameraBoom")
	var original_cam: Camera3D = boom.get_node("Camera3D")
	var original_cam_transform: Transform3D = original_cam.global_transform
	var cam_left: Camera3D = subviewport_left.get_node("Camera3D")
	cam_left.global_transform = original_cam_transform
	var cam_right: Camera3D = subviewport_right.get_node("Camera3D")
	cam_right.global_transform = original_cam_transform

	# Move the cameras out sideways in local space.
	var up: Vector3 = original_cam_transform.basis * Vector3(0.0, 1.0, 0.0)
	var left: Vector3 = original_cam_transform.basis * Vector3(1.0, 0.0, 0.0)
	cam_left.transform.origin -= left * ipd/2.0
	cam_right.transform.origin += left * ipd/2.0

	cam_left.transform.basis = cam_left.transform.basis.rotated(up, eye_inward_rotation * PI/180.0)
	cam_right.transform.basis = cam_left.transform.basis.rotated(up, -eye_inward_rotation * PI/180.0)

	# Copy over other camera settings.
	cam_left.fov = original_cam.fov
	cam_left.cull_mask = original_cam.cull_mask
	cam_right.fov = original_cam.fov
	cam_right.cull_mask = original_cam.cull_mask

	# Disable/enable camera and viewer.
	original_cam.current = not _get_enabled()
	$ColorRect.visible = _get_enabled()

func scene_init() -> void:

	# Move subviewports from this object to the camera boom in the main scene.
	remove_child(subviewport_left)
	remove_child(subviewport_right)
	var boom: Node3D = get_app().get_node("CameraBoom")
	boom.add_child(subviewport_left)
	boom.add_child(subviewport_right)

func scene_shutdown() -> void:

	# Move subviewports back into this scene.
	var boom: Node3D = get_app().get_node("CameraBoom")
	boom.remove_child(subviewport_left)
	boom.remove_child(subviewport_right)
	add_child(subviewport_left)
	add_child(subviewport_right)

	# FIXME: Only works if this is the only thing overriding the camera.
	# Otherwise this will cause conflicts with other things trying to disable
	# the main cam.
	var original_cam: Camera3D = boom.get_node("Camera3D")
	original_cam.current = true
