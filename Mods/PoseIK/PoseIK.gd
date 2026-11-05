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
var shoulder_raise_max_angle: float = 60.0
var shoulder_rotation_scale: float = 1.0

var debug_pole_targets: bool = false

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

var polemodifier_left_arm: KiriPoleTargetModifier3D = null
var polemodifier_right_arm: KiriPoleTargetModifier3D = null

# Euler angles to use with Basis.from_euler().
# FIXME(GIANTESS): Make these degrees. Convert to radians later.
# FIXME(GIANTESS): Set better defaults based on our tweaking.
var pole_target_angle_arms_down:            Vector3 = Vector3(0.0,             PI,              0.0)
var pole_target_angle_hands_up:             Vector3 = Vector3(45.0 * PI/180.0, PI/2.0,          0.0)
var pole_target_angle_hands_across:         Vector3 = Vector3(-5.0 * PI/180.0, 15.0 * PI/180.0, 0.0)
var pole_target_angle_hands_above_shoulder: Vector3 = Vector3(45.0 * PI/180.0, PI/2.0,          0.0)
var pole_target_alpha_scale_hands_above_shoulder: float = 2.0

var shoulder_lean_counter_rotation_scale: float = 1.0

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
		{ "min" : -1.0, "max" : 1.0, "step": 0.01 },
		"advanced")
	add_tracked_setting(
		"hips_vertical_blend_speed", "Hips vertical blend speed",
		{ "min" : 0.0, "max" : 20.0 },
		"advanced")
	add_tracked_setting(
		"hip_adjustment_speed", "Hip Adjustment Speed", { "min" : 0.0, "max" : 10.0 },
		"advanced")

	add_tracked_setting(
		"shoulder_raise_max_angle", "Shoulder rotation max angle", { "min" : 0.0, "max" : 90.0 },
		"advanced")
	add_tracked_setting(
		"shoulder_rotation_scale", "Shoulder rotation scale", { "min" : 0.0, "max" : 10.0 },
		"advanced")
	add_tracked_setting(
		"shoulder_lean_counter_rotation_scale", "Counter-rotated inside shoulder for lean scale", { "min" : 0.0, "max" : 2.0 },
		"advanced")

	# Euler angles to use with Basis.from_euler().
	add_setting_group("pole_targets", "Pole Target pitch/yaw/roll")
	add_tracked_setting("debug_pole_targets", "Show pole targts for debugging", {}, "pole_targets")
	add_tracked_setting("pole_target_angle_arms_down", "Arms down", {}, "pole_targets")
	add_tracked_setting("pole_target_angle_hands_up", "Hands up", {}, "pole_targets")
	add_tracked_setting("pole_target_angle_hands_across", "Reaching across the chest", {}, "pole_targets")
	add_tracked_setting("pole_target_angle_hands_above_shoulder", "Hands above shoulders", {}, "pole_targets")
	add_tracked_setting("pole_target_alpha_scale_hands_above_shoulder", "Hands above shoulder alpha scale", {"min": 0.0, "max": 5.0, "step": 0.01}, "pole_targets")

	_reinit()

func scene_init() -> void:
	_reinit()

	var skel: Skeleton3D = get_skeleton()

	# Set up pole target modifiers for left/right arms.
	#
	# Set them to inactive so we can trigger their modification at a specific
	# point in the PoseIK process.
	polemodifier_left_arm = KiriPoleTargetModifier3D.new()
	skel.add_child(polemodifier_left_arm)
	polemodifier_left_arm.angle_offset = -PI/2
	polemodifier_left_arm.root_bone = "LeftUpperArm"
	polemodifier_left_arm.target_bone = "LeftHand"
	polemodifier_left_arm.pole_target_node = polemodifier_left_arm.get_path_to($PoleTargetElbowLeft)
	polemodifier_left_arm.active = false
	polemodifier_right_arm = KiriPoleTargetModifier3D.new()
	skel.add_child(polemodifier_right_arm)
	polemodifier_right_arm.angle_offset = PI/2
	polemodifier_right_arm.root_bone = "RightUpperArm"
	polemodifier_right_arm.target_bone = "RightHand"
	polemodifier_right_arm.pole_target_node = polemodifier_right_arm.get_path_to($PoleTargetElbowRight)
	polemodifier_right_arm.active = false

func scene_shutdown() -> void:
	_init_complete = false
	_clear_ik_chains()

	if polemodifier_left_arm:
		polemodifier_left_arm.queue_free()
		polemodifier_left_arm = null

	if polemodifier_right_arm:
		polemodifier_right_arm.queue_free()
		polemodifier_right_arm = null

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
		
		var head_offset: Vector3 = Vector3(0.0, head_vertical_offset * get_model_height_scale(), 0.0)
		$Head.global_transform.origin += head_offset * tracker_dict["head"].transform.basis
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
	
	# FIXME(GIANTESS): This is possibly affected by model/tracker scale.
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
			model_pos.y, head_pos.y - head_rest_transform.origin.y,
			clamp(hips_vertical_blend_speed * delta, 0.0, 1.0))

	# ---------------------------------------------------------------------
	# IK stuff starts here

	# Solve spine.
	for chain_name in ["spine"]:
		_ikchains_dict[chain_name].do_ik_chain()

	# Arm IK.

	# Solve arms.
	# FIXME(GIANTESS): See if we can do this after shoulders-up and shoulders-forward.
	for chain_name in ["arm_left", "arm_right"]:
		_ikchains_dict[chain_name].do_ik_chain()

	# Do hand stuff.
	if do_hands:
		update_hand(hand_landmarks_left, "Left")
		update_hand(hand_landmarks_right, "Right")

	for chain_name in ["arm_left", "arm_right"]:

		# Adjust shoulders upward when the arm is raised up past a certain
		# point. Depends on tracker position and chest bone already being in the
		# right transform.
		_adjust_shoulders_for_arms_up(chain_name)

		# Determine how much we're reaching across the chest so we can pivot the
		# pole target upwards. Depends on shoulder bone transform and tracker.
		var arm_across_chest_alpha: float = _calculate_arm_across_chest_alpha(chain_name)

		# FIXME(GIANTESS): Do shoulders-forward based on arm_across_chest_alpha.

		# Determine how much the arms are lowered so we can move the pole
		# targets backwards, so the elbows face back.
		var arms_down_alpha: float = _calculate_arms_down_alpha(chain_name)

		var arms_above_shoulder_alpha: float = _calculate_arms_above_shoulders_alpha(chain_name)

		var pole_target_vec: Vector3 = _calculate_final_pole_target_position(
			chain_name, arms_down_alpha, arm_across_chest_alpha,
			arms_above_shoulder_alpha)

		if chain_name == "arm_left":
			$PoleTargetElbowLeft.transform.origin = pole_target_vec
		else:
			$PoleTargetElbowRight.transform.origin = pole_target_vec

	# Do pole target stuff.
	polemodifier_left_arm._do_rotation_update(delta, true)
	polemodifier_right_arm._do_rotation_update(delta, true)

	# Counter-rotate upper arm (hack). This keeps the bicep from pointing
	# outwards when the arm goes outwards.
	# FIXME(GIANTESS): Arm chain argument.
	# FIXME(GIANTESS): Parameterize the amount of effect this has.
	fix_upperarm_HACK()

	# Debug display of pole targets.
	_update_debug_draw_pole_targets()

	# ---------------------------------------------------------------------------------------------
	# Handle Leaning

	# Lean the entire model based on the head rotation/
	#var head_rotation: float = skel.get_bone_pose_rotation(
		#skel.find_bone("Head")).get_euler(EULER_ORDER_XYZ).z
	#var lean_amount: float = head_rotation * lean_scale
	
	# FIXME(GIANTESS): Try using the hips transform offset from the rest pose
	#var hips_pose: Transform3D = \
	#	(skel.global_transform * skel.get_bone_global_rest(skel.find_bone("Hips"))).inverse() * \
	#	(skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Hips")))
	var hips_pose: Transform3D = \
		skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Root"))
	var hips_inv: Transform3D = \
		hips_pose.inverse()
	var head_in_hips_space: Vector3 = hips_inv * tracker_dict.head.transform.origin
	#print(head_in_hips_space)
	# Problem with this is that the hips have already been rotated from the IK.
	var lean_amount: float = -head_in_hips_space.x / get_model_height_scale() 

	handle_lean(skel, lean_amount * lean_scale)




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
	chain_spine.tracker_object = $Head
	chain_spine.yaw_scale = chest_yaw_scale

	#chain_spine.do_rotate_to_match_tracker = false
	#chain_spine.do_point_tracker = false
	#chain_spine.do_pole_targets = false

	_ikchains_dict["spine"] = chain_spine

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
			chain_hand.tracker_object = hand_tracker_left
			_ikchains_dict["arm_left"] = chain_hand
		else:
			chain_hand.main_axis_of_rotation = arm_rotation_axis
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
# FIXME(GIANTESS): Stop using this. We should be doing things in local coordinate spaces.
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

	# Apply counter-rotation to shoulder on the side we're leaning into.
	var arm_bone_to_modify: String = "LeftShoulder"
	if angle > 0:
		arm_bone_to_modify = "RightShoulder"

	var arm_bone_idx: int = skel.find_bone(arm_bone_to_modify)
	var current_arm_bone_transform: Transform3D = skel.get_bone_pose(arm_bone_idx)
	var new_transform: Transform3D = current_arm_bone_transform.rotated(Vector3(0.0, 0.0, 1.0), -angle * shoulder_lean_counter_rotation_scale)
	skel.set_bone_pose(arm_bone_idx, new_transform)

func update_hand(hand_landmarks : Array, which_hand : String):

	if len(hand_landmarks) < 21:
		return

	for finger_bone_array in finger_bone_array_array:
		_update_finger_chain(finger_bone_array, hand_landmarks, which_hand)

## Update a single chain of finger bones based on hand tracking landmarks.
func _update_finger_chain(finger_bone_array : Array, hand_landmarks : Array, which_hand : String) -> void:

	var tracker_dict : Dictionary = get_global_mod_data("trackers")

	# Don't update fingers on inactive hands.
	# FIXME: Just return to rest pose for these fingers?
	if not tracker_dict["hand_" + which_hand.to_lower()].active:
		return

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
		var local_rotation_axis_from_rest: Vector3 = \
			skel.get_bone_global_rest(bone_to_modify_index).basis * rotation_axis_local

		var hand_index = "hand_" + which_hand.to_lower()
		if tracker_dict.has(hand_index):
			if not tracker_dict[hand_index]:
				skel.set_bone_pose_rotation(bone_to_modify_index, Basis())
			else:
				rotate_bone_in_global_space(skel, bone_to_modify_index, local_rotation_axis_from_rest, -angle_between)

		is_first_bone = false

func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray = []
	if not check_mod_dependency("Mod_MediaPipeController", false):
		errors.append("No MediaPipeController detected before PoseIK. There is nothing to feed tracker data into the PoseIK system.")
	return errors

func _calculate_arm_across_chest_alpha(chain_name: String) -> float:

	var skel: Skeleton3D = get_skeleton()

	# Figure out left/right strings and trackers based on which side we're
	# on.
	var tracker_to_use: Node3D = $Hand_Left
	var side: String = "Left"
	var otherside: String = "Right"
	if chain_name == "arm_right":
		tracker_to_use = $Hand_Right
		side = "Right"
		otherside = "Left"

	# Get the position of this shoulder. We're using the UpperArm because we
	# really want the "tail" of the Shoulder bone, or where it effectively ends
	# up anyway.
	var upper_arm_index: int = skel.find_bone(side + "UpperArm")
	var upper_arm_pos_global: Vector3 = skel.global_transform * skel \
		.get_bone_global_pose(upper_arm_index) \
		.origin

	# Get the position of the OTHER shoulder.
	var other_upper_arm_index: int = skel.find_bone(otherside + "UpperArm")
	var other_upper_arm_pos_global: Vector3 = skel.global_transform * skel \
		.get_bone_global_pose(other_upper_arm_index) \
		.origin

	# Get the midpoint between the two upper arms. Should end up in the base of
	# the next/top of the chest area.
	var midpoint: Vector3 = (other_upper_arm_pos_global + upper_arm_pos_global) / 2.0

	# Get the offset from that midpoint for THIS arm.
	var upper_arm_offset_from_center: Vector3 = upper_arm_pos_global - midpoint

	# Create a normalized axis to check against.
	var axis_to_check: Vector3 = upper_arm_offset_from_center.normalized()
	
	# Get the offset of the hand tracker from the midpoint.
	var vector_to_check_against_axis: Vector3 = \
		tracker_to_use.get_global_transform().origin - midpoint

	# Project the tracker onto that axis to figure out how far between the two
	# shoulders we are. Or, more specifically, how far we are between this
	# shoulder and the center of the two shoulders.
	var dp: float = vector_to_check_against_axis.dot(axis_to_check)

	# Convert that to percentage based on the breadth of the shoulders.
	var dp_percentage: float = dp / upper_arm_offset_from_center.length()

	# FIXME(GIANTESS): make configurable value for the 1.0 and 0.75 (starting
	#   threshold and scaling of alpha value)
	var final_alpha: float = clamp(0.75 * (1.0 -dp_percentage), 0.0, 1.0)

	# That's our output.
	return final_alpha

func _calculate_arms_down_alpha(chain_name: String) -> float:

	var skel: Skeleton3D = get_skeleton()

	var chest_bone_index: int = skel.find_bone("Chest")
	var chest_bone_tx: Transform3D = skel.global_transform * skel.get_bone_global_pose(chest_bone_index)
	var chest_bone_tx_inv = chest_bone_tx.inverse()

	# Figure out left/right strings and trackers based on which side we're
	# on.
	var tracker_to_use: Node3D = $Hand_Left
	if chain_name == "arm_right":
		tracker_to_use = $Hand_Right

	var tracker_in_chest_space: Vector3 = \
		chest_bone_tx_inv * \
		tracker_to_use.get_global_transform().origin

	# Move pole target backwards when the arm is lowered.
	#
	# FIXME(GIANTESS): Make configurable!
	# Number from 0 to 1, indicating how far down an arm must be for the
	# elbows-back pole target to kick in.
	var arm_lowered_threshold: float = 0.25
	# Same as above, but what point the pole target direction should max
	# out.
	var arm_lowered_max: float = 1.0

	var hand_rest_position: Vector3 = \
		skel.get_bone_global_rest(
			skel.find_bone(_ikchains_dict[chain_name].tip_bone)).origin
	var base_bone_rest_position: Vector3 = \
		skel.get_bone_global_rest(
			skel.find_bone(_ikchains_dict[chain_name].base_bone)).origin
	var arm_length: float = (hand_rest_position - base_bone_rest_position).length()
	
	var base_bone_in_chest_space = chest_bone_tx_inv * \
		skel.global_transform * \
		skel.get_bone_global_pose(
			skel.find_bone(_ikchains_dict[chain_name].base_bone)).origin

	var t = (base_bone_in_chest_space.y - tracker_in_chest_space.y) / arm_length
	return smoothstep(arm_lowered_threshold, arm_lowered_max, t)

func _calculate_arms_above_shoulders_alpha(chain_name: String) -> float:

	var skel: Skeleton3D = get_skeleton()

	# Figure out left/right strings and trackers based on which side we're
	# on.
	var tracker_to_use: Node3D = $Hand_Left
	var side: String = "Left"
	var otherside: String = "Right"
	if chain_name == "arm_right":
		tracker_to_use = $Hand_Right
		side = "Right"
		otherside = "Left"

	# Get the position of this shoulder.
	var upper_arm_index: int = skel.find_bone(side + "UpperArm")
	var upper_arm_pos_global: Vector3 = skel.global_transform * skel \
		.get_bone_global_pose(upper_arm_index) \
		.origin

	# Get the position of the OTHER shoulder.
	var other_upper_arm_index: int = skel.find_bone(otherside + "UpperArm")
	var other_upper_arm_pos_global: Vector3 = skel.global_transform * skel \
		.get_bone_global_pose(other_upper_arm_index) \
		.origin

	var chest_bone_index: int = skel.find_bone("Chest")
	var chest_bone_tx: Transform3D = skel.global_transform * skel.get_bone_global_pose(chest_bone_index)
	var chest_bone_tx_inv = chest_bone_tx.inverse()

	# Get the midpoint between the two upper arms. Should end up in the base of
	# the next/top of the chest area.
	var midpoint: Vector3 = (other_upper_arm_pos_global + upper_arm_pos_global) / 2.0

	var midpoint_in_chest_space: Vector3 = chest_bone_tx_inv * midpoint
	var hand_tracker_in_chest_space: Vector3 = chest_bone_tx_inv * tracker_to_use.global_transform.origin

	var offset_from_shoulder_mid: Vector3 = \
		hand_tracker_in_chest_space - midpoint_in_chest_space

	offset_from_shoulder_mid /= get_model_height_scale()

	return clamp(
		offset_from_shoulder_mid.y * pole_target_alpha_scale_hands_above_shoulder,
		0.0, 1.0)

func _calculate_final_pole_target_position(
	chain_name: String,
	arms_down_alpha: float,
	arm_across_chest_alpha: float,
	arms_above_shoulder_alpha: float) -> Vector3:

	var skel: Skeleton3D = get_skeleton()
	var chest_bone_index: int = skel.find_bone("Chest")
	var chest_bone_tx: Transform3D = skel.global_transform * skel.get_bone_global_pose(chest_bone_index)

	# Figure out final pole target location.
	var adjusted_pole_target_angle_arms_down:    Vector3 = pole_target_angle_arms_down
	var adjusted_pole_target_angle_hands_up:     Vector3 = pole_target_angle_hands_up
	var adjusted_pole_target_angle_hands_across: Vector3 = pole_target_angle_hands_across
	var adjusted_pole_target_angle_hands_above_shoulder: Vector3 = pole_target_angle_hands_above_shoulder

	# Figure out left/right strings and trackers based on which side we're
	# on.
	if chain_name == "arm_right":
		adjusted_pole_target_angle_arms_down.y *= -1.0
		adjusted_pole_target_angle_hands_up.y *= -1.0
		adjusted_pole_target_angle_hands_across.y *= -1.0
		adjusted_pole_target_angle_hands_above_shoulder *= -1.0

	var pole_target_basis_arms_down: Basis = Basis.from_euler(adjusted_pole_target_angle_arms_down)
	var pole_target_basis_hands_up: Basis = Basis.from_euler(adjusted_pole_target_angle_hands_up)
	var pole_target_basis_hands_across: Basis = Basis.from_euler(adjusted_pole_target_angle_hands_across)
	var pole_target_basis_hands_above_shoulders: Basis = Basis.from_euler(adjusted_pole_target_angle_hands_above_shoulder)

	var final_basis: Basis = pole_target_basis_hands_up \
		.slerp(pole_target_basis_arms_down, arms_down_alpha) \
		.slerp(pole_target_basis_hands_across, arm_across_chest_alpha) \
		.slerp(pole_target_basis_hands_above_shoulders, arms_above_shoulder_alpha)

	# FIXME(GIANTESS): Change the hardcoded value for distance here.
	var pole_target_vec: Vector3 = chest_bone_tx * (final_basis * Vector3(0.0, 0.0, 100.0))

	return pole_target_vec

func _adjust_shoulders_for_arms_up(chain_name: String) -> void:

	var skel: Skeleton3D = get_skeleton()

	var chest_bone_index: int = skel.find_bone("Chest")

	var rotation_scale: float = shoulder_rotation_scale
	var rotation_max: float = shoulder_raise_max_angle * (PI/180)

	# Figure out left/right strings, trackers, and inverted scales based on
	# which side we're on.
	var tracker_to_use: Node3D = $Hand_Left
	var shoulder_bone: String = "LeftShoulder"
	if chain_name == "arm_right":
		tracker_to_use = $Hand_Right
		shoulder_bone = "RightShoulder"
		rotation_scale = -rotation_scale

	var tracker_local_position = \
		skel.get_global_transform().inverse() * tracker_to_use.get_global_transform()

	var chest_pose = skel.get_bone_global_pose(chest_bone_index)

	var shoulder_bone_index = skel.find_bone(shoulder_bone)
	if shoulder_bone_index != -1:
		var shoulder_pose = skel.get_bone_global_pose(shoulder_bone_index)
		var chest_pose_inv = chest_pose.inverse()
		var shoulder_y = (chest_pose_inv * shoulder_pose).origin.y
		var tracker_local_chest = chest_pose_inv * tracker_local_position
		if tracker_local_chest.origin.y > shoulder_y:
			
			var shoulder_rotation_angle: float = \
				(tracker_local_chest.origin.y - shoulder_y) * 2.0 * rotation_scale

			# Apply scale based on height of model.
			shoulder_rotation_angle /= get_model_height_scale()

			shoulder_rotation_angle = clampf(shoulder_rotation_angle, -rotation_max, rotation_max)
			# Actually rotate the thing!
			skel.set_bone_pose_rotation(shoulder_bone_index,
				Quaternion(Vector3(0.0, 0.0, 1.0), shoulder_rotation_angle) *
				skel.get_bone_rest(shoulder_bone_index).basis.get_rotation_quaternion())

# Debug display of pole targets.
func _update_debug_draw_pole_targets() -> void:

	var skel: Skeleton3D = get_skeleton()

	if debug_pole_targets:

		var debug_mesh: ImmediateMesh = get_app().get_debug_mesh()
		debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for side: String in ["Left", "Right"]:

			var upper_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone(side + "UpperArm")).origin
			var lower_pos: Vector3 = skel.global_transform * skel.get_bone_global_pose(skel.find_bone(side + "Hand")).origin
			var midpoint: Vector3 = (upper_pos + lower_pos) / 2.0
			
			var target: Node3D = $PoleTargetElbowLeft
			if side == "Right":
				target = $PoleTargetElbowRight

			# Line from top of arm to hand.
			debug_mesh.surface_set_color(Color.RED)
			debug_mesh.surface_add_vertex(upper_pos)
			debug_mesh.surface_set_color(Color.GREEN)
			debug_mesh.surface_add_vertex(lower_pos)

			# Line from midpoint to pole target.
			var midpoint_offset: Vector3 = target.global_transform.origin - midpoint
			midpoint_offset = midpoint_offset.normalized() * get_model_height_scale()
			debug_mesh.surface_set_color(Color.BLUE)
			debug_mesh.surface_add_vertex(midpoint)
			debug_mesh.surface_set_color(Color.CYAN)
			debug_mesh.surface_add_vertex(midpoint + midpoint_offset)

		debug_mesh.surface_end()

	$PoleTargetElbowRight.visible = debug_pole_targets
	$PoleTargetElbowLeft.visible = debug_pole_targets

func fix_upperarm_HACK() -> void:

	var skel: Skeleton3D = get_skeleton()

	for side in ["Left", "Right"]:
		if randf() > 0.0:

			var upperarm_index: int = skel.find_bone(side + "UpperArm")

			# Preserve child transforms.
			var children: Array = []
			for child_index: int in skel.get_bone_children(upperarm_index):
				children.push_back([child_index, skel.get_bone_global_pose(child_index),skel. get_bone_pose(child_index)])

			var rotation_euler: Vector3 = \
				(skel.get_bone_rest(upperarm_index).inverse() *
				skel.get_bone_pose(upperarm_index)).basis.get_euler()

			# Axis we'll be rotating the upper arm by, and also to check how far
			# we have to rotate.
			var rotation_axis: Vector3 = skel.get_bone_global_pose(upperarm_index).basis * Vector3(0.0, 1.0, 0.0)

			# Current forward vector for the upper arm.
			var upperarm_forward_vector: Vector3 = skel.get_bone_global_pose(upperarm_index).basis * Vector3(1.0, 0.0, 0.0)

			# Current forward vector for the chest (rotation target).
			var chest_forward_vector: Vector3 = skel.get_bone_global_pose(skel.find_bone("Chest")).basis * Vector3(0.0, 0.0, 1.0)

			# Get the dot product and cross product to construct the rotation
			# from. DP tells us how much and CP tells us which way.
			var cos_forward_displacement: float = upperarm_forward_vector.normalized().dot(chest_forward_vector.normalized())
			var cross_forwards: Vector3 = upperarm_forward_vector.normalized().cross(chest_forward_vector.normalized())

			# Flip stuff for mirrored side.
			if side == "Left":
				cos_forward_displacement *= -1.0

			# Get the angle to rotate by.
			var rotation_displacement: float = acos(cos_forward_displacement)

			# Rotate outwards, but not inwards. We'll drop the rotation
			# displacement to zero as it crosses from the cross product pointing
			# one way and the other way. Basically, when the rotation direction
			# flips and it crosses over its original orientation.
			# FIXME(GIANTESS): Make the thresholds here configurable!
			var axis_alignment: float = rotation_axis.dot(cross_forwards.normalized())
			rotation_displacement = lerp(rotation_displacement, 0.0, smoothstep(-0.1, 0.1, axis_alignment))

			# Another mirror flip.
			if side == "Right":
				rotation_displacement *= -1

			#print(side, " ", rotation_displacement)

			#get_app().debug_draw_transform(
				#skel.global_transform * \
				#skel.get_bone_global_pose(skel.find_bone("Chest")), 0.25)

			#print(rotation_euler)
			#if randf() < 0.5:
			#rotation_euler.x += rotation_displacement #0.1
			#rotation_euler.z *= 0.5
			var rotation_displacement_scale: float = 0.5
			skel.set_bone_pose_rotation(upperarm_index,
				Basis(skel.get_bone_pose_rotation(upperarm_index)) * \
				Basis.from_euler(Vector3(0.0, rotation_displacement * rotation_displacement_scale, 0.0)) \
			)
			#get_app().debug_draw_transform(skel.global_transform * skel.get_bone_global_pose(upperarm_index), 0.25)

			# Restore child transforms.
			for child_record: Array in children:
				skel.set_bone_global_pose(child_record[0], child_record[1])
				#skel.set_bone_pose_position(child_record[0], child_record[1].origin)
				skel.set_bone_pose_position(child_record[0], skel.get_bone_rest(child_record[0]).origin)


			
			#skel.set_bone_pose_rotation(upperarm_index, Quaternion.from_euler(Vector3(0.0, PI * 2.0 * randf(), 0.0)))
