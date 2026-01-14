extends Mod_Base

var subviewport_left: SubViewport
var subviewport_right: SubViewport
var ipd: float = 0.0064
var luminance_vs_color: float = 0.5

func _ready() -> void:
	
	add_tracked_setting("ipd", "Inter Pupillary Distance", { "min" : -1.0, "max" : 1.0, "step" : 0.0001 })
	add_tracked_setting("luminance_vs_color", "Luminance vs Color", { "min" : 0.0, "max" : 1.0, "step" : 0.01 })
	
	subviewport_left = $SubViewport_Left
	subviewport_right = $SubViewport_Right

	subviewport_left.world_3d = get_viewport().world_3d
	subviewport_right.world_3d = get_viewport().world_3d

	var mat = $ColorRect.material
	mat.set_shader_parameter("view_left", subviewport_left.get_texture())
	mat.set_shader_parameter("view_right", subviewport_right.get_texture())

func _process(delta: float) -> void:

	var mat = $ColorRect.material
	mat.set_shader_parameter("luminance_vs_color", luminance_vs_color)


	subviewport_left.size = get_viewport().size
	subviewport_right.size = get_viewport().size

	# Position cameras.
	var boom: Node3D = get_app().get_node("CameraBoom")
	var original_cam: Camera3D = boom.get_node("Camera3D")
	var original_cam_transform: Transform3D = original_cam.global_transform
	var cam_left: Camera3D = subviewport_left.get_node("Camera3D")
	cam_left.global_transform = original_cam_transform
	var cam_right: Camera3D = subviewport_right.get_node("Camera3D")
	cam_right.global_transform = original_cam_transform

	#var up: Vector3 = Vector3(0.0, 1.0, 0.0)
	#var forward: Vector3 = original_cam_transform.basis * Vector3(0.0, 0.0, 1.0)
	#var left: Vector3 = up.cross(forward)
	var up: Vector3 = original_cam_transform.basis * Vector3(0.0, 1.0, 0.0)
	var left: Vector3 = original_cam_transform.basis * Vector3(1.0, 0.0, 0.0)

	# FIXME: Add IPD setting.
	cam_left.transform.origin -= left * ipd/2.0
	cam_right.transform.origin += left * ipd/2.0

	# Copy over other camera settings.
	cam_left.fov = original_cam.fov
	cam_left.cull_mask = original_cam.cull_mask
	cam_right.fov = original_cam.fov
	cam_right.cull_mask = original_cam.cull_mask

	original_cam.current = false

func scene_init() -> void:
	remove_child(subviewport_left)
	remove_child(subviewport_right)
	var boom: Node3D = get_app().get_node("CameraBoom")
	boom.add_child(subviewport_left)
	boom.add_child(subviewport_right)
	var original_cam: Camera3D = boom.get_node("Camera3D")
	var original_cam_transform: Transform3D = original_cam.global_transform
	subviewport_left.get_node("Camera3D").global_transform = original_cam_transform
	subviewport_right.get_node("Camera3D").global_transform = original_cam_transform
	original_cam.current = false

func scene_shutdown() -> void:
	var boom: Node3D = get_app().get_node("CameraBoom")
	boom.remove_child(subviewport_left)
	boom.remove_child(subviewport_right)
	add_child(subviewport_left)
	add_child(subviewport_right)
	var original_cam: Camera3D = boom.get_node("Camera3D")
	# FIXME: Only works if this is the only thing overriding the camera.
	original_cam.current = true
