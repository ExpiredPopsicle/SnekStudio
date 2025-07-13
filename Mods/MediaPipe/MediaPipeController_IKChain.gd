extends RefCounted
class_name MediaPipeController_IKChain

# FIXME: We pass this around internally a bunch and don't need to.
var skeleton : Skeleton3D = null
var base_bone : String
var tip_bone : String

var tracker_object : Node = null

var rotation_low : float = 0.1
var rotation_high : float = 2.0 * PI - 0.1

var do_yaw : bool = true
var do_bone_roll : bool = false

var main_axis_of_rotation : Vector3 = Vector3(1.0, 0.0, 0.0)

# If do_yaw is true, then this is the "yaw" rotation axis.
var secondary_axis_of_rotation : Vector3 = Vector3(0.0, 1.0, 0.0)

# Set to 0,0,0 if no pole target.
var pole_direction_target : Vector3 = Vector3(0.0, 0.0, 0.0)
var pole_direction_rotation_object : Node3D = null

var _calculated_distance_to_angle_mappings = null
var _calculated_max_extension_angle = 0.0
var _calculated_min_extension_angle = 2.0 * PI
var _calculated_max_extension_distance = 1.0
var _calculated_min_extension_distance = 0.0

# FIXME: Get rid of these or make them actual config options once everything is
# working.
var do_ik_curve = true
var do_yaw_global = true
var do_point_tracker = true
var do_pole_targets = true
var do_rotate_to_match_tracker = true

var yaw_scale : float = 0.25
var reset_first : bool = true

var symmetric : bool = false
# Local space to the rest position of whatever bone we're working on.
var symmetric_axis : Vector3 = Vector3(1.0, 0.0, 0.0)
var symmetric_influence_scale : float = 2.0
var symmetric_influence_start_offset : float = 1.0

func _debug_print_chain_rotation_mapping(
	skel : Skeleton3D,
	base_bone_index : int,
	tip_bone_index : int):

	# Print a graph of the head-to-hips distances based on spine bone
	# pitches. Find the max extension angle.
	var n = 0.0
	var found_max_extension_angle = 0.0
	var found_max_extension_angle_distance = 0.0
	while n <= PI:
		var dist = attempt_spine_rotation(skel, n, base_bone_index, tip_bone_index)
		var barstr = ""
		var barcounter = 0
		while barcounter < dist:
			barstr += "#"
			barcounter += 0.01
		print("%2f = %f %s" % [n, dist, barstr])
		n += 0.02

		if dist > found_max_extension_angle_distance:
			found_max_extension_angle_distance = dist
			found_max_extension_angle = n

	print("MAX EXTENSION ANGLE: ", found_max_extension_angle)

func rotate_chain_so_tip_points_in_direction(
	skel : Skeleton3D,
	base_bone_index : int,
	tip_bone_index : int,
	target_position_worldspace : Vector3):

	# FIXME: Fix this comment. We're doing more than just hips/head with this function now.
	#
	# We can use "Hips" here, and have it affect the legs as well (pivoting the other way), or
	# we can target the bone right above the hips, along the spine, and only move the upper
	# torso.
	#
	# My model relies on hips rotation for tail flapping in the background, so I'm gonna leave
	# this as "Hips" right now.
	var bone_after_hips = base_bone_index

	# Get *current* hips and head positions.
	var head_world_space = skel.get_global_transform() * skel.get_bone_global_pose(tip_bone_index)
	var hips_world_space = skel.get_global_transform() * skel.get_bone_global_pose(bone_after_hips)

	# Figure out the rotation from the direction the spine is pointing, to the direction to the
	# head tracker.
	var delta_to_tracker = (target_position_worldspace - hips_world_space.origin).normalized()
	var delta_to_head = (head_world_space.origin - hips_world_space.origin).normalized()
	
	var rotation_axis = -delta_to_tracker.cross(delta_to_head).normalized()
	var rotation_angle = acos(delta_to_tracker.dot(delta_to_head))
	var hips_index = bone_after_hips
	var root_index = skel.get_bone_parent(hips_index)
	var hips_transform_worldspace = skel.get_global_transform() * skel.get_bone_global_pose(hips_index)
	hips_transform_worldspace = hips_transform_worldspace.rotated(rotation_axis, rotation_angle)
	var root_transform_worldspace = skel.get_global_transform() * skel.get_bone_global_pose(root_index)
	var new_hips_transform = root_transform_worldspace.inverse() * hips_transform_worldspace
	skel.set_bone_pose_rotation(hips_index, new_hips_transform.basis.get_rotation_quaternion())

func rotate_chain_to_pole_target(
	skel : Skeleton3D,
	base_bone_index : int,
	tip_bone_index : int,
	pole_direction_target_skeleton_space : Vector3):

	# If we have a reference rotation object, use that now.
	if pole_direction_rotation_object:
		var pole_direction_rotation_skeleton_space : Transform3D = \
			skel.global_transform.inverse() * pole_direction_rotation_object.global_transform
		pole_direction_target_skeleton_space = \
			pole_direction_rotation_skeleton_space * pole_direction_target_skeleton_space

	# Get average bone direction.
	var current_bone_index = skel.get_bone_parent(tip_bone_index)
	var total_bone_offset = Vector3(0.0, 0.0, 0.0)
	var base_bone_origin = skel.get_bone_global_pose(base_bone_index).origin
	while current_bone_index != base_bone_index:
		total_bone_offset += skel.get_bone_global_pose(current_bone_index).origin - base_bone_origin
		current_bone_index = skel.get_bone_parent(current_bone_index)
	
	# Get pole direction.
	var pole_direction = \
		skel.get_bone_global_pose(tip_bone_index).origin - \
		skel.get_bone_global_pose(base_bone_index).origin
	
	#if (pole_direction.length() - head_dist_target) > - 0.01:
	if true:
		
		#print(skel.get_bone_name(base_bone_index), " ", pole_direction.length() - head_dist_target)

		pole_direction = pole_direction.normalized()

		# Project average bone displacement onto rotation plane.
		var s = total_bone_offset.normalized().dot(pole_direction)
		var direction_offset = total_bone_offset.normalized() - pole_direction * s
		direction_offset = direction_offset.normalized()
		assert(abs(direction_offset.dot(pole_direction)) < 0.001)
		
		# Project pole target direction onto rotation plane.
		var pole_direction_target_offset = pole_direction_target_skeleton_space - \
			(skel.get_bone_global_pose(base_bone_index).origin + 
			skel.get_bone_global_pose(tip_bone_index).origin) / 2.0
			
		s = pole_direction_target_offset.dot(pole_direction)
		var target_direction_offset = pole_direction_target_offset - pole_direction * s
		target_direction_offset = target_direction_offset.normalized()
		assert(abs(target_direction_offset.dot(pole_direction)) < 0.001)

#			print(skel.get_bone_name(tip_bone_index))
#			print(direction_offset)
#			print(target_direction_offset)
		
		var rotation_direction = sign(direction_offset.cross(target_direction_offset).dot(pole_direction))
		var rotation_amount = acos(direction_offset.dot(target_direction_offset))

		var parent_space = skel.get_bone_global_pose(skel.get_bone_parent(base_bone_index)).basis
		
		# Find second-to-last bone.
#			current_bone_index = tip_bone_index
#			while skel.get_bone_parent(current_bone_index) != base_bone_index:
#				current_bone_index = skel.get_bone_parent(current_bone_index)
		current_bone_index = base_bone_index
			
		var new_global_pose = \
			skel.get_bone_global_pose(current_bone_index).basis.rotated(pole_direction, rotation_amount * rotation_direction)
		skel.set_bone_pose_rotation(current_bone_index, (parent_space.inverse() * new_global_pose))



func chain_distribute_bone_roll(
	base_bone_index : int,
	tip_bone_index : int):

	# Count up bones.
	var bone_count = 1
	var current_bone = skeleton.get_bone_parent(tip_bone_index)
	while current_bone != -1 and current_bone != base_bone_index:
		bone_count += 1
		current_bone = skeleton.get_bone_parent(current_bone)

	# Determine the bone roll axis for tip bone by averaging out all the child
	# positions and using that as a bone direction.
	var tip_bone_roll_axis = Vector3(0.0, 0.0, 0.0)
	var tip_bone_children = skeleton.get_bone_children(tip_bone_index)
	for tip_bone_child in tip_bone_children:
		tip_bone_roll_axis += skeleton.get_bone_rest(tip_bone_child).origin
	tip_bone_roll_axis = tip_bone_roll_axis.normalized()

	var current_tip_rotation : Quaternion = \
		skeleton.get_bone_rest(tip_bone_index).basis.get_rotation_quaternion().inverse() * \
		skeleton.get_bone_pose_rotation(tip_bone_index)

	# This is us trying to narrow down the roll component out of the entire
	# rotation by using the dot product of the two axes of rotation as a scaling
	# value for the angle.
	var tip_roll = \
		lerp_angle(
			0.0,
			current_tip_rotation.get_angle(),
			tip_bone_roll_axis.dot(current_tip_rotation.get_axis()))
	
	var bone_chain_index = bone_count
	
	current_bone = skeleton.get_bone_parent(tip_bone_index)
	while current_bone != -1:
		
		bone_chain_index -= 1
		
		var avg_child_direction = Vector3(0.0, 0.0, 0.0)
		
		# Save child bone rotations in parent-parent space.
		var this_parent_index = skeleton.get_bone_parent(current_bone)
		var child_indices = skeleton.get_bone_children(current_bone)
		var this_bone_starting_rotation = skeleton.get_bone_pose_rotation(current_bone)
		var preserved_rotations_in_parent_space = []
		for child in child_indices:
			var child_bone_rotation = skeleton.get_bone_pose_rotation(child)
			preserved_rotations_in_parent_space.append(
				this_bone_starting_rotation * child_bone_rotation)
				
			avg_child_direction += skeleton.get_bone_rest(child).origin
		
		avg_child_direction = avg_child_direction.normalized()
		
		# Rotate the actual bone.
		var rotation_alpha = float(bone_chain_index) / float(bone_count)
		var new_rotation = \
			this_bone_starting_rotation * \
			Quaternion(avg_child_direction, tip_roll * rotation_alpha)
		skeleton.set_bone_pose_rotation(current_bone, new_rotation)

		# Set all the children back.
		var child_index = 0
		var new_bone_rotation = skeleton.get_bone_pose_rotation(current_bone)
		for child in child_indices:
			var new_child_bone_rotation = \
				new_bone_rotation.inverse() * \
				preserved_rotations_in_parent_space[child_index]
			skeleton.set_bone_pose_rotation(child, new_child_bone_rotation)
			
			child_index += 1
		
		if current_bone == base_bone_index:
			break
		current_bone = this_parent_index

func rotate_chain_twist_on_secondary_axis(
	skel : Skeleton3D,
	base_bone_index : int,
	tip_bone_index : int,
	target_transform_worldspace : Transform3D,
	forward_axis_for_secondary_rotation : Vector3,
	rotation_scale : float):
	
	#var forward_axis_for_secondary_rotation : Vector3 = Vector3(0.0, 0.0, 1.0)

	# Count up how many bones we're going to need to distribute this among.
	var bone_count_to_hips = 0
	var current_bone_index = tip_bone_index
	while current_bone_index != -1 and current_bone_index != base_bone_index:
		current_bone_index = skel.get_bone_parent(current_bone_index)
		bone_count_to_hips += 1

	# Figure out angle difference between the direction where the hips are
	# facing and the direction the head is facing.
	var hips_forward_skelspace = skel.get_bone_global_pose(base_bone_index).basis * forward_axis_for_secondary_rotation
	var head_forward_skelspace = skel.global_transform.basis.inverse() * target_transform_worldspace.basis * forward_axis_for_secondary_rotation
	hips_forward_skelspace.y = 0.0
	hips_forward_skelspace = hips_forward_skelspace.normalized()
	head_forward_skelspace.y = 0.0
	head_forward_skelspace = head_forward_skelspace.normalized()

	# Figure out how many radians we're off. We're actually not projecting the directions onto
	# the the same plane and comparing there because we just don't have to be as precise for
	# this one.
	var radians_to_rotate_body = \
		sign(secondary_axis_of_rotation.dot(head_forward_skelspace.cross(hips_forward_skelspace))) * \
		-acos(hips_forward_skelspace.dot(head_forward_skelspace))

	# Scale rotation amount for body.
	# FIXME: Make configurable.
	# TODO: Make it configurable.
	radians_to_rotate_body *= rotation_scale

	# Go from the head down to the hips and apply an even fraction of the rotation (distributing
	# the rotation among all the bones between head and hips).
	current_bone_index = tip_bone_index
	while current_bone_index != -1 and current_bone_index != base_bone_index:

		var bone_transform_current = skel.get_bone_global_pose(current_bone_index)
		bone_transform_current = bone_transform_current.rotated(
			secondary_axis_of_rotation,
			radians_to_rotate_body / bone_count_to_hips)

		var parent_bone_transform = skel.get_bone_global_pose(skel.get_bone_parent(current_bone_index))
		skel.set_bone_pose_rotation(current_bone_index, (parent_bone_transform.inverse() * bone_transform_current).basis.get_rotation_quaternion())

		current_bone_index = skel.get_bone_parent(current_bone_index)

func rotate_bone_to_match_object(
	skel : Skeleton3D, tip_bone_index : int,
	target_transform_worldspace : Transform3D):
	
	var head_index = tip_bone_index
	var neck_index = skel.get_bone_parent(head_index)
	var neck_transform = skel.get_global_transform() * skel.get_bone_global_pose(neck_index)

	var new_head_transform = \
		neck_transform.inverse() * \
		target_transform_worldspace * \
		(skel.transform * skel.get_bone_global_rest(head_index))

	skel.set_bone_pose_rotation(
		head_index,
		new_head_transform.basis.get_rotation_quaternion())

func do_ik_chain():

	if not is_instance_valid(skeleton):
		return

	var target_transform : Transform3D = \
		tracker_object.global_transform
	
	if _calculated_distance_to_angle_mappings == null:	
		evaluate_bone_chain_limit()
	
	var base_bone_index = skeleton.find_bone(base_bone)
	var tip_bone_index = skeleton.find_bone(tip_bone)
	var current_bone_index = tip_bone_index

	# Reset all rotations.
	if reset_first:
		while current_bone_index != -1:
			skeleton.reset_bone_pose(current_bone_index)
			current_bone_index = skeleton.get_bone_parent(current_bone_index)
		
			if current_bone_index == base_bone_index:
				break
	
	if do_ik_curve:

		var hips_global = skeleton.global_transform * skeleton.get_bone_global_pose(base_bone_index).origin
		var head_tracker_global = target_transform.origin

		var head_dist_target : float = (hips_global - head_tracker_global).length()

		var best_angle : float = _calculated_max_extension_angle
		
		if head_dist_target <= _calculated_min_extension_distance:
			best_angle = _calculated_min_extension_angle
		elif head_dist_target >= _calculated_max_extension_distance:
			best_angle = _calculated_max_extension_angle
		else:
			for k in range(0, len(_calculated_distance_to_angle_mappings) - 1):
				var dist_high = _calculated_distance_to_angle_mappings[k+1][0]
				var dist_low = _calculated_distance_to_angle_mappings[k][0]
				if dist_low >= head_dist_target and \
					dist_high <= head_dist_target:
					
					var alpha = (head_dist_target - dist_low) / (dist_high - dist_low)
					
					best_angle = lerp(
						_calculated_distance_to_angle_mappings[k][1],
						_calculated_distance_to_angle_mappings[k+1][1],
						alpha)
					
					break
					

		if symmetric:
			var global_symmetric_axis : Vector3 = skeleton.global_transform.basis * skeleton.get_bone_global_pose(base_bone_index).basis * symmetric_axis
			var global_symmetry_check_point : Vector3 = head_tracker_global - hips_global
			var dp = global_symmetric_axis.dot(global_symmetry_check_point)
			best_angle *= -dp * symmetric_influence_scale
			#var symmetric_influence_start_offset : float = -1.0

		attempt_spine_rotation(
			skeleton, best_angle,
			base_bone_index,
			tip_bone_index)

	# -----------------------------------------------------------------------------------------
	# Simpler approach attempt

#		var max_dist_angle = 0.0
#		var min_dist_angle = PI
#		var max_dist = attempt_spine_rotation(max_dist_angle, base_bone_index, tip_bone_index)
#		var min_dist = attempt_spine_rotation(min_dist_angle, base_bone_index, tip_bone_index)
#
#		var lerp_alpha = (head_dist_target - min_dist) / (max_dist - min_dist)
#		lerp_alpha = clamp(lerp_alpha, 0.0, 1.0)
#		var use_angle = lerp(max_dist_angle, min_dist_angle, 1.0 - lerp_alpha)
#		attempt_spine_rotation(use_angle, base_bone_index, tip_bone_index)

	
	# -----------------------------------------------------------------------------------------
	# Yaw chest to head orientation

	if do_yaw and do_yaw_global:
		rotate_chain_twist_on_secondary_axis(
			skeleton, base_bone_index, tip_bone_index,
			target_transform,
			Vector3(0.0, 0.0, 1.0), yaw_scale)

	# -----------------------------------------------------------------------------------------
	# Rotate whole spine section to point towards the head tracker.
	
	if do_point_tracker:
		rotate_chain_so_tip_points_in_direction(skeleton, base_bone_index, tip_bone_index, target_transform.origin)

	# -----------------------------------------------------------------------------------------
	# Aim at pole target

	if do_pole_targets:
		if pole_direction_target != Vector3(0.0, 0.0, 0.0):	
			rotate_chain_to_pole_target(skeleton, base_bone_index, tip_bone_index, pole_direction_target)

	# -----------------------------------------------------------------------------------------
	# Rotate the head to face the same direction as the head tracker.
	#
	# We have to do this after everything else so the transform of the bone below it is already
	# fully calculated and finalized.

	if do_rotate_to_match_tracker:
		rotate_bone_to_match_object(skeleton, tip_bone_index, target_transform)

	if do_bone_roll:
		chain_distribute_bone_roll(base_bone_index, tip_bone_index)


# This function will rotate a bone in the global (skeleton object) coordiate
# space, as though it were in its rest position. So hardcoded Y axis can be
# used for elbow, hardcoded X axis can be used for spine, etc.
func rotate_bone_in_global_space(
	skel : Skeleton3D,
	bone_index : int,
	axis : Vector3,
	angle : float):

	var parent_bone_index = skel.get_bone_parent(bone_index)	
	var gs_rotation = Basis(axis.normalized(),  angle).get_rotation_quaternion()
	var gs_rotation_parent = skel.get_bone_global_rest(parent_bone_index).basis.get_rotation_quaternion()
	var gs_rotation_rest = skel.get_bone_global_rest(bone_index).basis.get_rotation_quaternion()
	var bs_rotation = gs_rotation_parent.inverse() * gs_rotation * gs_rotation_rest
	skel.set_bone_pose_rotation(
		bone_index,
		bs_rotation)

func attempt_spine_rotation(
	skel : Skeleton3D,
	rotation_amount, base_bone_index,
	tip_bone_index):
		
	var current_bone_index = tip_bone_index
	var first_bone = current_bone_index
	var last_bone = current_bone_index
	
	# Count up bones so we can evenly distribute the rotation out among all of
	# them.
	var bone_count = 0
	while current_bone_index != -1 and current_bone_index != base_bone_index:
		bone_count += 1
		current_bone_index = skel.get_bone_parent(current_bone_index)
	current_bone_index = tip_bone_index

	# Switch over to per-bone rotation amount.
	rotation_amount /= bone_count
	
	while current_bone_index != -1 and current_bone_index != base_bone_index:
		rotate_bone_in_global_space(skel, current_bone_index, main_axis_of_rotation, rotation_amount)
		current_bone_index = skel.get_bone_parent(current_bone_index)
		last_bone = current_bone_index
	
	# FIXME: Make this a normal error (non-compliant model).
	assert(last_bone == base_bone_index)
	
	var head_dist = \
		(skel.get_bone_global_pose(first_bone).origin -
		skel.get_bone_global_pose(last_bone).origin).length()
	
	return head_dist
		
func evaluate_bone_chain_limit():
	
	var base_bone_index = skeleton.find_bone(base_bone)
	var tip_bone_index = skeleton.find_bone(tip_bone)
	
	var n = rotation_low
	
	var found_max_extension_angle = 0.0
	var found_max_extension_angle_distance = 0.0
	
	var found_min_extension_angle = 0.0
	var found_min_extension_angle_distance = 99999999.0
	
	var output_mapping = []
	
	var sample_count = 64.0
	
	while n <= rotation_high:
		var dist = attempt_spine_rotation(
			skeleton, n, base_bone_index,
			tip_bone_index)
		
#		# Debug display.
#		var barstr = ""
#		var barcounter = 0
#		while barcounter < dist:
#			barstr += "#"
#			barcounter += 0.02
#		print("%2f = %f %s" % [n, dist, barstr])

		n += (rotation_high - rotation_low) / sample_count

		if dist > found_max_extension_angle_distance:
			found_max_extension_angle_distance = dist
			found_max_extension_angle = n
			
		if dist < found_min_extension_angle_distance:
			found_min_extension_angle_distance = dist
			found_min_extension_angle = n
			
	# Go through an resample the entire curve given the min/max range that we now know.
	for i in range(0, sample_count):
		var a = float(i) / float(sample_count)
		var angle = lerp(found_max_extension_angle, found_min_extension_angle, a)
		
		var dist = attempt_spine_rotation(
			skeleton, angle, base_bone_index,
			tip_bone_index)
		output_mapping.append( [dist, angle] )
	
	# Sanity check.
	for k in range(1, len(output_mapping)):
		if output_mapping[k-1][0] < output_mapping[k][0]:
			# FIXME: Normal error message.
			print("BAD SAMPLES")

	_calculated_distance_to_angle_mappings = output_mapping
	_calculated_max_extension_angle = found_max_extension_angle
	_calculated_min_extension_angle = found_min_extension_angle
	_calculated_max_extension_distance = found_max_extension_angle_distance
	_calculated_min_extension_distance = found_min_extension_angle_distance

	if symmetric:
		_calculated_max_extension_distance += symmetric_influence_start_offset

	return [ 
		found_max_extension_angle, found_max_extension_angle_distance,
		found_min_extension_angle, found_min_extension_angle_distance, output_mapping ]

# Reset every bone in a bone chain, inclusive of both tip and base bones, to its
# resting pose.
func reset_bone_chain(
	skel : Skeleton3D,
	base_bone_index, tip_bone_index):

	if base_bone_index is String:
		base_bone_index = skel.find_bone(base_bone_index)
	if tip_bone_index is String:
		tip_bone_index = skel.find_bone(tip_bone_index)

	var current_bone_index = tip_bone_index
	while current_bone_index != -1:

		skel.reset_bone_pose(current_bone_index)		

		if current_bone_index == base_bone_index:
			break
		
		current_bone_index = skel.get_bone_parent(current_bone_index)
