extends Node3D
class_name ModelController

const vrm_constants = preload("res://addons/godot-vrm/vrm_constants.gd")

var _last_loaded_vrm = ""

func _set_lod_bias_recursively(node):
	if node is MeshInstance3D:
		node.lod_bias = 128
	
	for child in node.get_children():
		_set_lod_bias_recursively(child)

func _rotate_meshinstances_recursively(node):
	if node is MeshInstance3D:
		node.basis = Basis(Vector3(0.0, 1.0, 0.0), PI)
	
	for child in node.get_children():
		_rotate_meshinstances_recursively(child)

func get_last_loaded_vrm():
	return _last_loaded_vrm

## Load a new VRM. Returns the newly instantiated scene's root node on success,
## or null on failure.
func load_vrm(path) -> Node3D:

	# If the file doesn't exist, return immediately.
	if not FileAccess.file_exists(path):
		push_error("Failed to load ", path, ": file does not exist.")
		return null

	# VRM 1.x extensions have to be loaded in a specific order, and in a way
	# that puts them before the internal extension that converts from stuff like
	# ImporterMeshInstance to MeshInstance3D.
	#
	# Yes, there is an internal extension that does that and it makes it very
	# confusing when the runtime loader doesn't act like the editor loader.
	var extension_paths : PackedStringArray = [
		"res://addons/godot-vrm/1.0/VRMC_vrm.gd",
		"res://addons/godot-vrm/1.0/VRMC_node_constraint.gd",
		"res://addons/godot-vrm/1.0/VRMC_springBone.gd",
		"res://addons/godot-vrm/1.0/VRMC_materials_hdr_emissiveMultiplier.gd",
		"res://addons/godot-vrm/1.0/VRMC_materials_mtoon.gd"
	]

	# We're going to load these all with first_priotity = true in the call to
	# register_gltf_document_extension, so we actually need to reverse the order
	# here that they end up in the correct order in the final extension list.
	extension_paths.reverse()

	# For cleanup later.
	var extensions: Array = []

	# Load all VRM 1.x extensions and register them, in reverse order.
	for extension_path in extension_paths:
		var extension = load(extension_path).new()
		assert(extension != null)
		GLTFDocument.register_gltf_document_extension(extension, true)
		extensions.append(extension)

	# Load up the VRM 0.0 extension.
	var vrm_extension: GLTFDocumentExtension = load("res://addons/godot-vrm/vrm_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm_extension, true)

	var gltf: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()

	# These options are copied from the VRM addon's loader.
	var options : Dictionary = {}
	state.set_additional_data(&"vrm/head_hiding_method", vrm_constants.HeadHidingSetting.IgnoreHeadHiding as vrm_constants.HeadHidingSetting)
	state.set_additional_data(&"vrm/first_person_layers", options.get(&"vrm/only_if_head_hiding_uses_layers/first_person_layers", 2) as int)
	state.set_additional_data(&"vrm/third_person_layers", options.get(&"vrm/only_if_head_hiding_uses_layers/third_person_layers", 4) as int)
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED

	# We need to hardcode these flag numbers here because we don't have access
	# to EditorSceneFormatImporter at runtime. I know it's annoying, but this
	# one is on the Godot devs.
	var flags: int = 1 | 16 | 8 | 2
		# 1  EditorSceneFormatImporter.IMPORT_SCENE
		# 2  EditorSceneFormatImporter.IMPORT_ANIMATION
		# 8  EditorSceneFormatImporter.IMPORT_GENERATE_TANGENT_ARRAYS
		# 16 EditorSceneFormatImporter.IMPORT_USE_NAMED_SKIN_BINDS

	# Attempt to load file.
	var err = gltf.append_from_file(path, state, flags)

	var generated_scene = null
	if err == OK:
		
		# Remove whatever was already there.
		var existing_model = get_node_or_null("Model")
		if existing_model:
			# We can't remove this from the scene immediately because some
			# signals need to be cleaned up which still require the model to be
			# in the scene. So let's just rename it to make room for the new one
			# and queue_free().
			existing_model.name = "Old_Model"
			existing_model.queue_free()
	
		# Add new model to the scene.
		generated_scene = gltf.generate_scene(state)
		generated_scene.name = "Model"
		add_child(generated_scene)

	# Cleanup.
	GLTFDocument.unregister_gltf_document_extension(vrm_extension)

	# Cleanup all the other extensions.
	for extension in extensions:
		assert(extension != null)
		GLTFDocument.unregister_gltf_document_extension(extension)

	# Fixup.
	_set_lod_bias_recursively(self)

	if generated_scene:
		_last_loaded_vrm = path

	return generated_scene

func get_model() -> Node3D:
	return get_node("Model")

func get_skeleton() -> Skeleton3D:

	var model : Node3D = get_model()
	if not model:
		return null

	# Try to find the skeleton on the secondary object first.
	var secondary = $Model.get_node_or_null("secondary")
	if secondary:
		if secondary is VRMSecondary:
			var skeleton2 : Skeleton3D = secondary.get_node(secondary.skeleton)
			return skeleton2

	# Buggy fallback.
	var skeleton = get_model().find_child("GeneralSkeleton", true, false)
	if skeleton:
		return skeleton

	skeleton = get_model().find_child("Skeleton3D", true, false)
	if skeleton:
		return skeleton

	return null

# Find a bone index based on the VRM bone name. This can be different from the
# bone name on the model itself. These names match the Unity humanoid.
func find_mapped_bone_index(bone_name : String):
	var bone_mapping = $Model.vrm_meta.humanoid_bone_mapping

	# Forcefully convert the bone name into the form of one uppercase letter
	# then all lowercase. eg foo -> Foo, FOO -> Foo, etc. This seems to be
	# the convention of the VRM importer or just the exporter I'm using.
	#var fixed_bone_name = bone_name[0].to_lower() + bone_name.substr(1)
	var fixed_bone_name = bone_name

	var skeleton : Skeleton3D = get_skeleton()
	
	var bone_index = bone_mapping.profile.find_bone(fixed_bone_name)
	if bone_index != -1:
		
		var mapped_bone_name = bone_mapping.get_skeleton_bone_name(fixed_bone_name)
		if mapped_bone_name != "":
			#var mapped_bone_name = bone_mapping[fixed_bone_name]
		
			var bone_index2 = skeleton.find_bone(mapped_bone_name)
			#print("  MAPPED BONE: ", mapped_bone_name, " ", bone_index2)
			if bone_index2 != -1:
				return bone_index2

	# Couldn't find the mapped bone name. Attempt to find the bone directly on
	# the model.
	var bone_index3 = skeleton.find_bone(fixed_bone_name)
	if bone_index3 != -1:
		return bone_index3

	return -1

## Get a bone's "global" (local to the skeleton objectm not the scene) pose.
func get_bone_transform(bone_name : String):

	var bone_index = find_mapped_bone_index(bone_name)
	if bone_index == -1:
		return null

	var skeleton : Skeleton3D = get_skeleton()
	if not skeleton:
		return null

	return skeleton.get_bone_global_pose(bone_index)

## Reset the whole skeleton to its rest position.
func reset_skeleton_to_rest_pose() -> void:
	var skel : Skeleton3D = get_skeleton()
	var bone_count : int = skel.get_bone_count()
	for bone_index in range(0, bone_count):
		skel.set_bone_pose(bone_index, skel.get_bone_rest(bone_index))

## Reset all the blend shapes to their neutral state.
func reset_blend_shapes() -> void:
	var anim_player : AnimationPlayer = $Model.find_child("AnimationPlayer", false, false)

	# FIXME: This is having issues starting in 4.4. Possibly internal Godot bug?
	if anim_player:
		anim_player.play("RESET")
		anim_player.advance(0)
		anim_player.stop()
