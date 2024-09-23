extends BoneAttachment3D
class_name AvatarCollider

var from_vrm : bool = false

func get_enabled():
	var body = $CharacterBody3D
	if body.collision_layer != 0:
		return true
	return false

func set_enabled(new_enabled):
	print(new_enabled)
	if new_enabled:
		$CharacterBody3D.collision_layer = 1
		$CharacterBody3D.collision_mask = 2
	else:
		$CharacterBody3D.collision_layer = 0
		$CharacterBody3D.collision_mask = 0

func get_settings():
	var out_dict = {}
	
	out_dict["bone_name"] = bone_name
	var body_origin = get_node("CharacterBody3D").transform.origin
	
	out_dict["position"] = [
		body_origin[0],
		body_origin[1],
		body_origin[2]]
	
	out_dict["radius"] = $CharacterBody3D/CollisionShape3D.shape.radius
	
	out_dict["from_vrm"] = from_vrm
	
	out_dict["enabled"] = get_enabled()
	
	return out_dict
	
func set_settings(settings_dict):
	
	if "bone_name" in settings_dict:
		bone_name = settings_dict["bone_name"]
	
	if "position" in settings_dict:
		get_node("CharacterBody3D").transform.origin = Vector3(
			settings_dict["position"][0],
			settings_dict["position"][1],
			settings_dict["position"][2])
			
	if "radius" in settings_dict:
		$CharacterBody3D/CollisionShape3D.shape.radius = settings_dict["radius"]
		$CharacterBody3D/MeshInstance3D.mesh.radius = settings_dict["radius"]
		$CharacterBody3D/MeshInstance3D.mesh.height = settings_dict["radius"] * 2.0

	if "enabled" in settings_dict:
		set_enabled(settings_dict["enabled"])
		var surface_material : ShaderMaterial = $CharacterBody3D/MeshInstance3D.get_surface_override_material(0)
		if not settings_dict["enabled"]:
			surface_material.set_shader_parameter("color", Vector3(0.2, 0.2, 0.2))
	
	if "selected" in settings_dict:
		if settings_dict["selected"]:
			var surface_material : ShaderMaterial = $CharacterBody3D/MeshInstance3D.get_surface_override_material(0)
			surface_material.set_shader_parameter("color", Vector3(0.0, 0.5, 0.0))

	if "visible" in settings_dict:
		set_hidden(not settings_dict["visible"])

	if "from_vrm" in settings_dict:
		from_vrm = settings_dict["from_vrm"]

func set_hidden(hidden):
	get_node("CharacterBody3D/MeshInstance3D").visible = not hidden
	
	
	
