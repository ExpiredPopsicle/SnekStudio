extends Node3D
class_name ModelController

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

	# Attempt to load file.
	# FIXME: Determine of the flags used are still needed. Remove them if not.
	var gltf: GLTFDocument = GLTFDocument.new()
	var vrm_extension: GLTFDocumentExtension = load("res://addons/godot-vrm/vrm_extension.gd").new()
	GLTFDocument.register_gltf_document_extension(vrm_extension, true)
	var state: GLTFState = GLTFState.new()
	state.handle_binary_image = GLTFState.HANDLE_BINARY_EMBED_AS_UNCOMPRESSED
	var err = gltf.append_from_file(path, state,
		16 | #EditorSceneFormatImporter.IMPORT_USE_NAMED_SKIN_BINDS | 
		8 | #EditorSceneFormatImporter.IMPORT_GENERATE_TANGENT_ARRAYS |
		2) #EditorSceneFormatImporter.IMPORT_ANIMATION) #16 #EditorSceneFormatImporter.IMPORT_USE_NAMED_SKIN_BINDS)

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
	var secondary = $Model.get_node("secondary")
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

#	for k in range(0, 100):
#		if bone_mapping.profile.get_bone_name(k) == fixed_bone_name:
#			print("SDCSDCSDCSDSDSC")

	
	# FIXME: Just return the same thing that Skeletonfind_bone() returns when
	# it can't find a bone.
	#print("CANNOT FIND BONE: ", fixed_bone_name)
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

	anim_player.play("RESET")
	anim_player.advance(0)
	anim_player.stop()
