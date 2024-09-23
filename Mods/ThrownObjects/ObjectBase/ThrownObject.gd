extends RigidBody3D
class_name ThrownObject

@export var sticky : bool = true
@export var stickiness_chance : float = 0.5
@export var remaining_lifetime : float = 10.0
@export var stickiness_time : float = 5.0
@export var collision_sound : AudioStream = null
@export var collision_force : float = 1.0

# Sprite-specific settings.
@export var sprite_frames : Array[Texture] = []
@export var sprite_frames_after_impact : Array[Texture] = []
@export var sprite_frame_time : float = 0.1
@export var sprite_uniform_scale : float = 0.5
@export var sprite_destroy_after_impact : bool = false

var _animation_time = 0.0
var attached_to_body = false
var _orig_parent = null
var _impacted = false

var thrower = null

# Use this to select pre-or-post-impact animation automatically.
func _get_active_sprite_array():
	var sprite_array_to_use = sprite_frames
	if _impacted and len(sprite_frames_after_impact) > 0:
		sprite_array_to_use = sprite_frames_after_impact
	return sprite_array_to_use

func _update_sprite_texture(delta):
	_animation_time += delta
	
	var sprite_array_to_use = _get_active_sprite_array()
	
	# Select animation frame or hide the element entirely if there is nothing to
	# show.
	if sprite_array_to_use.size() > 0:
		var frame_number = int(floor(_animation_time / sprite_frame_time))
		var selected_frame
		frame_number = frame_number % sprite_array_to_use.size()
		selected_frame = sprite_array_to_use[frame_number]
	
		$Sprite3D.texture = selected_frame
		$Sprite3D.material_override.set_shader_parameter("texture_albedo", selected_frame)
		$Sprite3D.material_override.set_shader_parameter("uniform_scale", sprite_uniform_scale)
	else:
		$Sprite3D.set_visible(false)

	# See if we need to end the animation and make this sprite go away.
	if sprite_destroy_after_impact and _impacted and $Sprite3D.visible:
		if _animation_time >= sprite_frame_time * sprite_array_to_use.size():
			$Sprite3D.set_visible(false)


func _set_physics_active(active : bool):
	
	if not active:
		linear_velocity = Vector3(0.0, 0.0, 0.0)
		angular_velocity = Vector3(0.0, 0.0, 0.0)
		collision_mask = 0
		collision_layer = 0
		set_gravity_scale(0.0)
	
	else:
		collision_mask = 1
		set_gravity_scale(1.0)

func _reattach_to_body(body):
	
	if attached_to_body:
		return
	
	if not (body is CharacterBody3D):
		return
	
	if get_node_or_null("..") is CharacterBody3D:
		return
	
	linear_velocity = Vector3(0.0, 0.0, 0.0)
	angular_velocity = Vector3(0.0, 0.0, 0.0)
	collision_mask = 0
	collision_layer = 0
	
	assert(not _orig_parent)
	_orig_parent = get_node("..")
	var old_global_transform = get_global_transform()
	_orig_parent.call_deferred("remove_child", self)
	body.call_deferred("add_child", self)
	call_deferred("set_global_transform", old_global_transform)
	attached_to_body = true
	
	var old_linear_velocity = \
		old_global_transform.origin - \
		body.get_global_transform().origin
	
	var emitter = get_node_or_null("Particles")
	if emitter:
		emitter.transform.basis = old_global_transform.basis.inverse()
		emitter.emitting = true
		emitter.process_material = $Particles.process_material.duplicate()
		emitter.process_material.direction = old_linear_velocity.normalized()
		emitter.process_material.initial_velocity_min = 1.0 + randf()
		emitter.process_material.initial_velocity_max = emitter.process_material.initial_velocity_min

func _on_RigidBody_body_entered(body):
	
	if attached_to_body:
		return
	
	# Start sound playing.
	$AudioStreamPlayer3D.play()

	var collision_point = global_transform.origin
	var collision_point_extended = global_transform.origin + linear_velocity
	var body_part_pos = body.global_transform.origin - Vector3(0.0, 0.25, 0.0)
	
	var dir1 = (collision_point - body_part_pos).normalized()
	var dir2 = (collision_point_extended - body_part_pos).normalized()
	
	var rotation_axis = dir1.normalized().cross(dir2.normalized())
	var rotation_angle = acos(dir1.dot(dir2)) * 2
	if rotation_angle > 0.5:
		rotation_angle = 0.5
	if rotation_angle < -0.5:
		rotation_angle = -0.5
	
	rotation_angle *= -collision_force
	
	var q = Quaternion(
		rotation_axis.normalized(), rotation_angle)

	if sticky and randf() < stickiness_chance:
		_reattach_to_body(body)
		set_gravity_scale(0.0)
	else:
		# We no longer have to move in a straight line. Enable gravity and just
		# let the projectile fall down.
		set_gravity_scale(1.0)
	
	# FIXME: Don't hardcode head rotation. Make it select the right bone!
	if thrower:
		thrower.add_head_impact_rotation(
			(body.global_transform.inverse() * Transform3D(q)).basis.get_rotation_quaternion())
			
	# If we have a post-impact animation defined, then reset the animation time
	# to the beginning.
	if len(sprite_frames_after_impact):
		_animation_time = 0.0
	
	_impacted = true

func _physics_process(delta):
	
	stickiness_time -= delta
	remaining_lifetime -= delta

	# Just delete it if it's old enough.
	if remaining_lifetime < 0.0:
		queue_free()
	
	# Handle stickiness wearing off.
	if stickiness_time < 0 and _orig_parent:

		stickiness_time = 999.0
		_set_physics_active(true)
		sleeping = false
		
		# Remove us from the character and re-attach us to the original parent.
		var current_global_transform = get_global_transform()
		get_node("..").remove_child(self)
		if is_instance_valid(_orig_parent):
			_orig_parent.add_child(self)
			global_transform = current_global_transform
			_orig_parent = null
		else:
			queue_free()
		
	# Sprites: Figure out the transform of this object relative to the camera's
	# view space.
	var viewport = get_viewport()
	if viewport:
		var camera = get_viewport().get_camera_3d()
		if camera:
			var camera_transform = camera.get_global_transform()
			var my_transform = get_global_transform()
			var my_viewspace_transform = \
				my_transform.inverse() * camera_transform

			# Take the Z axis rotation from that.	
			var rot_angle = my_viewspace_transform.basis.get_euler()[2]
			
			# Set that on the shader.
			$Sprite3D.material_override.set_shader_parameter("rotation", rot_angle)
		
func _process(delta):
	_update_sprite_texture(delta)
	
# Attempt to determine total visible AABB for collision approximations.
func _find_total_aabb(node, indent=""):
	
	if not (node is Node3D):
		return AABB()
		
	var node_transform : Transform3D = node.transform
	
	var aabb : AABB = AABB()
	
	if node is VisualInstance3D and node.visible:
		aabb = node_transform * node.get_aabb()
		
	for child in node.get_children():
		var child_aabb = _find_total_aabb(child, indent + "  ")
		if aabb.size == Vector3(0.0, 0.0, 0.0):
			aabb = child_aabb
		else:
			aabb = aabb.merge(child_aabb)

	return aabb

func _ready():
	
	# Setup audio.
	$AudioStreamPlayer3D.stream = collision_sound
	$AudioStreamPlayer3D.pitch_scale = 1.0 + (randf() * 2.0 - 1.0) * 0.2

	# Give it a little bit of random spin.
	var random_rotation_axis = Vector3(
		(randf() - 0.5) * 2,
		(randf() - 0.5) * 2,
		(randf() - 0.5) * 2).normalized()
	var random_rotation_velocity = randf() * PI * 2.0 * 25.0
	angular_velocity = random_rotation_axis * random_rotation_velocity
	angular_damp = 5.0

	# Setup sprite.
	$Sprite3D.scale = Vector3(
		sprite_uniform_scale, sprite_uniform_scale, sprite_uniform_scale)
	$Sprite3D.material_override = $Sprite3D.material_override.duplicate()

	# Attempt to determine the max AABB of our visual models and use it as a
	# guess for a radius for the sphere collider.
	#
	# FIXME: If we have an AABB maybe we should just do a box collider.
	# FIXME: Work for sprites, too.
	var max_aabb : AABB = _find_total_aabb(self)
	if max_aabb != AABB():
		if $CollisionShape.shape is SphereShape3D:
			var collision_sphere = $CollisionShape.shape.duplicate()
			$CollisionShape.shape = collision_sphere
			var max_dim = max(
				abs(max_aabb.position.x),
				abs(max_aabb.position.y),
				abs(max_aabb.position.x + max_aabb.size.x),
				abs(max_aabb.position.y + max_aabb.size.y))
			collision_sphere.set_radius(max_dim)

	
