extends Mod_Base

var bind_ip_address : String = "127.0.0.1"
var bind_port : int = 39570
var vmc_receiver_enabled : bool = false


var blend_shape_last_values = {}
var overridden_blend_shape_values = {} # FIXME: Make this more general-purpose

var recording_enabled : bool = false
var recording_start : float = 0.0
var recording_packets : Array = []

var playback_enabled : bool = false
var playback_start : float = -1.0
var playback_next_frame : int = 0


func _ready():
	add_tracked_setting("bind_ip_address", "Receiver IP address")
	add_tracked_setting("bind_port", "Receiver port")
	add_tracked_setting("vmc_receiver_enabled", "Receiver enabled")
	
	add_tracked_setting("recording_enabled", "Recording active")

	add_tracked_setting("playback_enabled", "Playback active")

	var clear_recording_button : Button = Button.new()
	clear_recording_button.text = "Clear recorded frames"
	get_settings_window().add_child(clear_recording_button)
	clear_recording_button.pressed.connect(
		func():
			recording_packets = [])

	var save_recording_button : Button = Button.new()
	save_recording_button.text = "Save recorded frames"
	get_settings_window().add_child(save_recording_button)
	save_recording_button.pressed.connect(
		func():
			var out_file : FileAccess = FileAccess.open("user://vmc_temp_recording.json", FileAccess.WRITE)
			var out_string : String = JSON.stringify(recording_packets, "  ")
			out_file.store_string(out_string)
			recording_packets = [])

	var load_recording_button : Button = Button.new()
	load_recording_button.text = "Load recorded frames"
	get_settings_window().add_child(load_recording_button)
	load_recording_button.pressed.connect(
		func():
			var in_file : FileAccess = FileAccess.open("user://vmc_temp_recording.json", FileAccess.READ)
			if in_file:
				var in_string = in_file.get_as_text()
				recording_packets = JSON.parse_string(in_string))

	update_settings_ui()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	$KiriOSCServer.change_port_and_ip(bind_port, bind_ip_address)
	if _settings_old["vmc_receiver_enabled"] != _settings_new["vmc_receiver_enabled"]:
		if vmc_receiver_enabled:
			$KiriOSCServer.start_server()
		else:
			$KiriOSCServer.stop_server()

func scene_shutdown() -> void:
	get_app().get_controller().reset_skeleton_to_rest_pose()
	get_app().get_controller().reset_blend_shapes()

func _process(delta: float) -> void:

	if playback_enabled:

		var current_time = Time.get_ticks_msec() / 1000.0

		# Have we just started playback?
		if playback_start == -1:
			playback_start = current_time

		var playback_time : float = current_time - playback_start
		while playback_next_frame < len(recording_packets) and recording_packets[playback_next_frame]["time"] <= playback_time:
			print("Recorded packet: ", playback_next_frame, recording_packets[playback_next_frame])
			playback_next_frame += 1

	else:
		# Restart playback.
		playback_next_frame = 0
		playback_start = -1

func _on_OSCServer_message_received(address_string, arguments):

	# Save packets.
	if recording_enabled:
		var new_frame : Dictionary = {}
		new_frame["time"] = Time.get_ticks_msec() / 1000.0
		new_frame["address"] = address_string
		new_frame["arguments"] = arguments
		recording_packets.append(new_frame)
		print("Packets saved: ", len(recording_packets))

	var model : Node3D = get_app().get_model()
	var skeleton : Skeleton3D = get_app().get_skeleton()
	var model_controller : Node3D = get_app().get_node("ModelController")
	
	#if address_string == "/VMC/Ext/Root/Pos":
	#	print(arguments)
	#if randf() < 0.1:
	#print(address_string, ": ", arguments)
	
	#if address_string == "/VMC/Ext/Tra/Pos" or address_string == "/VMC/Ext/Bone/Pos" or address_string == "/VMC/Ext/Hmd/Pos" or address_string == "/VMC/Ext/Root/Pos" or address_string == "/VMC/Ext/Con/Pos":
	if address_string == "/VMC/Ext/Bone/Pos" and arguments[0] == "Hips":
		var origin = Vector3(arguments[1], arguments[2], arguments[3])
		#skeleton.global_position = -origin
		var origin_hips = skeleton.get_bone_global_pose(skeleton.find_bone("Hips")).origin
		var offset = origin - origin_hips
		skeleton.global_position = Vector3(-offset.x, offset.y, -offset.z)
		#print("OLD: ", skeleton.global_position)
		#skeleton.global_position = origin
		#print(len(arguments))
		
		
		var node_name = arguments[0]
		node_name = node_name.replace(":", "_")
		node_name = node_name.replace("/", "_")
		var node = get_node_or_null(NodePath(str(node_name)))
		if node == null:
			print("NEW NODE: ", node_name)
			node = MeshInstance3D.new()
			node.mesh = SphereMesh.new()
			node.mesh.radius = 0.1
			node.mesh.height = 0.2
			node.name = node_name
			add_child(node)
			#
		node.global_position = origin
	#else:
	#	print(address_string)
	
	if address_string == "/VMC/Ext/Bone/Pos":
	
		var actual_bone_name = arguments[0]
		
		#print(actual_bone_name)

		# We may have to rename some thumb bone names, depending on whether we
		# have a VRM 1.0 or 0.0 model.
		if arguments[0].begins_with("LeftThumb") or arguments[0].begins_with("RightThumb"):
			if model_controller.find_mapped_bone_index("LeftThumbMetacarpal") != -1:
				# We have the metacarpal bone, so assume VRM 1.0.
				var bone_without_side = ""
				var bone_side = ""
				if arguments[0].begins_with("Left"):
					bone_without_side = arguments[0].substr(4)
					bone_side = "Left"
				else:
					bone_without_side = arguments[0].substr(5)
					bone_side = "Right"
				#print("BONE WITHOUT SIDE: ", bone_without_side)
				
				var converted_bone_without_side = bone_without_side
				if bone_without_side == "ThumbProximal":
					converted_bone_without_side = "ThumbMetacarpal"
				if bone_without_side == "ThumbIntermediate":
					converted_bone_without_side = "ThumbProximal"
				
				actual_bone_name = bone_side + converted_bone_without_side

		var bone_index =  model_controller.find_mapped_bone_index(actual_bone_name)


		# FIXME: If we want to actually handle bone translation offsets, we
		# need to handle this in the correct coordinate space. Right now
		# enabling it will just double-up translation and look wrong.
		var origin = Vector3(arguments[1], arguments[2], arguments[3])

		#if actual_bone_name == "Hips":
			##print(origin)
			#if skeleton.global_position != origin:
				#print("Changed")
			#print(skeleton.global_position)
			##skeleton.global_position = origin

		# FIXME: Currently we're rotation-only.
		#var origin = Vector3(0.0, 0.0, 0.0) # Use this for rotation-only.

		# We have to flip around some of the rotation axes directly in the
		# quaternion here to account for the different coordinate space.
		#var rot = Quaternion(-arguments[4], -arguments[5], arguments[6], arguments[7])
		
#		var t = int(Time.get_unix_time_from_system())
#		if t & 1:
#			arguments[4] = -arguments[4]
#		if t & 2:
#			arguments[5] = -arguments[5]
#		if t & 4:
#			arguments[6] = -arguments[6]
#		if t & 8:
#			arguments[7] = -arguments[7]
		
		#print(t)
		
		var rot = Quaternion(arguments[4], -arguments[5], -arguments[6], arguments[7]).normalized()
		#rot = $Model/GeneralSkeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion() #Quaternion(0.0, 0.0, 0.0, 1.0) #rot.slerp(Quaternion(0.0, 0.0, 0.0, 1.0), 0.1)
		#var rot = Quaternion(0.0, 0.0, 0.0, 1.0) #rot.slerp(Quaternion(0.0, 0.0, 0.0, 1.0), 0.1)
		
		#var rot = Quaternion(0.0, arguments[6], arguments[5], 0.0)
		
		#rot.w = sqrt(1.0 - (rot.x * rot.x + rot.y * rot.y + rot.z * rot.z))
		
#		var rot = Quaternion(0.0, 0.0, 0.0, 1.0)
#		#if arguments[0].to_lower() == "rightlowerarm" || arguments[0].to_lower() == "rightupperarm":
#			#rot = Quaternion(0.707, 0.0, 0.0, 0.707).normalized()
#			#print(arguments.slice(4, 8))
#
#			#rot = Quaternion(0.0, , 0.0, 0.0)
#			#rot.w = sqrt(1.0 - (rot.x * rot.x + rot.y * rot.y + rot.z * rot.z))
#
		#rot = Quaternion(arguments[6], arguments[4], arguments[5], 0.0)
#		rot.w = sqrt(1.0 - (rot.x * rot.x + rot.y * rot.y + rot.z * rot.z))
#		if arguments[7] < 0.0:
#			rot.w = -rot.w
		
		#print([arguments[0], $Model/GeneralSkeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion()])
		
		if bone_index != -1:

			var new_transform : Transform3D = \
#				$Model/GeneralSkeleton.get_bone_rest(bone_index) * \
				skeleton.get_bone_rest(bone_index) * \
				Transform3D(
					skeleton.get_bone_global_rest(bone_index).basis.get_rotation_quaternion()).inverse() * \
				Transform3D(
					Basis(rot),
					origin) * \
				Transform3D(
					skeleton.get_bone_global_rest(bone_index).basis.get_rotation_quaternion())

			skeleton.set_bone_pose_rotation(
				bone_index, new_transform.basis.get_rotation_quaternion())
		else:
			print("NO BONE FOUND FOR VMC THING: ", actual_bone_name)

	# -------------------------------------------------------------------------
	# Blend shapes

	if address_string == "/VMC/Ext/Blend/Val":
		blend_shape_last_values[arguments[0].to_upper()] = arguments[1]

	# Merge blend shapes with overridden stuff.
	var combined_blend_shape_last_values = blend_shape_last_values.duplicate()
	for k in overridden_blend_shape_values.keys():
		if k in combined_blend_shape_last_values:
			combined_blend_shape_last_values[k] = max(
				overridden_blend_shape_values[k],
				combined_blend_shape_last_values[k])
		else:
			combined_blend_shape_last_values[k] =  overridden_blend_shape_values[k]

	if address_string == "/VMC/Ext/Blend/Apply":

		var anim_path_maximums = {}
		var anim_player : AnimationPlayer = model.get_node("AnimationPlayer")

		if anim_player:

			# Figure out the maximum blend shape values for each animation.
			for anim_name in combined_blend_shape_last_values.keys():
	
				# FIXME: Hack hack hack hack hack
				#   This is a hack added on 2023-10-26 so my model can work
				#   tomorrow after I made the silly mistake of updating the VRM
				#   addon.
				var name_mapping_so_this_works_tomorrow = {
					"EYES_SHRUNK" : "Eyes_Shrunk",
					"CLIPBOARD_OPEN" : "Clipboard_Open",
					"BLUSH" : "Blush",
					"TONGUE 1" : "Tongue 1",
					"TONGUE 2" : "Tongue 2",
					"LOOKLEFT" : "lookLeft",
					"LOOKRIGHT" : "lookRight",
					"LOOKUP" : "lookUp",
					"LOOKDOWN" : "lookDown",
					"BROWS DOWN" : "Brows down",
					"BROWS UP" : "Brows up",
					"SORROW" : "sad",
					"NEUTRAL" : "neutral",
					"JOY" : "happy",
					"BLINK" : "blink",
					"A" : "aa",
					"E" : "ee",
					"I" : "ih",
					"O" : "oh",
					"U" : "ou" }


				# Skip any animations that don't exist in this VRM.				
				var full_anim_name = anim_name
				if full_anim_name in name_mapping_so_this_works_tomorrow:
					full_anim_name = name_mapping_so_this_works_tomorrow[full_anim_name]
				if not (full_anim_name in anim_player.get_animation_list()):
					#print("NAME: ", anim_name)
					#print(anim_player.get_animation_list())
					continue
					
				var anim = anim_player.get_animation(full_anim_name)
				
				if not anim:
					continue
				
				# Iterate through every track on the animation.
				#print("Anim ", anim_name, " track count: ", anim.get_track_count())
				for track_index in range(0, anim.get_track_count()):
					var anim_path : NodePath = anim.track_get_path(track_index)

					#print("  track: ", anim.track_get_path(track_index))

					# Create the key if it does not exist.
					if not (anim_path in anim_path_maximums.keys()):
						anim_path_maximums[anim_path] = 0.0
					
					# Record max value.
					anim_path_maximums[anim_path] = max(
						anim_path_maximums[anim_path],
						combined_blend_shape_last_values[anim_name])
					
			# Iterate through every max animation value and set it on the
			# appropriate blend shape on the object.
			var anim_root = anim_player.get_node(anim_player.root_node)
			if anim_root:
				
				for anim_path_max_value_key in anim_path_maximums.keys():
				
					var object_to_animate : Node = anim_root.get_node(anim_path_max_value_key)
					if object_to_animate:
						object_to_animate.set(
							"blend_shapes/" + anim_path_max_value_key.get_subname(0),
							anim_path_maximums[anim_path_max_value_key])
