@tool
extends SkeletonModifier3D
class_name KiriPoleTargetModifier3D

## Root bone name.
@export_enum(" ") var root_bone: String = ""
@export_enum(" ") var target_bone: String = ""
@export var pole_target_node: NodePath

## Relative rotation to add to offset the pole angle. Use this to compensate if
## the pole target is inteded to use a different axis than the bone's local X
## axis.
@export_range(-180.0, 180.0, 0.1, "radians_as_degrees") var angle_offset: float = 0.0

## Add a debug line. Takes coordinates in skeleton space.
func _add_debug_line(start: Vector3, end: Vector3, color: Color = Color(1, 1, 1)):
	var debug_mesh: ImmediateMesh = $DebugLines.mesh

	# Convert to world space.
	start = get_skeleton().global_transform * start
	end = get_skeleton().global_transform * end

	# Convert to local space.
	start = global_transform.inverse() * start
	end = global_transform.inverse() * end

	# Add line.
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	debug_mesh.surface_set_color(color)
	debug_mesh.surface_add_vertex(start)
	debug_mesh.surface_add_vertex(end)
	debug_mesh.surface_end()

func _clear_debug_lines():
	var debug_mesh: ImmediateMesh = $DebugLines.mesh
	debug_mesh.clear_surfaces()

func _ready() -> void:
	var debug_mesh_instance: MeshInstance3D = get_node_or_null("DebugLines")
	if debug_mesh_instance == null:
		debug_mesh_instance = MeshInstance3D.new()
		debug_mesh_instance.mesh = ImmediateMesh.new()
		debug_mesh_instance.material_override = ShaderMaterial.new()
		debug_mesh_instance.material_override.shader = preload("res://Core/Materials/debug_mesh.gdshader")
		debug_mesh_instance.name = "DebugLines"
		add_child(debug_mesh_instance)

# Show the bone names as an enum of bones in the skeleton we have attached to.
func _validate_property(property: Dictionary) -> void:
	if property.name == "root_bone" or property.name == "target_bone":
		var skeleton: Skeleton3D = get_skeleton()
		if skeleton:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = skeleton.get_concatenated_bone_names()

func _process_modification_with_delta(delta: float) -> void:

	if not active:
		return

	_do_rotation_update(delta, true)

func _do_rotation_update(_delta: float, actually_do_it: bool) -> void:

	var skel: Skeleton3D = get_skeleton()
	var root_bone_idx: int = skel.find_bone(root_bone)
	var target_bone_idx: int = skel.find_bone(target_bone)
	
	if root_bone_idx == -1 or target_bone_idx == -1:
		return

	if pole_target_node.is_empty():
		return
	
	var root_transform_skeleton_space: Transform3D = \
		skel.get_bone_global_pose(root_bone_idx)
	var root_position_skeleton_space: Vector3 = \
		root_transform_skeleton_space.origin

	# "Pole axis" is the normalized vector going from the root bone to the tip
	# of the chain.
	var pole_axis_skeleton_space: Vector3 = \
		(skel.get_bone_global_pose(target_bone_idx).origin -
		root_position_skeleton_space).normalized()

	#_clear_debug_lines()
	#_add_debug_line(
	#	root_position_skeleton_space,
	#	skel.get_bone_global_pose(target_bone_idx).origin)

	# Convert world-space target object transform to something we can use in
	# skeleton space.
	var pole_target_transform_in_skeleton_space: Transform3D = \
		skel.global_transform.inverse() * \
		get_node(pole_target_node).global_transform

	#_add_debug_line(
	#	(root_position_skeleton_space + skel.get_bone_global_pose(target_bone_idx).origin) / 2.0,
	#	pole_target_transform_in_skeleton_space.origin)

	# Figure out the axes for a coordinate space based on the bone direction and
	# pole axis. This is the coordinate space we'll be doing our rotation in.
	var root_bone_forward_skeleton_space: Vector3 = \
		root_transform_skeleton_space.basis * Vector3(0.0, 0.0, -1.0)
	var pole_space_left_skeleton_space: Vector3 = \
		root_bone_forward_skeleton_space.cross(pole_axis_skeleton_space).normalized()
	var pole_space_forward_skeleton_space: Vector3 = \
		pole_axis_skeleton_space.cross(pole_space_left_skeleton_space).normalized()

	# Now that we've figured out the axes, create a transform to move stuff
	# in/out of this coordinate space ("pole space").
	var pole_space_transform: Basis = Basis(
		pole_space_left_skeleton_space,
		pole_space_forward_skeleton_space,
		pole_axis_skeleton_space).inverse()

	# Get the pole target in our "pole space".
	var pole_target_position_pole_space: Vector3 = pole_space_transform * \
		(pole_target_transform_in_skeleton_space.origin - root_position_skeleton_space)

	# Compute angle offset in our 2D plane (that the pole axis is the normal
	# of).
	var pole_angle: float = atan2(
		-pole_target_position_pole_space.x,
		-pole_target_position_pole_space.y)

	# This is the basis we need to rotate the root bone by.
	var final_root_rotation_skeleton_space: Basis = \
		Basis(pole_axis_skeleton_space, (-pole_angle + angle_offset) * influence)

	# Reconstruct the transform for the root bone so we keep the origin while applying the rotation
	# to the existing orientation.
	var final_root_transform_skeleton_space: Transform3D = \
		skel.get_bone_global_pose(root_bone_idx)
	final_root_transform_skeleton_space.basis = \
		final_root_rotation_skeleton_space * root_transform_skeleton_space.basis

	# Set it.
	if actually_do_it:
		skel.set_bone_global_pose(
			root_bone_idx,
			final_root_transform_skeleton_space)
