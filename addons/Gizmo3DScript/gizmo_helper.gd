class_name GizmoHelper
extends Node
## A collection of helper methods translated from the C++ Godot source.
## They're required by Gizmo3D but lack binds to GDScript and C#.

## Port of https://github.com/godotengine/godot/blob/master/scene/resources/material.cpp#L2856
static func set_on_top_of_alpha(material: BaseMaterial3D, alpha: bool = false):
	if alpha:
		material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_ALPHA
	else:
		material.transparency = BaseMaterial3D.Transparency.TRANSPARENCY_DISABLED
	material.render_priority = Material.RENDER_PRIORITY_MAX
	material.no_depth_test = true

## Port of https://github.com/godotengine/godot/blob/master/core/math/aabb.cpp#L361
static func get_edge(aabb: AABB, edge: int) -> Array:
	var result : Array[Vector3] = []
	result.resize(2)
	var position = aabb.position
	var size = aabb.size
	match (edge):
		0:
			result[0] = (Vector3(position.x + size.x, position.y, position.z))
			result[1] = (Vector3(position.x, position.y, position.z))
		1:
			result[0] = (Vector3(position.x + size.x, position.y, position.z + size.z))
			result[1] = (Vector3(position.x + size.x, position.y, position.z))
		2:
			result[0] = (Vector3(position.x, position.y, position.z + size.z))
			result[1] = (Vector3(position.x + size.x, position.y, position.z + size.z))
		3:
			result[0] = (Vector3(position.x, position.y, position.z))
			result[1] = (Vector3(position.x, position.y, position.z + size.z))
		4:
			result[0] = (Vector3(position.x, position.y + size.y, position.z))
			result[1] = (Vector3(position.x + size.x, position.y + size.y, position.z))
		5:
			result[0] = (Vector3(position.x + size.x, position.y + size.y, position.z))
			result[1] = (Vector3(position.x + size.x, position.y + size.y, position.z + size.z))
		6:
			result[0] = (Vector3(position.x + size.x, position.y + size.y, position.z + size.z))
			result[1] = (Vector3(position.x, position.y + size.y, position.z + size.z))
		7:
			result[0] = (Vector3(position.x, position.y + size.y, position.z + size.z))
			result[1] = (Vector3(position.x, position.y + size.y, position.z))
		8:
			result[0] = (Vector3(position.x, position.y, position.z + size.z))
			result[1] = (Vector3(position.x, position.y + size.y, position.z + size.z))
		9:
			result[0] = (Vector3(position.x, position.y, position.z))
			result[1] = (Vector3(position.x, position.y + size.y, position.z))
		10:
			result[0] = (Vector3(position.x + size.x, position.y, position.z))
			result[1] = (Vector3(position.x + size.x, position.y + size.y, position.z))
		11:
			result[0] = (Vector3(position.x + size.x, position.y, position.z + size.z))
			result[1] = (Vector3(position.x + size.x, position.y + size.y, position.z + size.z))
	return result

## Port of https://github.com/godotengine/godot/blob/master/core/math/basis.cpp#L262
static func scaled_orthogonal(basis: Basis, scale: Vector3) -> Basis:
	var s = Vector3(-1, -1, -1) + scale
	var sign = (s.x + s.y + s.z) < 0
	var b = basis.orthonormalized()
	s *= b
	var dots = Vector3.ZERO
	for i in range(3):
		for j in range(3):
			dots[j] += s[i] * abs(basis[i].normalized().dot(b[j]))
	if sign != ((dots.x + dots.y + dots.z) < 0):
		dots = -dots
	basis *= Basis.from_scale(Vector3.ONE + dots)
	return basis
