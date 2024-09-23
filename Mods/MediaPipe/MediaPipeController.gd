extends Mod_Base

# Tracker process state and UDP connection info.
var udp_server = null
@export var udp_port_base : int = 7098
var _udp_port = udp_port_base # This will change dynamically based on port availability.
var tracker_pid = -1
var time_until_tracker_restart = 0.0

# NEW tracker stuff.
var tracker_python_process : KiriPythonWrapperInstance = null

# Current tracking state.
var last_parsed_data = {}
var hand_landmarks_left = []
var hand_landmarks_right = []
var hand_time_since_last_update = [0.0, 0.0]
var hand_time_since_last_missing = [0.0, 0.0]
var mirrored_last_frame = true
var blend_shape_last_values = {}
var _current_model_root : Node = null
var hand_rest_trackers = {}
var _init_complete = false
var _ikchains = []

# Settings stuff
@export var mirror_mode : bool = true
@export var arm_rest_angle : float = 45
@export var arm_reset_time : float = 0.5
@export var arm_reset_speed : float = 0.1
@export var use_external_tracker = false
@export var hand_tracking_enabed : bool = true
var use_vrm_basic_shapes = false
var use_mediapipe_shapes = true
var frame_rate_limit = 60
var video_device = Array() # It's an array that we only ever put one thing in.

var debug_visible_hand_trackers = false

# TODO: Add settings for these
var do_spine = true
var do_ik_curve = true
var do_yaw_global = true
var do_point_tracker = true
var do_pole_targets = true
var do_rotate_to_match_tracker = true
var do_hands = true

# Temp variables for settings.
var _devices_by_list_entry = {}
var _devices_list = []

var functions_blendshapes = preload("MediaPipeController_BlendShapes.gd")

# FIXME: Make key for this configurable.
var tracking_pause = false

var hand_confidence_time_threshold = 1.0
var hand_count_change_time_threshold = 1.0

func _ready():

	var script_path : String = self.get_script().get_path()
	var script_dirname : String = script_path.get_base_dir()

	tracker_python_process = KiriPythonWrapperInstance.new( \
		script_dirname.path_join("/_tracker/Project/new_tracker.py"))
	tracker_python_process.setup_python(true)
	
	print("Installing dependencies...")
	# FIXME: Find a way to determine whether or not we've installed
	# dependencies. Also figure out a way to ship with those dependencies
	# instead of relying on PyPi.
	#
	# Use "pip3 download -r requirements.txt" but feed it something from our RPC
	# wrapper config, to download the whl files, and then just do "pip install"
	# with those whl files.
	#
	# Hard part: Figure out platform (--platform on pip) stuff.
	# (eg: pip3 download --platform=win_amd64 --only-binary=:all: -r requirements.txt")
	#
	# FIXME: Don't run pip every damn time we start up.
	var requirements_file_path : String = \
		tracker_python_process.convert_cache_item_to_real_path("res://Mods/MediaPipe/_tracker/Project/requirements.txt")
		
	var pip_args = ["-m", "pip", "install", "-r", requirements_file_path]
	print("Running pip: ", pip_args)
	var pip_install_return : int = tracker_python_process.execute_python(pip_args)
	
	print("Pip return: ", pip_install_return)

	print("Starting tracker process...")
	tracker_python_process.start_process(false)

	add_tracked_setting("hand_tracking_enabed", "Hand tracking enabled")
	add_tracked_setting("use_vrm_basic_shapes", "Use basic VRM shapes")
	add_tracked_setting("use_mediapipe_shapes", "Use MediaPipe shapes")
	add_tracked_setting("mirror_mode", "Mirror mode")
	add_tracked_setting("frame_rate_limit", "Frame rate limit", { "min" : 1.0, "max" : 240.0 })
	add_tracked_setting("arm_rest_angle", "Arm rest angle", { "min" : 0.0, "max" : 180.0 })
	add_tracked_setting("use_external_tracker", "Disable internal tracker")

	add_tracked_setting("hand_confidence_time_threshold", "Hand confidence time threshold", { "min" : 0.0, "max" : 20.0 })
	add_tracked_setting("hand_count_change_time_threshold", "Hand count change time threshold", { "min" : 0.0, "max" : 20.0 })

	_scan_video_devices()
	
	add_tracked_setting(
		"video_device", "Video Device",
		{"values" : _devices_list,
		 "combobox" : true})

	add_tracked_setting("debug_visible_hand_trackers", "Debug: Visible hand trackers")


	add_tracked_setting("tracking_pause", "Pause tracking")

	hand_rest_trackers["Left"] = $LeftHandRestReference
	hand_rest_trackers["Right"] = $RightHandRestReference
	
	set_status("Waiting to start")
	
	update_settings_ui()
	
	
	# FIXME: Remove this.
	var reset_label : Label = Label.new()
	var reset_button : Button = Button.new()
	reset_button.text = "Cycle Tracker"
	get_settings_window().add_child(reset_label)
	get_settings_window().add_child(reset_button)
	reset_button.pressed.connect(func():
		#tracker_python_process.call_rpc_sync(
			#"stop_tracker", [])
		tracker_python_process.call_rpc_sync(
			"start_tracker", []))
	
	_update_for_new_model_if_needed()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	super.load_after(_settings_old, _settings_new)
	_update_arm_rest_positions()
	
	var reset_tracker = false
	
	if _settings_new["frame_rate_limit"] != _settings_old["frame_rate_limit"]:
		reset_tracker = true
	if len(_settings_old["video_device"]) != len(_settings_new["video_device"]):
		reset_tracker = true

	# If camera device selection changed, call the RPC to open the new device,
	if len(_settings_old["video_device"]) > 0 and len(_settings_new["video_device"]) > 0:
		if _settings_old["video_device"][0] != _settings_new["video_device"][0]:
			var actual_device_data = _devices_by_list_entry[video_device[0]]
			tracker_python_process.call_rpc_sync(
				"set_video_device_number", [actual_device_data["index"]])

	# If no camera selected, then select device -1.
	if len(_settings_new["video_device"]) == 0:
		tracker_python_process.call_rpc_sync(
			"set_video_device_number", [-1])

	tracker_python_process.call_rpc_async(
		"set_hand_confidence_time_threshold", [hand_confidence_time_threshold])
		
	tracker_python_process.call_rpc_async(
		"set_hand_count_change_time_threshold", [hand_count_change_time_threshold])

	if _settings_old["use_external_tracker"] != _settings_new["use_external_tracker"]:
		reset_tracker = true

	if reset_tracker:
		stop_tracker()
		if not use_external_tracker:
			time_until_tracker_restart = 3.0

	var reset_blend_shapes = false
	if _settings_old["use_vrm_basic_shapes"] != _settings_new["use_vrm_basic_shapes"]:
		reset_blend_shapes = true
	if _settings_old["use_mediapipe_shapes"] != _settings_new["use_mediapipe_shapes"]:
		reset_blend_shapes = true
	if reset_blend_shapes:
		for k in blend_shape_last_values.keys():
			blend_shape_last_values[k] = 0.0

func scene_init():

	blend_shape_last_values = {}
	last_parsed_data = {}

	assert(!udp_server)
	
	# Find a port number that's open to use.
	udp_server = PacketPeerUDP.new()
	var udp_error = 1
	_udp_port = udp_port_base
	while udp_error != OK:
		udp_error = udp_server.bind(_udp_port, "127.0.0.1")
		if udp_error != OK:
			_udp_port += 1

	if not use_external_tracker:
		start_tracker()

	var root = get_skeleton().get_parent()
	var left_rest = $LeftHandRestReference
	var right_rest = $RightHandRestReference
	remove_child(left_rest)
	remove_child(right_rest)
	root.add_child(left_rest)
	root.add_child(right_rest)
	
	_setup_ik_chains()
	_update_arm_rest_positions()
	
	_init_complete = true

func scene_shutdown():
	
	stop_tracker()
	
	udp_server.close()
	udp_server = null
	
	var root = get_skeleton().get_parent()
	var left_rest = root.get_node("LeftHandRestReference")
	var right_rest = root.get_node("RightHandRestReference")
	
	root.remove_child(left_rest)
	root.remove_child(right_rest)
	add_child(left_rest)
	add_child(right_rest)
	
	_ikchains = []
	
	_init_complete = false

# -----------------------------------------------------------------------------
# Post-load model setup.

func _update_arm_rest_positions():
	var skel : Skeleton3D = get_skeleton()
	
	if skel:
		
		for side in [ "Left", "Right" ]:
			
			var rotation_axis : Vector3 = Vector3(0.0, 0.0, 1.0)
			if side == "Left":
				rotation_axis *= -1

			# Rotate the shoulder down so the arm is resting at a specific angle
			# on the Z axis.
			var shoulder_index = skel.find_bone(side + "Shoulder")
			var hand_index = skel.find_bone(side + "Hand")
			var shoulder_origin : Vector3 = skel.get_bone_global_rest(shoulder_index).origin
			var hand_origin : Vector3 = skel.get_bone_global_rest(hand_index).origin
			var rotation_basis = Basis(rotation_axis, deg_to_rad(arm_rest_angle))
			var new_offset : Vector3 = (hand_origin - shoulder_origin).rotated(
					rotation_axis, deg_to_rad(arm_rest_angle))
			hand_rest_trackers[side].transform.origin = shoulder_origin + new_offset
			hand_rest_trackers[side].transform.basis = rotation_basis

func _setup_ik_chains():
	
	_ikchains = []
	
	var chain_spine = MediaPipeController_IKChain.new()
	chain_spine.skeleton = get_skeleton()
	chain_spine.base_bone = "Hips"
	chain_spine.tip_bone = "Head"
	chain_spine.rotation_low = 0.0 * PI
	chain_spine.rotation_high = 2.0 * PI
	chain_spine.do_yaw = true
	chain_spine.main_axis_of_rotation = Vector3(1.0, 0.0, 0.0)
	chain_spine.secondary_axis_of_rotation = Vector3(0.0, 1.0, 0.0)
	chain_spine.pole_direction_target = Vector3(0.0, 0.0, 0.0) # No pole target
	_ikchains.append(chain_spine)

	var x_pole_dist = 10.0
	var z_pole_dist = 10.0
	var y_pole_dist = 5.0
	
	var arm_rotation_axis = Vector3(0.0, 1.0, 0.0).normalized()

	for side in [ "Left", "Right" ]:
		var chain_hand = MediaPipeController_IKChain.new()
		chain_hand.skeleton = get_skeleton()
		chain_hand.base_bone = side + "UpperArm"
		chain_hand.tip_bone = side + "Hand"
		chain_hand.rotation_low = 0.05 * PI
		chain_hand.rotation_high = 2.0 * 0.99 * PI
		chain_hand.do_yaw = false
		chain_hand.do_bone_roll = true
		chain_hand.secondary_axis_of_rotation = Vector3(0.0, 1.0, 0.0)

		if side == "Left":		
			chain_hand.main_axis_of_rotation = -arm_rotation_axis
			chain_hand.pole_direction_target = Vector3(
				x_pole_dist, -y_pole_dist, -z_pole_dist)
		else:
			chain_hand.main_axis_of_rotation = arm_rotation_axis
			chain_hand.pole_direction_target = Vector3(
				-x_pole_dist, -y_pole_dist, -z_pole_dist)
			
		_ikchains.append(chain_hand)

func _update_for_new_model_if_needed():
	_setup_ik_chains()
	_update_arm_rest_positions()

# -----------------------------------------------------------------------------
# Tracker process interop.

func _scan_video_devices():

	var device_list : Array = tracker_python_process.call_rpc_sync(
		"enumerate_camera_devices", [])
	print(device_list)

	for device in device_list:
		var device_generated_name = "{name} ({backend}:{index})".format(device)
		print(device_generated_name)
		_devices_list.append(device_generated_name)
		_devices_by_list_entry[device_generated_name] = device

	# Create a fake "None" entry.
	_devices_list.insert(0, "None")
	_devices_by_list_entry["None"] = { "index" : -1 }


func _get_tracker_executable():
	var script_path = self.get_script().get_path()
	var script_dirname = script_path.get_base_dir()
	var actual_module_path = ProjectSettings.globalize_path(script_dirname)

	var executable_name = "snekstudio_mediapipetracker_linux/snekstudio_mediapipetracker_linux"
	if OS.get_name() == "Windows":
		executable_name = "snekstudio_mediapipetracker_windows/snekstudio_mediapipetracker_windows.exe"
	
	var executable_path = actual_module_path.path_join("_tracker/Project/dist").path_join(executable_name)

	# FIXME: REAL UGLY HACK
	var paths_to_check = [executable_path, "./snekstudio_mediapipetracker_linux"]
	
	# FIXME: EVEN UGLIER HACK OH GOD IT JUST GETS WORSE AND WORSE
	#paths_to_check = [actual_module_path.path_join("_tracker/run_linux_sourcetree.bsh")]
	
	for path in paths_to_check:
		if FileAccess.file_exists(path):
			return path
	
	# FIXME
	print("CAN'T FIND THE TRACKER EXECUTABLE!")
	return ""

	#return executable_path
	
	# FIXME: Hack hack hack hack
	#return "./snekstudio_mediapipetracker_linux"

func start_tracker():
	
	tracker_python_process.call_rpc_sync(
		"set_udp_port_number", [_udp_port])

	tracker_python_process.call_rpc_sync(
		"set_hand_confidence_time_threshold", [hand_confidence_time_threshold])

	var video_device_index_to_use = 0
	
	if len(video_device) > 0:
		if video_device[0] in _devices_by_list_entry:
			var actual_device_data = _devices_by_list_entry[video_device[0]]
			video_device_index_to_use = int(actual_device_data["index"])
	else:
		video_device_index_to_use = -1

	tracker_python_process.call_rpc_async(
		"set_video_device_number", [video_device_index_to_use])

	tracker_python_process.call_rpc_async(
		"set_hand_count_change_time_threshold", [hand_count_change_time_threshold])

	tracker_python_process.call_rpc_sync(
		"start_tracker", [])

func stop_tracker():
	
	if tracker_pid == -1:
		return
	
	OS.kill(tracker_pid)
	tracker_pid = -1
	
	set_status("Stopped")

func process_new_packets(model, delta):
	var most_recent_packet = null
	var dropped_packets = 0
	while true:
		var packet = udp_server.get_packet()
		
		# FIXME: Disallow packets from remote systems, unless allowed
		# explicitly.

		var packet_string = packet.get_string_from_utf8()
		var json = JSON.new()
		json.parse(packet_string)
		var parsed_data = json.data

		if parsed_data:
			
			if "status" in parsed_data:
				set_status(parsed_data["status"])
				continue

			if "error" in parsed_data:
				set_status("Error: " + parsed_data["error"])
				continue

			set_status("Receiving tracker data")
			
			last_parsed_data["head_quat"] = parsed_data["head_quat"]
			last_parsed_data["head_origin"] = parsed_data["head_origin"]
			
			for hand_name in [ "left", "right" ]:
				var hand_score_str = "hand_" + hand_name + "_score"
				var hand_rotation_str = "hand_" + hand_name + "_rotation"
				var hand_origin_str = "hand_" + hand_name + "_origin"
				var hand_landmark_str = "hand_landmarks_" + hand_name # FIXME: Make this consistent.
				# FIXME: Put all the hand stuff under one dictionary entry.
				
				if hand_score_str in parsed_data:

					var override_val : bool = false
					if not (hand_score_str in last_parsed_data):
						override_val = true
					elif last_parsed_data[hand_score_str] < parsed_data[hand_score_str]:
						override_val = true
					
					if override_val:
						last_parsed_data[hand_score_str] = parsed_data[hand_score_str]
						last_parsed_data[hand_rotation_str] = parsed_data[hand_rotation_str]
						last_parsed_data[hand_origin_str] = parsed_data[hand_origin_str]
						last_parsed_data[hand_landmark_str] = parsed_data[hand_landmark_str]
						
			if "blendshapes" in parsed_data:

				# Save the parsed data.
				last_parsed_data["blendshapes"] = parsed_data["blendshapes"]

 				#blend_shape_last_values.duplicate()
	
				var shape_dict_new = {}
				
				# Merge in MediaPipe or basic VRM blendshapes per options.
				if use_vrm_basic_shapes:
					shape_dict_new.merge(
						functions_blendshapes.convert_mediapipe_shapes_to_vrm_standard(last_parsed_data["blendshapes"]),
						true)
				if use_mediapipe_shapes:
					shape_dict_new.merge(
						last_parsed_data["blendshapes"],
						true)
				
				# Apply smoothing.
				# FIXME: Parameterize.
				shape_dict_new = functions_blendshapes.apply_smoothing(
					blend_shape_last_values, shape_dict_new,
					delta)
				
				# Eye fixups.
				# FIXME: Make optional.
				shape_dict_new = functions_blendshapes.fixup_eyes(shape_dict_new)
				
				shape_dict_new = functions_blendshapes.handle_blendshapes(
					model,
					shape_dict_new,
					blend_shape_last_values,
					use_vrm_basic_shapes,
					use_mediapipe_shapes,
					mirror_mode,
					delta)
				
				functions_blendshapes.apply_animations(
					model, shape_dict_new, mirror_mode)
				
				blend_shape_last_values = shape_dict_new
				

		if len(packet) > 0:
			if most_recent_packet != null:
				dropped_packets += 1
			most_recent_packet = packet
		else:
			break
	
	if dropped_packets > 0:
		print_log(["Dropped packets: ", dropped_packets])

# -----------------------------------------------------------------------------
# Actual update code.


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

func _process(delta):

	if tracker_python_process:
		tracker_python_process.poll()

	if tracker_pid != -1:
		if not OS.is_process_running(tracker_pid):
			if time_until_tracker_restart <= 0:
				stop_tracker()
				time_until_tracker_restart = 1

	if time_until_tracker_restart > 0:
		time_until_tracker_restart -= delta
		if time_until_tracker_restart <= 0:
			if tracker_pid != -1:
				stop_tracker()
			if not use_external_tracker:
				start_tracker()
		else:
			set_status("Restarting in: " + str(int(time_until_tracker_restart)))

	if not _init_complete:
		return
		
	if not udp_server:
		return

	var model_root = get_model()
	if not model_root:
		return


	# FIXME: Remove this. OffKai hack.
	if tracking_pause:
		return
	

	# FIXME: Hack.
	# This just moves the body based on the head position.
	var head_pos = $Head.transform.origin
	var model_pos = model_root.transform.origin
	var model_y = model_pos.y
	
	if true:
		# FIXME: Make this adjustable, at the very least.
		model_root.transform.origin = model_pos.lerp(head_pos, delta)
		#model_root.transform.origin.y = model_y 
		#model_root.transform.origin.y = lerp(model_pos.y, head_pos.y - 1.9, 0.01)
		
		# FIXME: Another hack!
		var head_rest_transform = get_skeleton().get_bone_global_rest(
			get_skeleton().find_bone("Head"))
		#print(head_rest_transform.origin.y)
		
		# FIXME: Hard-coded fudge factor.
		# FIXME: Why can't we just map this directly again? It looks like we're shrugging when the arms get set up wrong or something.
		model_root.transform.origin.y = lerp(model_pos.y, head_pos.y - head_rest_transform.origin.y + -0.2, 0.1)

	process_new_packets(model_root, delta)

	var delta_scale = delta * 60.0
	if delta_scale > 1.0:
		delta_scale = 1.0
	if delta_scale < 0.01:
		delta_scale = 0.01

	if last_parsed_data:
		var parsed_data = last_parsed_data

		# FIXME: Make these adjustable.
		var model_origin_offset = Vector3(0.0, 2.0, 0.0)
		var arbitrary_scale = 1.0
		var smoothness = 2.0
		var score_exponent = 1.5
		var score_threshold = 0.1
		var head_rotation_scale = 2.0

		# These are for transforming individual feature points into from the
		# mediapipe hand coordinate into skeleton coordinates.
		var hand_landmark_position_multiplier = Vector3(1.0, 1.0, 1.0)
	
		var hand_origin_multiplier = Vector3(1.0, 1.0, 1.0)
		var head_origin_multiplier = Vector3(1.0, 1.0, 1.0)
		var head_quat_multiplier = [1.0, 1.0, 1.0, 1.0]

		var tracker_left = $Hand_Left
		var tracker_right = $Hand_Right

		if not mirror_mode:
			hand_origin_multiplier = Vector3(-1.0, 1.0, 1.0)
			head_origin_multiplier = Vector3(-1.0, 1.0, 1.0)
			head_quat_multiplier = [1.0, -1.0, -1.0, 1.0]
	
			tracker_left = $Hand_Right
			tracker_right = $Hand_Left
			
			hand_landmark_position_multiplier = Vector3(-1.0, 1.0, 1.0)
		# -----------------------------------------------------------------------------------------
		# Hand packets

		# Pick hand rest references based on mirroring.
		var hand_rest_reference_left = hand_rest_trackers["Left"]
		var hand_rest_reference_right = hand_rest_trackers["Right"]
		if mirror_mode:
			hand_rest_reference_left = hand_rest_trackers["Right"]
			hand_rest_reference_right = hand_rest_trackers["Left"]

		# FIXME: Code smell. Replace with a function call.
		var per_hand_data = [
			[ "Left", hand_landmarks_left,
			  tracker_left,
			  hand_rest_reference_left, 0 ],
			[ "Right", hand_landmarks_right,
			  tracker_right,
			  hand_rest_reference_right, 1 ] ]
		
		for hand in per_hand_data:
			
			var time_since_last_update = hand_time_since_last_update[hand[4]]
			var time_since_last_missing = hand_time_since_last_missing[hand[4]]
				
			
			var hand_str = hand[0]
			var hand_str_lower = hand_str.to_lower()
			var landmarks = hand[1]
			var tracker_ob = hand[2]
			#var fix_basis = hand[3]
	
		
			var hand_score_str = "hand_" + hand_str_lower + "_score"
			var hand_origin_str = "hand_" + hand_str_lower + "_origin"
			var hand_rotation_str = "hand_" + hand_str_lower + "_rotation"
			
			var hand_origin_array = parsed_data[hand_origin_str]
			var hand_score = parsed_data[hand_score_str]
		
			# Apply thresholds to the confidence score.			
			if parsed_data[hand_score_str] < score_threshold or not hand_tracking_enabed: # FIXME: Wrong place for the enabled check?
				parsed_data[hand_score_str] = 0.0

			# Track time since last visible or not.
			if hand_score >= score_threshold:
				time_since_last_update = 0.0
				time_since_last_missing += delta
			else:
				time_since_last_update += delta
				time_since_last_missing = 0.0

			hand_time_since_last_update[hand[4]] = time_since_last_update
			hand_time_since_last_missing[hand[4]] = time_since_last_missing

			if time_since_last_update > arm_reset_time:
				
				var reference_ob = hand[3]
				# Move hand to rest position.
				tracker_ob.global_transform.origin = tracker_ob.global_transform.origin.lerp(
					reference_ob.global_transform.origin, arm_reset_speed) # FIXME: Hardcoded value.
				
				var rot_quat1 = tracker_ob.global_transform.basis.get_rotation_quaternion()
				var rot_quat2 = reference_ob.global_transform.basis.get_rotation_quaternion()
				tracker_ob.global_transform.basis = Basis(rot_quat1.slerp(rot_quat2, arm_reset_speed)) # FIXME: Hardcoded value
				tracker_ob.global_transform.basis = tracker_ob.global_transform.basis.orthonormalized()

			elif time_since_last_missing > 0.1: # FIXME: Hardcoded value.

				# Stretch the last bit of the score out with an exponent.
				parsed_data[hand_score_str] = pow(parsed_data[hand_score_str], score_exponent)
			
				# TODO: Replace the tracker object with just a Transform3D.
				var target_origin = model_origin_offset + (Vector3(
					hand_origin_array[0],
					hand_origin_array[1],
					hand_origin_array[2]) * hand_origin_multiplier) * arbitrary_scale
				
				# Attempt to move hand in front of model. Reaching behind is
				# *usually* the results of bad data.
				#
				# FIXME: Ugly hack.
				#   If we're going to do this, we need to make sure we do it in the model's forward
				#   direction.
				#
				# FIXME: Hardcoded values all over this part.
				#
				var skel = get_app().get_skeleton()
				var chest_transform_global_pose = skel.get_bone_global_pose(skel.find_bone("Chest"))
				var min_z = (skel.global_transform * chest_transform_global_pose).origin
				if target_origin.z < min_z.z + 0.2:
					target_origin.z = min_z.z + 0.2

				# Move tracker forward if we're reaching across the chest to see
				# if we can fix some clipping-into-chest problems.
				#
				# FIXME: Hardcoded values all over this part.
				#
				var tracker_in_chest_space = chest_transform_global_pose.inverse() * target_origin
				# FIXME: Hack for mirror.
				var swap_tracker = tracker_right
				if mirror_mode:
					swap_tracker = tracker_left
				if tracker_ob == swap_tracker:
					tracker_in_chest_space.x *= -1
				# Just clamp the overall reach, first.
				if tracker_in_chest_space.x < -0.2:
					tracker_in_chest_space.x = -0.2
				# Now move forward.
				if tracker_in_chest_space.x < 0.0:
					# FIXME: Hardcoded scaling value.
					tracker_in_chest_space.z += -(tracker_in_chest_space.x - 0.1) * 0.2
				# FIXME: Hack for mirror.
				if tracker_ob == swap_tracker:
					tracker_in_chest_space.x *= -1
				
				target_origin = chest_transform_global_pose * tracker_in_chest_space

				var rotation_basis_array = parsed_data[hand_rotation_str]
				
				var rotation_basis = Basis(
					Vector3(rotation_basis_array[0][0], rotation_basis_array[0][1], rotation_basis_array[0][2]),
					Vector3(rotation_basis_array[1][0], rotation_basis_array[1][1], rotation_basis_array[1][2]),
					Vector3(rotation_basis_array[2][0], rotation_basis_array[2][1], rotation_basis_array[2][2]))

				var new_rotation : Basis = (rotation_basis * Basis()).orthonormalized()
				
				
				if mirror_mode:
					var new_rot_quat = new_rotation.get_rotation_quaternion()
					new_rot_quat.y *= -1.0
					new_rot_quat.z *= -1.0
					new_rotation = Basis(new_rot_quat)
				else:
					var new_rot_quat = new_rotation.get_rotation_quaternion()
					new_rot_quat.y *= -1.0
					new_rot_quat.z *= -1.0
					new_rot_quat.w *= -1.0
					new_rot_quat.x *= -1.0
					new_rotation = Basis(new_rot_quat)
				
				#var new_rot_ortho = new_rotation.orthonormalized().get_rotation_quaternion()
				var old_rot_ortho = tracker_ob.transform.basis.orthonormalized()
				#var new_quat = old_rot_ortho.slerp(new_rotation, 0.1) 
				# FIXME: Hardcoded smoothing factor
				#tracker_ob.transform.basis = Basis(rotation_basis.get_rotation_quaternion())
				
				#if hand_score > 0.0:
				#	tracker_ob.transform.basis.orthonormalized().slerp(
				#		new_rotation.orthonormalized(), 1.0).orthonormalized()
				
				# Why do we have to go through the global transform? I guess we need like a "baked"
				# version of the transform that handles all of our weird axis flipping.
				
				var old_world_transform = tracker_ob.get_global_transform()
				
				#tracker_ob.transform.basis = new_rotation # Basis(new_rotation.orthonormalized().get_rotation_quaternion())
				
				# FIXME: Can't work due to variability in chest bone location?
				#   (problem with new model rigging that wasn't a problem with the old)
#				# Snap tracker to rest position if we're below a certain
#				# threshold
#				#
#				# FIXME: Hardcoded threshold.
#				if tracker_in_chest_space.y < 0.0:
#					var reference_ob = hand[3]
#					target_origin = reference_ob.global_transform.origin
#					#tracker_ob.transform.basis = reference_ob.transform.basis
#					new_rotation = reference_ob.transform.basis
					
				var lerp_scale = 0.25
				tracker_ob.transform.origin = tracker_ob.transform.origin.lerp(
					target_origin,
					hand_score * delta_scale * lerp_scale)
				
				# FIXME: Hardcoded SLERP speed. Make configurable.
				tracker_ob.transform.basis = Basis(
					tracker_ob.transform.basis.orthonormalized().get_rotation_quaternion().slerp(
					new_rotation, 0.5)) # Basis(new_rotation.orthonormalized().get_rotation_quaternion())
				
				var new_world_transform = tracker_ob.get_global_transform()
				
				# FIXME: Hardcoded smoothing value.
				var interped_transform = old_world_transform.interpolate_with(new_world_transform, 0.75)
				tracker_ob.global_transform.basis = interped_transform.basis

				#tracker_ob.transform.basis = new_rotation
				if tracker_ob.mesh:
					tracker_ob.mesh.material.albedo_color.a = 0.25 + hand_score * 0.75

		# -----------------------------------------------------------------------------------------
		# Head packets
		
		# FIXME: Hardcoded transform
		var head_origin_array = parsed_data["head_origin"]
		$Head.transform.origin = $Head.transform.origin.lerp(
			model_origin_offset +
			(Vector3(
				head_origin_array[0],
				head_origin_array[1],
				head_origin_array[2]) * head_origin_multiplier) * arbitrary_scale,
				delta_scale * 0.5) # FIXME: Hardcoded smoothing.
		
		var head_quat_array = parsed_data["head_quat"]
		var head_euler = Basis(Quaternion(
			head_quat_array[0] * head_quat_multiplier[0],
			head_quat_array[1] * head_quat_multiplier[1],
			head_quat_array[2] * head_quat_multiplier[2],
			head_quat_array[3] * head_quat_multiplier[3])).get_euler()
		$Head.transform.basis = $Head.transform.basis.slerp(
			Basis.from_euler(head_euler * head_rotation_scale),
			delta_scale * 0.5) # FIXME: Hardcoded smoothing.
		

		
		# ---------------------------------------------------------------------
		# IK stuff starts here

		var skel = get_app().get_skeleton()
		var skel_offset = Transform3D()

		# Spine IK
		if do_spine:
			_ikchains[0].do_ik_chain(skel_offset * $Head.transform)

		# Arm IK.

		var x_pole_dist = 10.0
		var z_pole_dist = 10.0
		var y_pole_dist = 5.0
		
		var tracker_to_use_right = tracker_right
		var tracker_to_use_left = tracker_left
		if not mirror_mode:
			tracker_to_use_right = tracker_left
			tracker_to_use_left = tracker_right
		
		# FIXME: Hack hack hack hack hack hack
		for k in range(1, 3):

			var tracker_to_use = tracker_to_use_right
			var compensation_alpha_scale = 1.0
			var pole_target_x = x_pole_dist
			if k == 2: # FIXME: Hack.
				tracker_to_use = tracker_to_use_left
				compensation_alpha_scale *= -1.0
				pole_target_x = -x_pole_dist
		
			var tracker_local_position = \
				skel.get_global_transform().inverse() * tracker_to_use.get_global_transform()
			var base_bone_position = skel.get_bone_global_pose(
				skel.find_bone(_ikchains[k].base_bone)).origin
			#print(tracker_local_position.origin.x - bone_position.x)
			
			# See if we can raise the shoulders for when arms go too far up.
			if k == 1 or k == 2:
				var chest_pose = skel.get_bone_global_pose(skel.find_bone("Chest"))

				# FIXME: We really need to parameterize this all in a less
				# silly way.
				var rotation_scale = -1.0
				var shoulder_bone = "RightShoulder"
				if tracker_to_use == tracker_right:
					shoulder_bone = "LeftShoulder"
					rotation_scale = -rotation_scale
				
				var shoulder_bone_index = skel.find_bone(shoulder_bone)
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

			
			_ikchains[k].pole_direction_target = Vector3(
				pole_target_x, pole_target_y, pole_target_z)
			_ikchains[k].do_ik_chain(
				skel_offset * tracker_to_use.transform)


		# Do hand stuff.
				
		# Process hand landmarks

		if do_hands:


			# UGLY HACK ALERT
			if mirror_mode != mirrored_last_frame:
				
				for tracker in [ $Hand_Left, $Hand_Right ]:
					var removal_queue = []
					for c in tracker.get_children():
						if c is MeshInstance3D:
							removal_queue.append(c)
					for c in removal_queue:
						tracker.remove_child(c)
						c.queue_free()
		
				hand_landmarks_left.clear()
				hand_landmarks_right.clear()
		
				mirrored_last_frame = mirror_mode
				
			var hands = [ \
				[ "Left", hand_landmarks_left, tracker_right, Basis() ], # FIXME: Remove the last value.
				[ "Right", hand_landmarks_right, tracker_left, Basis() ]]  # FIXME: Remove the last value.

			for hand in hands:
				update_hand(hand, parsed_data, skel)

func update_hand(hand, parsed_data, skel):
	var mark_counter = 0

	var flipped_hand = "left"
	if hand[0] == "Left":
		flipped_hand = "right"

	var hand_landmark_rotation_to_use = hand[3]
	var hand_landmarks = hand[1]

	for mark in parsed_data["hand_landmarks_" + flipped_hand]:
		
		# Add any missing landmarks
		if len(hand_landmarks) < mark_counter + 1:
			var new_mesh_instance = MeshInstance3D.new()
			hand[2].add_child(new_mesh_instance)
			hand_landmarks.append(new_mesh_instance)
		
		# Update debug visibility.
		for landmark in hand_landmarks:
			if landmark.mesh == null and debug_visible_hand_trackers:
				landmark.mesh = SphereMesh.new()
				landmark.mesh.radius = 0.004
				landmark.mesh.height = landmark.mesh.radius * 2.0
				landmark.material_override = preload(
					"MediaPipeTrackerMaterial.tres")
			elif landmark.mesh != null and (not debug_visible_hand_trackers):
				landmark.mesh = null
		
		var marker = hand_landmarks[mark_counter]
		
		var marker_old_worldspace = marker.global_transform.origin
		
		var marker_original_local = Vector3(mark[0], mark[1], mark[2])
		if mirror_mode:
			marker_original_local[0] *= -1
			# FIXME: WHY THE HECK DO WE HAVE TO DO DO THIS!?!?!?!?!?!?!?!?!?!?!?!?!!!??!?!?!?!?!?!
			if flipped_hand == "right":
				marker_original_local[0] *= -1
				marker_original_local[1] *= -1
				marker_original_local[2] *= -1
		else:
#							marker_original_local[0] *= -1
			if flipped_hand == "right":
				marker_original_local[0] *= -1
				marker_original_local[1] *= -1
				marker_original_local[2] *= -1
			pass
	
		var marker_new_local = hand_landmark_rotation_to_use * \
			marker_original_local
		var marker_new_worldspace = marker.get_parent().transform * marker_new_local
		
#						marker.transform.origin = \
#							hand_landmark_rotation_to_use * \
#							(Vector3(mark[0], mark[1], mark[2]) * hand_landmark_position_multiplier)
		marker.global_transform.origin = lerp( \
			marker_old_worldspace, \
			marker_new_worldspace, \
			0.25) # FIXME: Hardcoded smoothing
		
		mark_counter += 1



#					# First, we need to offset the metacarpal. We can't effectively change the
#					# origin of this through rotations without affecting other bones as well.
#					# Thankfully, we can just set it to the length of the rest offset times the 
#					# direction of the tracker.
#					var metacarpal_index = skel.find_bone(hand[0] + "ThumbMetacarpal")
#					var metacarpal_rest_origin = skel.get_bone_rest(metacarpal_index).origin
#					var metacarpal_tracker_delta_world = hand[1][1].global_transform.origin - hand[1][0].global_transform.origin
#					var metacarpal_tracker_delta_global = skel.transform.basis.inverse() * metacarpal_tracker_delta_world
#					var metacarpal_tracker_delta_bone = skel.get_bone_global_pose(metacarpal_index).basis.inverse() * metacarpal_tracker_delta_global
#					print(metacarpal_tracker_delta_bone)
#					skel.set_bone_pose_position( \
#						metacarpal_index,
#						metacarpal_rest_origin.length() * metacarpal_tracker_delta_bone.normalized())


	var finger_bone_array = [
		[ "IndexProximal",      5,  6, "IndexIntermediate", "IndexProximal" ],
		[ "IndexIntermediate",  6,  7, "IndexDistal",       "IndexIntermediate" ],
		[ "IndexDistal",        7,  8, "IndexDistal",       "IndexIntermediate" ],
		
		[ "MiddleProximal",     9,  10, "MiddleIntermediate", "MiddleProximal" ],
		[ "MiddleIntermediate", 10, 11, "MiddleDistal", "MiddleIntermediate" ],
		[ "MiddleDistal",       11, 12, "MiddleDistal", "MiddleIntermediate" ],

		[ "RingProximal",       13, 14, "RingIntermediate", "RingProximal" ],
		[ "RingIntermediate",   14, 15, "RingDistal", "RingIntermediate" ],
		[ "RingDistal",         15, 16, "RingDistal", "RingIntermediate" ],

		[ "LittleProximal",     17, 18, "LittleIntermediate", "LittleProximal" ],
		[ "LittleIntermediate", 18, 19, "LittleDistal", "LittleIntermediate" ],
		[ "LittleDistal",       19, 20, "LittleDistal", "LittleIntermediate" ],

		# FIXME: Metacarpal *origin* needs to change relative to hand as well.
		[ "ThumbMetacarpal",    1,  2,  "ThumbProximal", "ThumbMetacarpal" ],
		[ "ThumbProximal",      2,  3,  "ThumbDistal", "ThumbProximal" ],
		[ "ThumbDistal",        3,  4,  "ThumbDistal", "ThumbProximal" ],
	]
	
	if not mirror_mode:
		if hand_landmarks == hand_landmarks_left:
			hand_landmarks = hand_landmarks_right
		elif hand_landmarks == hand_landmarks_right:
			hand_landmarks = hand_landmarks_left
			
	if len(hand_landmarks) < 21:
		return
	
	#var hand_basis = skel.get_bone_global_pose(skel.find_bone("LeftHand")).basis
	for finger_bone in finger_bone_array:

		var finger_bone_to_modify = hand[0] + finger_bone[0]
		var finger_bone_reference_1 = hand[0] + finger_bone[3]
		var finger_bone_reference_2 = hand[0] + finger_bone[4]
	
		var test_bone_name = finger_bone_to_modify
		var test_bone_index = skel.find_bone(test_bone_name)

		skel.reset_bone_pose(test_bone_index)
			
		var test_bone_pt_2 = hand_landmarks[finger_bone[2]].global_transform.origin
		var test_bone_pt_1 = hand_landmarks[finger_bone[1]].global_transform.origin
			
			
		var skel_inverse = skel.transform.inverse()
		var test_bone_vec_global = (skel_inverse * test_bone_pt_2 - skel_inverse * test_bone_pt_1).normalized()

		var current_finger_vec_global = \
			(skel.get_bone_global_pose(skel.find_bone(finger_bone_reference_1)).origin -
			skel.get_bone_global_pose(skel.find_bone(finger_bone_reference_2)).origin).normalized()
		
		var angle_between = acos(test_bone_vec_global.dot(current_finger_vec_global))
		var rotation_axis_global = test_bone_vec_global.cross(current_finger_vec_global).normalized()

		var rotation_axis_local = \
			skel.get_bone_global_pose(skel.get_bone_parent(test_bone_index)).basis.inverse() * \
			rotation_axis_global

		var global_rotation_from_rest = skel.get_bone_global_rest(test_bone_index).basis * rotation_axis_local
		
		var hand_index = 0
		if flipped_hand == "left":
			hand_index = 1
			
		if mirror_mode:
			hand_index = [1, 0][hand_index]
		
		if hand_time_since_last_update[hand_index] > arm_reset_time:
			#skel.set_bone_pose_rotation(test_bone_index,
			#	skel.get_bone_pose(test_bone_index).basis.slerp(Basis(), arm_reset_speed))
			skel.set_bone_pose_rotation(test_bone_index, Basis())
		else:
			rotate_bone_in_global_space(skel, test_bone_index, global_rotation_from_rest, -angle_between)
		
