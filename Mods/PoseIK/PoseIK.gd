extends Mod_Base
class_name Mod_PoseIK

var lean_scale : float = 4.0
var chest_yaw_scale : float = 0.3
# FIXME: Add settings for all of these.
var do_hands : bool = true
var lock_fingers_to_single_axis_of_rotation : bool = false # FIXME: only false for thumb
var lock_fingers_to_z_axis : bool = true
var debug_visible_hand_trackers : bool = false
var hack_reset_hips_every_frame : bool = true
var hack_reset_shoulders_every_frame : bool = true
var hip_adjustment_speed : float = 1.0
var head_vertical_offset : float = -0.2
var hips_vertical_blend_speed : float = 6.0

# FIXME: This should be a dictionary.
var _ikchains_dict : Dictionary = {
	"arm_left" : null,
	"arm_right" : null,
	"spine" : null
}

var hand_landmarks_left : Array = []
var hand_landmarks_right : Array = []

var _init_complete = false

# landmark_index_start/end corresponds to the index in the diagram here:
#   https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker
const finger_bone_array_array : Array[Array] = [
	[
		{
			"bone_name_current" : "IndexProximal",
			"landmark_index_start" : 5,
			"landmark_index_end"  : 6,
			"bone_name_next" : "IndexIntermediate",
			"bone_name_parent_of_next" : "IndexProximal"
		},
		{
			"bone_name_current" : "IndexIntermediate",
			"landmark_index_start" : 6,
			"landmark_index_end"  : 7,
			"bone_name_next" : "IndexDistal",
			"bone_name_parent_of_next" : "IndexIntermediate"
		},
		{
			"bone_name_current" : "IndexDistal",
			"landmark_index_start" : 7,
			"landmark_index_end"  : 8,
			"bone_name_next" : "IndexDistal",
			"bone_name_parent_of_next" : "IndexIntermediate"
		}
	],
	[
		{
			"bone_name_current" : "MiddleProximal",
			"landmark_index_start" : 9,
			"landmark_index_end"  : 10,
			"bone_name_next" : "MiddleIntermediate",
			"bone_name_parent_of_next" : "MiddleProximal"
		},
		{
			"bone_name_current" : "MiddleIntermediate",
			"landmark_index_start" : 10,
			"landmark_index_end"  : 11,
			"bone_name_next" : "MiddleDistal",
			"bone_name_parent_of_next" : "MiddleIntermediate"
		},
		{
			"bone_name_current" : "MiddleDistal",
			"landmark_index_start" : 11,
			"landmark_index_end"  : 12,
			"bone_name_next" : "MiddleDistal",
			"bone_name_parent_of_next" : "MiddleIntermediate"
		}
	],
	[
		{
			"bone_name_current" : "RingProximal",
			"landmark_index_start" : 13,
			"landmark_index_end"  : 14,
			"bone_name_next" : "RingIntermediate",
			"bone_name_parent_of_next" : "RingProximal"
		},
		{
			"bone_name_current" : "RingIntermediate",
			"landmark_index_start" : 14,
			"landmark_index_end"  : 15,
			"bone_name_next" : "RingDistal",
			"bone_name_parent_of_next" : "RingIntermediate"
		},
		{
			"bone_name_current" : "RingDistal",
			"landmark_index_start" : 15,
			"landmark_index_end"  : 16,
			"bone_name_next" : "RingDistal",
			"bone_name_parent_of_next" : "RingIntermediate"
		}
	],
	[
		{
			"bone_name_current" : "LittleProximal",
			"landmark_index_start" : 17,
			"landmark_index_end"  : 18,
			"bone_name_next" : "LittleIntermediate",
			"bone_name_parent_of_next" : "LittleProximal"
		},
		{
			"bone_name_current" : "LittleIntermediate",
			"landmark_index_start" : 18,
			"landmark_index_end"  : 19,
			"bone_name_next" : "LittleDistal",
			"bone_name_parent_of_next" : "LittleIntermediate"
		},
		{
			"bone_name_current" : "LittleDistal",
			"landmark_index_start" : 19,
			"landmark_index_end"  : 20,
			"bone_name_next" : "LittleDistal",
			"bone_name_parent_of_next" : "LittleIntermediate"
		}
	],
	[
		# FIXME: Metacarpal *origin* needs to change relative to hand as well.
		{
			"bone_name_current" : "ThumbMetacarpal",
			"landmark_index_start" : 1,
			"landmark_index_end"  : 2,
			"bone_name_next" : "ThumbProximal",
			"bone_name_parent_of_next" : "ThumbMetacarpal"
		},
		{
			"bone_name_current" : "ThumbProximal",
			"landmark_index_start" : 2,
			"landmark_index_end"  : 3,
			"bone_name_next" : "ThumbDistal",
			"bone_name_parent_of_next" : "ThumbProximal"
		},
		{
			"bone_name_current" : "ThumbDistal",
			"landmark_index_start" : 3,
			"landmark_index_end"  : 4,
			"bone_name_next" : "ThumbDistal",
			"bone_name_parent_of_next" : "ThumbProximal"
		},
	]
]


func _clear_ik_chains() -> void:
	for key in _ikchains_dict.keys():
		_ikchains_dict[key] = null

func _ready() -> void:

	add_setting_group("advanced", "Advanced")

	add_tracked_setting(
		"lean_scale", "Lean Scale",
		{ "min" : -6.0, "max" : 6.0 },
		"advanced")

	add_tracked_setting(
		"chest_yaw_scale", "Chest Yaw Rotation Scale",
		{ "min" : -4.0, "max" : 4.0 },
		"advanced")

	add_tracked_setting(
		"debug_visible_hand_trackers", "Debug: Visible hand trackers", {},
		"advanced")

	add_tracked_setting(
		"hack_reset_hips_every_frame",
		"Hack: Reset hips every frame (prevent drift)", {},
		"advanced")

	add_tracked_setting(
		"hack_reset_shoulders_every_frame",
		"Hack: Reset shoulders every frame (prevent shoulder drift)", {},
		"advanced")

	add_tracked_setting(
		"head_vertical_offset", "Head vertical offset",
		{ "min" : -1.0, "max" : 1.0 },
		"advanced")
	add_tracked_setting(
		"hips_vertical_blend_speed", "Hips vertical blend speed",
		{ "min" : 0.0, "max" : 20.0 },
		"advanced")
	add_tracked_setting(
		"hip_adjustment_speed", "Hip Adjustment Speed", { "min" : 0.0, "max" : 10.0 },
		"advanced")

	_reinit()

func scene_init() -> void:
	_reinit()

func scene_shutdown() -> void:
	_init_complete = false
	_clear_ik_chains()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	_reinit()
	_init_complete = true

func load_before(_settings_old : Dictionary, _settings_new : Dictionary):
	_init_complete = false
	_clear_ik_chains()

func _update_local_trackers() -> void:

	var tracker_dict : Dictionary = get_global_mod_data("trackers")

	if tracker_dict.has("head"):
		$Head.global_transform = tracker_dict["head"].transform
	if tracker_dict.has("hand_left"):
		$Hand_Left.global_transform = tracker_dict["hand_left"].transform
	if tracker_dict.has("hand_right"):
		$Hand_Right.global_transform = tracker_dict["hand_right"].transform

	# https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker
	var mediapipe_hand_landmark_names : Array = [
		"wrist",

		"thumb_cmc", # carpometacarpal
		"thumb_mcp", # metacarpal
		"thumb_ip", # interphalangeal
		"thumb_tip", # tip

		"index_finger_mcp",
		"index_finger_pip", # proximal something something
		"index_finger_dip", # distal something something
		"index_finger_tip",

		"middle_finger_mcp",
		"middle_finger_pip",
		"middle_finger_dip",
		"middle_finger_tip",

		"ring_finger_mcp",
		"ring_finger_pip",
		"ring_finger_dip",
		"ring_finger_tip",

		"pinky_finger_mcp",
		"pinky_finger_pip",
		"pinky_finger_dip",
		"pinky_finger_tip",
	]

	for side : String in [ "left", "right" ]:

		var tracker : Node3D;
		if side == "left":
			tracker = $Hand_Left
		else:
			tracker = $Hand_Right

		if tracker_dict.has("finger_positions"):
			for landmark_index : int in range(0, len(mediapipe_hand_landmark_names)):
				if tracker.get_child_count() > landmark_index:
					var finger_tracker : Node3D = tracker.get_child(landmark_index)
					var landmark_name : String = side + "_" + mediapipe_hand_landmark_names[landmark_index]
					#print(landmark_name, " = ", tracker_dict["finger_positions"][landmark_name])
					if landmark_name in tracker_dict["finger_positions"]:
						finger_tracker.global_transform.origin = tracker_dict["finger_positions"][landmark_name]

func _process(delta : float) -> void:

	if not _init_complete:
		return

	var tracker_dict : Dictionary = get_global_mod_data("trackers")
	var skel : Skeleton3D = get_skeleton()
	var model_root : Node3D = get_model()

	if not tracker_dict.has("head"):
		return

	# ---------------------------------------------------------------------------------------------
	# Update this mod's tracker instances

	_update_local_trackers()

	# Hack to fix hips drift.
	if hack_reset_hips_every_frame:
		var hips_index : int = skel.find_bone("Hips")
		if hips_index != -1:
			skel.reset_bone_pose(hips_index)

	# Hack to fix shoulder drift.
	if hack_reset_shoulders_every_frame:
		var bone_index : int = skel.find_bone("LeftShoulder")
		if bone_index != -1:
			skel.reset_bone_pose(bone_index)
		bone_index = skel.find_bone("RightShoulder")
		if bone_index != -1:
			skel.reset_bone_pose(bone_index)

	# FIXME: Hack.
	# This just moves the body based on the head position.
	var head_pos = $Head.transform.origin
	var model_pos = model_root.transform.origin
	
	if true: # FIXME: ???????
		model_root.transform.origin = model_pos.lerp(head_pos, delta * hip_adjustment_speed)
		#model_root.transform.origin = head_pos
		#model_root.transform.origin.y = model_y 
		#model_root.transform.origin.y = lerp(model_pos.y, head_pos.y - 1.9, 0.01)
		
		# FIXME: Another hack!
		var head_rest_transform = get_skeleton().get_bone_global_rest(
			get_skeleton().find_bone("Head"))
		#print(head_rest_transform.origin.y)
		
		# FIXME: Hard-coded fudge factor.
		# FIXME: Why can't we just map this directly again? It looks like we're shrugging when the arms get set up wrong or something.
		model_root.transform.origin.y = lerp(
			model_pos.y, head_pos.y - head_rest_transform.origin.y + head_vertical_offset,
			clamp(hips_vertical_blend_speed * delta, 0.0, 1.0))

	# ---------------------------------------------------------------------
	# IK stuff starts here

	# Arm IK.
	var x_pole_dist = 10.0
	var z_pole_dist = 10.0
	var y_pole_dist = 5.0

	for chain_name in ["arm_left", "arm_right"]:

		var tracker_to_use = $Hand_Left
		var compensation_alpha_scale = 1.0
		var pole_target_x = x_pole_dist
		if chain_name == "arm_right": # FIXME: Hack.
			tracker_to_use = $Hand_Right
			compensation_alpha_scale *= -1.0
			pole_target_x = -x_pole_dist

		var tracker_local_position = \
			skel.get_global_transform().inverse() * tracker_to_use.get_global_transform()
		var base_bone_position = skel.get_bone_global_pose(
			skel.find_bone(_ikchains_dict[chain_name].base_bone)).origin
		#print(tracker_local_position.origin.x - bone_position.x)
		
		# See if we can raise the shoulders for when arms go too far up.
		if chain_name == "arm_left" or chain_name == "arm_right":
			var chest_bone_index : int = skel.find_bone("Chest")
			if chest_bone_index != -1:
				var chest_pose = skel.get_bone_global_pose(chest_bone_index)

				# FIXME: We really need to parameterize this all in a less
				# silly way.
				var rotation_scale = 1.0
				var shoulder_bone = "LeftShoulder"
				if tracker_to_use == $Hand_Right:
					shoulder_bone = "RightShoulder"
					rotation_scale = -rotation_scale

				var shoulder_bone_index = skel.find_bone(shoulder_bone)
				if shoulder_bone_index != -1:
					var shoulder_pose = skel.get_bone_global_pose(shoulder_bone_index)
					var chest_pose_inv = chest_pose.inverse()
					var shoulder_y = (chest_pose_inv * shoulder_pose).origin.y
					var tracker_local_chest = chest_pose_inv * tracker_local_position
					if tracker_local_chest.origin.y > shoulder_y:
						#print(tracker_local_chest.origin.y - shoulder_y)
						skel.set_bone_pose_rotation(shoulder_bone_index,
							Quaternion(Vector3(0.0, 0.0, 1.0), (tracker_local_chest.origin.y - shoulder_y) * 2.0 * rotation_scale) *
							skel.get_bone_rest(shoulder_bone_index).basis.get_rotation_quaternion())

		var pole_target_y = -y_pole_dist
		var pole_target_z = -z_pole_dist

		# Rotate pole target upwards when the arm reaches across the
		# chest.
		if (tracker_local_position.origin.x - base_bone_position.x) * compensation_alpha_scale < 0:
			var alpha = -(tracker_local_position.origin.x - base_bone_position.x) * 3.0 * compensation_alpha_scale
			#print(alpha)
			pole_target_y = lerp(-y_pole_dist, 0.0, alpha)
			pole_target_z = lerp(-z_pole_dist, 0.0, alpha)
		
		# Move pole target backwards when the arm is lowered.
		#
		# FIXME: Hardcoded values.
		var arm_below_factor = (tracker_local_position.origin.y - base_bone_position.y) + 0.25
		arm_below_factor *= 1.0
		if arm_below_factor < 0.0:
			var alpha = arm_below_factor
			# FIXME: Hardcoded values.
			pole_target_z = lerp(pole_target_z, 100.0, alpha)
			pole_target_x = lerp(pole_target_x, 100.0 * compensation_alpha_scale, alpha)

		
		_ikchains_dict[chain_name].pole_direction_target = Vector3(
			pole_target_x, pole_target_y, pole_target_z)

	# FIXME: Fix this comment.
	# Do hand stuff.
	if do_hands:
		update_hand(hand_landmarks_left, "Left")
		update_hand(hand_landmarks_right, "Right")

	# Solve spine.
	for chain_name in ["spine"]:
		_ikchains_dict[chain_name].do_ik_chain()

	# ---------------------------------------------------------------------------------------------
	# Handle Leaning

	var lean_check_axis : Vector3 = (skel.transform * skel.get_bone_global_pose(skel.find_bone("Hips"))).basis * Vector3(1.0, 0.0, 0.0)
	lean_check_axis = lean_check_axis.normalized()
	var head_offset : Vector3 = tracker_dict["head"]["transform"].origin - model_root.transform.origin
	var lean_amount : float = sin(lean_check_axis.dot(head_offset))
	handle_lean(skel, lean_amount * lean_scale)

	# Solve arms.
	for chain_name in ["arm_left", "arm_right"]:
		_ikchains_dict[chain_name].do_ik_chain()


func _reinit() -> void:
	_reset_hand_landmarks()
	_setup_ik_chains()
	_init_complete = true

func _setup_ik_chains():

	# ORDER MATTERS ON THE CHAIN ARRAY. SPINE BEFORE ARMS BEFORE FINGERS.

	_clear_ik_chains()

	var chain_spine : PoseIK_IKChain = PoseIK_IKChain.new()
	chain_spine.skeleton = get_skeleton()
	chain_spine.base_bone = "Hips"
	chain_spine.tip_bone = "Head"
	chain_spine.rotation_low = 0.0 * PI
	chain_spine.rotation_high = 2.0 * PI
	chain_spine.do_yaw = true
	chain_spine.main_axis_of_rotation = Vector3(1.0, 0.0, 0.0)
	chain_spine.secondary_axis_of_rotation = Vector3(0.0, 1.0, 0.0)
	chain_spine.pole_direction_target = Vector3(0.0, 0.0, 0.0) # No pole target
	chain_spine.tracker_object = $Head
	chain_spine.yaw_scale = chest_yaw_scale

	#chain_spine.do_rotate_to_match_tracker = false
	#chain_spine.do_point_tracker = false
	#chain_spine.do_pole_targets = false

	_ikchains_dict["spine"] = chain_spine

	var x_pole_dist = 10.0
	var z_pole_dist = 10.0
	var y_pole_dist = 5.0
	
	var arm_rotation_axis = Vector3(0.0, 1.0, 0.0).normalized()

	var hand_tracker_left : Node3D = $Hand_Left
	var hand_tracker_right : Node3D = $Hand_Right

	for side in [ "Left", "Right" ]:

		var chain_hand = PoseIK_IKChain.new()
		chain_hand.skeleton = get_skeleton()
		chain_hand.base_bone = side + "UpperArm"
		chain_hand.tip_bone = side + "Hand"
		#chain_hand.tip_bone = side + "IndexProximal"
		chain_hand.rotation_low = 0.05 * PI
		chain_hand.rotation_high = 2.0 * 0.99 * PI
		chain_hand.do_yaw = false
		chain_hand.do_bone_roll = true
		chain_hand.secondary_axis_of_rotation = Vector3(0.0, 1.0, 0.0)

		if side == "Left":
			chain_hand.main_axis_of_rotation = -arm_rotation_axis
			chain_hand.pole_direction_target = Vector3(
				x_pole_dist, -y_pole_dist, -z_pole_dist)
			chain_hand.tracker_object = hand_tracker_left
			_ikchains_dict["arm_left"] = chain_hand
		else:
			chain_hand.main_axis_of_rotation = arm_rotation_axis
			chain_hand.pole_direction_target = Vector3(
				-x_pole_dist, -y_pole_dist, -z_pole_dist)
			chain_hand.tracker_object = hand_tracker_right
			_ikchains_dict["arm_right"] = chain_hand

func _reset_hand_landmarks():

	for tracker : Node3D in [ $Hand_Left, $Hand_Right ]:
		
		# Make sure we have all the children.
		while tracker.get_child_count() < 21:
			var new_finger_tracker : MeshInstance3D = MeshInstance3D.new()
			tracker.add_child(new_finger_tracker)
			if tracker == $Hand_Left:
				hand_landmarks_left.append(new_finger_tracker)
			else:
				hand_landmarks_right.append(new_finger_tracker)

		# Set them visible or not.
		for finger_tracker : MeshInstance3D in tracker.get_children():
			if debug_visible_hand_trackers:
				if not finger_tracker.mesh:
					finger_tracker.mesh = SphereMesh.new()
					finger_tracker.mesh.radius = 0.004
					finger_tracker.mesh.height = finger_tracker.mesh.radius * 2.0
					finger_tracker.material_override = preload(
						"../MediaPipe/MediaPipeTrackerMaterial.tres") # FIXME: Copy the material here?
			else:
				finger_tracker.mesh = null

	assert(len(hand_landmarks_left) == 21)
	assert(len(hand_landmarks_right) == 21)

# This function will rotate a bone in the global (skeleton object) coordiate
# space, as though it were in its rest position. So hardcoded Y axis can be
# used for elbow, hardcoded X axis can be used for spine, etc.
static func rotate_bone_in_global_space(
	skel : Skeleton3D,
	bone_index : int,
	axis : Vector3,
	angle : float,
	relative : bool = false):

	if axis.length() <= 0.0001:
		return

	var parent_bone_index = skel.get_bone_parent(bone_index)	
	var gs_rotation = Basis(axis.normalized(),  angle).get_rotation_quaternion()
	var gs_rotation_parent = skel.get_bone_global_rest(parent_bone_index).basis.get_rotation_quaternion()
	var gs_rotation_rest = skel.get_bone_global_rest(bone_index).basis.get_rotation_quaternion()
	var bs_rotation = gs_rotation_parent.inverse() * gs_rotation * gs_rotation_rest

	if relative:
		skel.set_bone_pose_rotation(
			bone_index,
			skel.get_bone_pose_rotation(bone_index) * bs_rotation)
	else:
		skel.set_bone_pose_rotation(
			bone_index,
			bs_rotation)


func handle_lean(skel : Skeleton3D, angle : float):

	var current_bone : int = skel.find_bone("Head")
	var hips_bone : int = skel.find_bone("Hips")
	var bone_count : int = 0
	
	while current_bone != hips_bone and current_bone != -1:
		bone_count += 1
		current_bone = skel.get_bone_parent(current_bone)

	angle /= float(bone_count)

	current_bone = skel.find_bone("Head")
	while current_bone != hips_bone and current_bone != -1:
		rotate_bone_in_global_space(skel, current_bone, Vector3(0.0, 0.0, 1.0), angle, true)
		current_bone = skel.get_bone_parent(current_bone)

func update_hand(hand_landmarks : Array, which_hand : String):

	if len(hand_landmarks) < 21:
		return

	for finger_bone_array in finger_bone_array_array:
		_update_finger_chain(finger_bone_array, hand_landmarks, which_hand)

## Update a single chain of finger bones based on hand tracking landmarks.
func _update_finger_chain(finger_bone_array : Array, hand_landmarks : Array, which_hand : String) -> void:

	var tracker_dict : Dictionary = get_global_mod_data("trackers")

	var skel : Skeleton3D = get_skeleton()
	var finger_rotation_main_axis : Vector3 = Vector3(0, 0, 0)
	var is_first_bone : bool = true

	for finger_bone in finger_bone_array:

		var hand_name : String = which_hand
		var finger_bone_to_modify_base : String = finger_bone["bone_name_current"]
		var finger_bone_to_modify : String = hand_name + finger_bone_to_modify_base

		# bone_name_next could actually be the same bone that we're about to
		# modify. This is normal. In that case we're re-using the parent->child
		# vector from the last pair of bones in the chain so that the last bone
		# has a direction reference when it normally wouldn't due to lack of the
		# tip bone.
		var bone_name_next : String = finger_bone["bone_name_next"]
		var bone_name_parent_of_next : String = finger_bone["bone_name_parent_of_next"]
		var finger_bone_reference_1 = hand_name + bone_name_next
		var finger_bone_reference_2 = hand_name + bone_name_parent_of_next
	
		var bone_to_modify_index : int = skel.find_bone(finger_bone_to_modify)

		if bone_to_modify_index == -1:
			continue
		if skel.find_bone(finger_bone_reference_2) == -1:
			continue

		# Try to find missing "tip" bones like on Exo's model.
		if skel.find_bone(finger_bone_reference_1) == -1:
			var bone_index_before_missing : int = skel.find_bone(finger_bone_reference_2)
			var bone_children : PackedInt32Array = skel.get_bone_children(bone_index_before_missing)
			if len(bone_children) == 1:
				finger_bone_reference_1 = skel.get_bone_name(bone_children[0])
			else:
				continue

		skel.reset_bone_pose(bone_to_modify_index)

		# Find the object-space vector between the control points.
		var control_point_end_index : int = finger_bone["landmark_index_end"]
		var control_point_start_index : int = finger_bone["landmark_index_start"]
		var control_point_end : Vector3 = hand_landmarks[control_point_end_index].global_transform.origin
		var control_point_start : Vector3 = hand_landmarks[control_point_start_index].global_transform.origin
		var skel_inverse = skel.transform.inverse()
		var test_bone_vec_global = (skel_inverse * control_point_end - skel_inverse * control_point_start).normalized()

		# Get the direction that the bone is facing in right now.
		var current_finger_vec_global = \
			(skel.get_bone_global_pose(skel.find_bone(finger_bone_reference_1)).origin -
			skel.get_bone_global_pose(skel.find_bone(finger_bone_reference_2)).origin).normalized()

		# Figure out the relative rotation between that direction and the direction to the next
		# control point.
		var angle_between = acos(test_bone_vec_global.dot(current_finger_vec_global))

		# Set the global rotation axis just once.
		# FIXME: Pre-calculate the rotation axis for this feature.
		var rotation_axis_global : Vector3 = finger_rotation_main_axis
		if is_first_bone or not lock_fingers_to_single_axis_of_rotation:
			rotation_axis_global = test_bone_vec_global.cross(current_finger_vec_global).normalized()
			finger_rotation_main_axis = rotation_axis_global

		# Convert that to local space.
		var rotation_axis_local = \
			skel.get_bone_global_pose(skel.get_bone_parent(bone_to_modify_index)).basis.inverse() * \
			rotation_axis_global

		# Another attempt fixing finger curling rotation stuff. Lock it to just the local Z axis.
		# In a t-pose, with the palms facing down, this should have our fingers curling normally.
		#
		# Does not work well with thumbs.
		if lock_fingers_to_z_axis and not is_first_bone and not finger_bone_to_modify_base.begins_with("Thumb"):
			rotation_axis_local = Vector3(-1, 0, 0)

		# Convert that to a rotation offset from the rest rotation.
		var global_rotation_from_rest = skel.get_bone_global_rest(bone_to_modify_index).basis * rotation_axis_local

		var hand_index = "hand_" + which_hand.to_lower()
		if tracker_dict.has(hand_index):
			if not tracker_dict[hand_index]:
				skel.set_bone_pose_rotation(bone_to_modify_index, Basis())
			else:
				rotate_bone_in_global_space(skel, bone_to_modify_index, global_rotation_from_rest, -angle_between)

		is_first_bone = false

func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray = []
	if not check_mod_dependency("Mod_MediaPipeController", false):
		errors.append("No MediaPipeController detected before PoseIK. There is nothing to feed tracker data into the PoseIK system.")
	return errors
