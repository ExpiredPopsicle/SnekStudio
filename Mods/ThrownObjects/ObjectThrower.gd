extends Mod_Base

# List of every possible throwable object (full path).
var throwable_list = []

var thrown_object_queue = []
var thrown_object_cooldown = 0.0
var thrown_object_cooldown_max = 0.05

@export var bit_redeem = false
@export var throws_per_bit = 1
@export var redeem_name = "Throw something at my face"
@export var count_multiplier = 1

# List of selected throwable objects (subset of throwable_list).
@export var selected_throwables : Array[String] = []

@export var head_impact_rotation_return_speed = 5.0

var head_impact_rotation_offset = Quaternion(0.0, 0.0, 0.0, 1.0)

func _ready():

	var local_dir = get_mod_path()
	var local_dir_objects : String = local_dir.path_join("Objects")

	# List of directories to (attempt to) search for throwable objects.
	var folders_with_throwables = [
		local_dir_objects
	]
	
	# Add a directory with the same path, but relative to the binary. This will
	# let runtime-loaded files override internal files.
	if local_dir_objects.begins_with("res://"):
		folders_with_throwables.append(
			OS.get_executable_path().get_base_dir().path_join(
				local_dir_objects.substr(len("res://"))))
	
	# Search those directories for any throwable objects, and load them.
	for path_to_list in folders_with_throwables:
		print(path_to_list)
		#var dir = DirAccess.open(path_to_list)
		#if dir:
			#dir.list_dir_begin()
			#var file_name = dir.get_next()
			#while file_name != "":
				#if not dir.current_is_dir():
		var diraccess = DirAccessWithMods.new()
		var filelist = diraccess.get_file_list(path_to_list)
		for file_name in filelist:
			var full_path = path_to_list.path_join(file_name)
			print("Checking ", full_path)
			
			# Load scene files directly.
			if file_name.get_extension() == "tscn":
				#var local_path = ProjectSettings.localize_path(full_path)
				
				#var local_path = full_path.substr(
				#	0, len(OS.get_executable_path().get_base_dir()))
				var local_path = path_to_list.path_join(file_name)
				throwable_list.append(local_path)
				print("local path: ", local_path)
			
			# TODO: Load JSON files... differently.
			
#					# TODO: Load loose GLTFs, OBJs, and PNGs.
#					if file_name.get_extension() == "obj":
#						print("Got an OBJ?")
#						var loaded_obj = load(full_path)
#						print(loaded_obj)
#
#					if file_name.get_extension() == "gltf":
#						print("Got a GLTF?")
#						var loaded_obj = load(full_path)
#						print(loaded_obj)
#
#					if file_name.get_extension() == "glb":
#						print("Got a GLB?")
#						var loaded_obj = load(full_path)
#						print(loaded_obj)
#
#					if file_name.get_extension() == "vrm":
#						print("Got a VRM?")
#						var loaded_obj = load(full_path)
#						print(loaded_obj)
			
				#file_name = dir.get_next()
	
func handle_channel_point_redeem(_redeemer_username, _redeemer_display_name, redeem_title, _user_input):
	
	if not bit_redeem:
		if redeem_title != "" and redeem_title == redeem_name:
			for k in range(count_multiplier):
				throw_random_object()

func handle_channel_chat_message(_cheerer_username, _cheerer_display_name, _message, bits_count):
	if bit_redeem and bits_count > 0:
		var throw_count = (bits_count / throws_per_bit) * count_multiplier
		for k in range(throw_count):
			throw_random_object()
	
func throw_random_object():
	
	# If there's nothing to throw, just return.
	if len(selected_throwables) < 1:
		printerr("Tried to throw an object with nothing in the throwable object list.")
		return

	# Find something to throw out of the list of stuff to throw and instantiate
	# it.
	var bit_scene_path = selected_throwables.pick_random()
	
	var executable_path : String = OS.get_executable_path().get_base_dir()
	if bit_scene_path.begins_with(executable_path):
		bit_scene_path = bit_scene_path.substr(len(executable_path) + 1)
	
	var bit_scene_packed = load(bit_scene_path)
	var bit_scene = bit_scene_packed.instantiate()

	thrown_object_queue.append(bit_scene)
	add_autodelete_object(bit_scene)

func add_head_impact_rotation(rot : Quaternion):
	head_impact_rotation_offset = head_impact_rotation_offset * rot

func _process(delta):
	
	var skel = get_skeleton()
	
	var head_index = get_skeleton().find_bone("Head")
	var neck_index = get_skeleton().find_bone("Neck")
	var chest_index = get_skeleton().find_bone("Chest")

	var current_rotation
	
	if head_index != -1:
		current_rotation = skel.get_bone_pose_rotation(head_index)
		skel.set_bone_pose_rotation(head_index, head_impact_rotation_offset * current_rotation)

	if neck_index != -1:
		current_rotation = skel.get_bone_pose_rotation(neck_index)
		skel.set_bone_pose_rotation(neck_index,
			head_impact_rotation_offset.slerp(Quaternion(0.0, 0.0, 0.0, 1.0), 0.5) * current_rotation)

	if chest_index != -1:
		current_rotation = skel.get_bone_pose_rotation(chest_index)
		skel.set_bone_pose_rotation(chest_index,
			head_impact_rotation_offset.slerp(Quaternion(0.0, 0.0, 0.0, 1.0), 0.75) * current_rotation)
	
	# SLERP back to rest rotation.
	head_impact_rotation_offset = \
		head_impact_rotation_offset.slerp(Quaternion(0.0, 0.0, 0.0, 1.0), delta * head_impact_rotation_return_speed)

func _physics_process(delta):

	# Figure out the rate to throw objects at. (TODO: Make configurable.)
	var throw_acceleration = log(float(thrown_object_queue.size()) / 100.0)
	if throw_acceleration < 0.0:
		throw_acceleration = 0.0
	throw_acceleration += 1.0
	if throw_acceleration > 5.0:
		throw_acceleration = 5.0
	throw_acceleration = pow(throw_acceleration, 4)

	thrown_object_cooldown -= delta * throw_acceleration

	if thrown_object_cooldown < 0:
		thrown_object_cooldown = 0.0
	
	# If we wanted to throw multiple objects per frame, we can make this a while
	# loop instead.
	if thrown_object_cooldown <= 0.0 and thrown_object_queue.size():

		if thrown_object_queue.size():
			
			# Reset cooldown.
			thrown_object_cooldown = thrown_object_cooldown_max
			
			# Get the next object to throw off the queue.
			var bit_scene = thrown_object_queue[0]
			thrown_object_queue.pop_front()
			
			bit_scene.thrower = self

			add_child(bit_scene)
			
			var head_position = Vector3(0.0, 1.8, 0.0)
			
			var skel = get_skeleton()
			# TODO: Make target bone configurable!
			var head_bone_index = skel.find_bone("Head")
			if head_bone_index != -1:
				var bone_transform = skel.global_transform * skel.get_bone_global_pose(head_bone_index)
				if bone_transform:
					head_position = bone_transform.origin

			# Pick a random position, as an offset from the targeted bone, in front of
			# the character.
			var random_start_position = Vector3(
				(randf() - 0.5) * 2,
				((randf() - 0.5) * 2) * 0.25,
				randf()).normalized() * 2.0

			# Add some variation to the velocity so it doesn't all come in at exactly
			# the same point.
			var velocity_randomness = Vector3(
				(randf() - 0.5) * 2,
				(randf() - 0.5) * 2,
				(randf() - 0.5) * 2).normalized() * randf() * 0.2

			# Set initial position and velocity.
			bit_scene.global_transform.origin = random_start_position + head_position
			bit_scene.linear_velocity = -random_start_position * 3.5 + velocity_randomness
			
			# Now let's do the math to give the projectile an arc. We're trying to find
			# time t, which is when the object would collide with the target, given the
			# velocity it has right now, if it were to go in a straight line.
			#
			#   random_start_position + bit_scene.linear_velocity * t = head_position
			#   (random_start_position - head_position) + bit_scene.linear_velocity * t = 0
			#   (random_start_position.length() - head_position.length()) + bit_scene.linear_velocity.length() * t = 0
			#   (random_start_position.length() - head_position.length()) = -bit_scene.linear_velocity.length() * t
			#   ((random_start_position.length() - head_position.length())) / -bit_scene.linear_velocity.length() = t
			var t = (random_start_position - head_position).length() / bit_scene.linear_velocity.length()

			# Determine a vertical velocity offset such that gravity would perfectly
			# negate it by the time we reach time t.
			var vertical_velocity_offset = 9.8 * t / 2.0
			bit_scene.linear_velocity[1] += vertical_velocity_offset
			bit_scene.set_gravity_scale(1.0)




func save_settings():
	var settings = {}
	settings["bit_redeem"] = bit_redeem
	settings["throws_per_bit"] = throws_per_bit
	settings["redeem_name"] = redeem_name
	settings["count_multiplier"] = count_multiplier
	settings["selected_throwables"] = selected_throwables.duplicate()
	return settings

func load_settings(settings_dict):
	bit_redeem = settings_dict["bit_redeem"]
	throws_per_bit = settings_dict["throws_per_bit"]
	redeem_name = settings_dict["redeem_name"]
	count_multiplier = settings_dict["count_multiplier"]
	selected_throwables = []
	for throwable in settings_dict["selected_throwables"]:
		selected_throwables.append(throwable)

func _create_settings_window():
	#var label = Label.new()
	#label.text = "THIS IS THE SETTINGS WIDGET FOR A THROWN OBJECT MOD"
	#return label
	var ui = load(
		get_script().resource_path.get_base_dir() + "/" +
		"UI/ObjectThrower_Settings.tscn").instantiate()
		
	var ui_throwable_list : ItemList = ui.get_node("%Value_ThrowableList")
	for throwable_name in throwable_list:
		var file_name = throwable_name.substr(
			throwable_name.get_base_dir().length())
		if file_name.length() and file_name[0] == "/":
			file_name = file_name.substr(1)
		ui_throwable_list.add_item(file_name)
	
	update_settings_ui(ui)
	ui.settings_modified.connect(update_settings_from_ui)

	return ui
	
func update_settings_ui(ui_window = null):
	
	if not ui_window:
		ui_window = get_settings_window()
	
	ui_window.get_node("%Value_BitOnlyRedeem").button_pressed = bit_redeem
	ui_window.get_node("%Value_ObjectsPerBit").value = throws_per_bit
	ui_window.get_node("%Value_CountMulitplier").value = count_multiplier
	ui_window.get_node("%Value_RedeemName").text = redeem_name
	
	var ui_throwable_list : ItemList = ui_window.get_node("%Value_ThrowableList")
	var item_count = ui_throwable_list.item_count
	for k in range(item_count):
		var item_text = throwable_list[k]
		if item_text in selected_throwables:
			ui_throwable_list.select(k, false)
		else:
			ui_throwable_list.deselect(k)

func update_settings_from_ui(ui_window = null):

	if not ui_window:
		ui_window = get_settings_window()

	bit_redeem = ui_window.get_node("%Value_BitOnlyRedeem").button_pressed
	throws_per_bit = ui_window.get_node("%Value_ObjectsPerBit").value
	count_multiplier = ui_window.get_node("%Value_CountMulitplier").value
	redeem_name = ui_window.get_node("%Value_RedeemName").text
	
	var ui_throwable_list : ItemList = ui_window.get_node("%Value_ThrowableList")
	var item_count = ui_throwable_list.item_count
	selected_throwables = []
	for k in range(item_count):
		if ui_throwable_list.is_selected(k):
			selected_throwables.append(throwable_list[k])
