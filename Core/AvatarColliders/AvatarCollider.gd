extends BoneAttachment3D
class_name AvatarCollider

enum ShapeType { NONE, SPHERE, CAPSULE, CYLINDER, BOX }

const COLOR_ENABLED  := Color8(128, 0, 0)
const COLOR_DISABLED := Color8(124, 124, 124)
const COLOR_SELECTED := Color8(0, 128, 0)

const MATERIAL := preload("res://Core/AvatarColliders/AvatarColliderEditorMaterial.tres")

var body: CharacterBody3D:
	get: return $CharacterBody3D
var shape: Shape3D:
	get: return $CharacterBody3D/CollisionShape3D.shape
	set(value): $CharacterBody3D/CollisionShape3D.shape = value

var mesh_instance: MeshInstance3D:
	get: return $CharacterBody3D/MeshInstance3D
var mesh: PrimitiveMesh:
	get: return mesh_instance.mesh
	set(value): mesh_instance.mesh = value

var shape_type: ShapeType:
	get:
		if   shape is SphereShape3D:   return ShapeType.SPHERE
		elif shape is CapsuleShape3D:  return ShapeType.CAPSULE
		elif shape is CylinderShape3D: return ShapeType.CYLINDER
		elif shape is BoxShape3D:      return ShapeType.BOX
		else:                          return ShapeType.NONE

var enabled: bool = true:
	set(value): enabled = value; _update_enabled(); _update_color()
var selected: bool = false:
	set(value): selected = value; _update_color()

func _update_enabled() -> void:
	body.collision_layer = 1 if enabled else 0
	body.collision_mask  = 2 if enabled else 0
func _update_color() -> void:
	var color = COLOR_SELECTED if selected else COLOR_ENABLED if enabled else COLOR_DISABLED
	mesh_instance.set_instance_shader_parameter("color", color)

## Whether the collider originated from the VRM.
var from_vrm := false


func load_settings(settings: Dictionary) -> void:
	bone_name = settings["bone_name"]

	var pos: Array = settings.get("position", [ 0.0, 0.0, 0.0 ])
	body.position = Vector3(pos[0], pos[1], pos[2])
	var rot: Array = settings.get("rotation", [ 0.0, 0.0, 0.0 ])
	body.rotation_degrees = Vector3(rot[0], rot[1], rot[2])

	var shape_type_str: String = settings.get("shape", "SPHERE")
	var new_shape_type: ShapeType = ShapeType.get(shape_type_str)
	match new_shape_type:
		ShapeType.SPHERE:
			if shape is not SphereShape3D:
				shape = SphereShape3D.new()
				mesh  = SphereMesh.new()
				mesh.material = MATERIAL
				shape.changed.connect(func():
					mesh.radius = shape.radius
					mesh.height = shape.radius * 2.0)

			shape.radius = settings.get("radius", 0.1)

		ShapeType.CAPSULE:
			if shape is not CapsuleShape3D:
				shape = CapsuleShape3D.new()
				mesh  = CapsuleMesh.new()
				mesh.material = MATERIAL
				shape.changed.connect(func():
					mesh.radius = shape.radius
					mesh.height = shape.height)

			shape.radius = settings.get("radius", 0.1)
			shape.height = settings.get("height", 0.4)

		ShapeType.CYLINDER:
			if shape is not CylinderShape3D:
				shape = CylinderShape3D.new()
				mesh  = CylinderMesh.new()
				mesh.material = MATERIAL
				shape.changed.connect(func():
					mesh.top_radius    = shape.radius
					mesh.bottom_radius = shape.radius
					mesh.height        = shape.height)

			shape.radius = settings.get("radius", 0.1)
			shape.height = settings.get("height", 0.4)

		ShapeType.BOX:
			if shape is not BoxShape3D:
				shape = BoxShape3D.new()
				mesh  = BoxMesh.new()
				mesh.material = MATERIAL
				shape.changed.connect(func():
					mesh.size = shape.size)

			var size: Array = settings.get("size", [ 0.2, 0.2, 0.2 ])
			shape.size = Vector3(size[0], size[1], size[2])

	enabled  = settings.get("enabled", true)
	from_vrm = settings.get("from_vrm", false)

func save_settings() -> Dictionary:
	var result: Dictionary
	result["bone_name"] = bone_name

	var pos := body.position
	var rot := body.rotation_degrees
	if pos != Vector3.ZERO: result["position"] = [ pos.x, pos.y, pos.z ]
	if rot != Vector3.ZERO: result["rotation"] = [ rot.x, rot.y, rot.z ]

	result["shape"] = ShapeType.keys()[shape_type]
	match shape_type:
		ShapeType.SPHERE:
			result["radius"] = shape.radius
		ShapeType.CAPSULE:
			result["radius"] = shape.radius
			result["height"] = shape.height
		ShapeType.CYLINDER:
			result["radius"] = shape.radius
			result["height"] = shape.height
		ShapeType.BOX:
			result["size"] = [ shape.size.x, shape.size.y, shape.size.z ]

	if not enabled: result["enabled"] = false
	if from_vrm: result["from_vrm"] = true

	return result
