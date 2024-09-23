extends Mod_Base

var bind_ip_address : String = "127.0.0.1"
var bind_port : int = 39570
var vmc_receiver_enabled : bool = false


var blend_shape_last_values = {}
var overridden_blend_shape_values = {} # FIXME: Make this more general-purpose


func _ready():
	add_tracked_setting("bind_ip_address", "Receiver IP address")
	add_tracked_setting("bind_port", "Receiver port")
	add_tracked_setting("vmc_receiver_enabled", "Receiver enabled")
	update_settings_ui()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	$KiriOSCServer.change_port_and_ip(bind_port, bind_ip_address)
	if _settings_old["vmc_receiver_enabled"] != _settings_new["vmc_receiver_enabled"]:
		if vmc_receiver_enabled:
			$KiriOSCServer.start_server()
		else:
			$KiriOSCServer.stop_server()

func _on_OSCServer_message_received(address_string, arguments):
	
	#return # -Kiri
	var model = get_app().get_model()
	var skeleton = model.find_child("GeneralSkeleton")
	var model_controller = get_app().get_node("ModelController")
	
	if address_string == "/VMC/Ext/Bone/Pos":
	
		var actual_bone_name = arguments[0]

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
		#var origin = Vector3(arguments[1], arguments[2], arguments[3])

		# FIXME: Currently we're rotation-only.
		var origin = Vector3(0.0, 0.0, 0.0) # Use this for rotation-only.

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
