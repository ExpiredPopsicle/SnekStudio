@tool
class_name SettingsWindowColliders
extends BasicSubWindow

enum TreeItemType { BONE, COLLIDER }

class ColliderDataGroup extends RefCounted:
	## Unique name identifying this group.
	## In the case of a single user, this must be equivalent to its filename.
	var name: String
	## The index into the "Share" OptionButton for this collider group.
	var option_idx: int
	## The model (file) names currently using this data group.
	## If there are multiple users, this entry will be shown as a group.
	var users: Array[String]
	## List of serialized AvatarCollider data.
	var data: Array[Dictionary]
	## Whether any settings on this collider group was changed.
	## If this is true, it won't be saved to disk.
	var is_default: bool

## Known common bones that a user will likely want to add colliders to.
## By default, bones not in this list aren't listed in the hierarchy.
const KNOWN_BONES := [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightLowerLeg", "RightUpperLeg", "RightFoot",
]

const ICON_BONE_KNOWN   := preload("res://Core/UI/Images/godot/Bone.svg")
const ICON_BONE_UNKNOWN := preload("res://Core/UI/Images/godot/Bone2D.svg")
const ICON_BONE_SPRING  := preload("res://Core/UI/Images/godot/DampedSpringJoint2D.svg")

const ICON_SPHERE   := preload("res://Core/UI/Images/godot/SphereShape3D.svg")
const ICON_CAPSULE  := preload("res://Core/UI/Images/godot/CapsuleShape3D.svg")
const ICON_CYLINDER := preload("res://Core/UI/Images/godot/CylinderShape3D.svg")
const ICON_BOX      := preload("res://Core/UI/Images/godot/BoxShape3D.svg")

const ICON_GROUP := preload("res://Core/UI/Images/godot/Folder.svg")

const AVATAR_COLLIDER := preload("res://Core/AvatarColliders/AvatarCollider.tscn")

# TODO: Improve default collider settings to include body, arms, hands and legs.
# TODO: Option to mirror changes / added colliders.
# TODO: Highlight selected bones.
# TODO: Revisit VRM colliders.

## Dictionary of collider groups keyed by their name.
var collider_groups : Dictionary[String, ColliderDataGroup]
## Dictionary of model file names and which collider group they use.
var model_files     : Dictionary[String, ColliderDataGroup]

var items_by_bone_name : Dictionary[String, TreeItem]
var selected_item      : TreeItem

@onready var hierarchy      : Tree   = %Hierarchy
@onready var toggle_unknown : Button = %ShowUnknown
@onready var toggle_spring  : Button = %ShowSpring

@onready var bone_options      : Container = %BoneOptions
@onready var collider_settings : Container = %ColliderSettings

@onready var pos      : Container = %Position
@onready var rot      : Container = %Rotation
@onready var sphere   : Container = %Sphere
@onready var capsule  : Container = %Capsule
@onready var cylinder : Container = %Cylinder
@onready var box      : Container = %Box

@onready var share     : OptionButton = %Share
@onready var rename    : Button       = %Rename
@onready var unlink    : Button       = %Unlink
@onready var reset     : Button       = %Reset
@onready var name_edit : LineEdit     = %NameEdit

var show_unknown: bool:
	get: return toggle_unknown.button_pressed
var show_spring: bool:
	get: return toggle_spring.button_pressed


func load_settings(settings: Variant) -> void:
	# Upgrading from SnekStudio v0.1.6
	if not settings.has("model_files"):
		var model_data := {}
		for model_name in settings: model_data[model_name] = model_name
		settings = { "collider_groups": settings, "model_files": model_data }

	collider_groups.clear()
	var groups: Dictionary = settings["collider_groups"]
	for group_name in groups:
		var data: Array = groups[group_name]
		var group := ColliderDataGroup.new()
		group.name = group_name
		group.data.append_array(data)
		collider_groups[group_name] = group

	model_files.clear()
	var models: Dictionary = settings["model_files"]
	for model_name in models:
		var group_name: String = models[model_name]
		var group := collider_groups[group_name]
		model_files[model_name] = group
		group.users.append(model_name)

func save_settings() -> Variant:
	var groups: Dictionary[String, Array]
	var models: Dictionary[String, String]

	for group_name in collider_groups:
		var group := collider_groups[group_name]
		if group.is_default: continue # skip if default
		groups[group_name] = group.data
		for model_name in group.users:
			models[model_name] = group_name

	return {
		"collider_groups" : groups,
		"model_files"     : models,
	}


func get_current_model_file_name() -> String:
	return _get_app_root()._get_current_model_base_name()

func get_current_collider_group(create_if_missing := false) -> ColliderDataGroup:
	var model_name := get_current_model_file_name()
	var group: ColliderDataGroup = model_files.get(model_name, null)
	if (group == null) and create_if_missing:
		group = _create_collider_group(model_name)
		group.data = create_default_colliders()
		group.is_default = true
		_update_share_options()
	return group

func create_default_colliders() -> Array[Dictionary]:
	return [
		{
			"bone_name" : "Head",
			"position"  : [ 0.0, 0.1, 0.02 ],
			"radius"    : 0.12,
		},
	]

func update_current_model_collider_data() -> void:
	var group := get_current_collider_group()
	group.data = save_colliders()
	group.is_default = false


func setup_for_current_model() -> void:
	hierarchy.clear()
	items_by_bone_name.clear()
	selected_item = null

	var skeleton := _get_skeleton()
	var hips_idx := skeleton.find_bone("Hips")
	assert(hips_idx >= 0) # TODO: Could the "Hips" bone be missing?

	_add_bone_recursive(skeleton, hips_idx, null)
	_update_bone_visibility_recursive(hierarchy.get_root())

	var model: Node3D = _get_app_root().get_model()
	var secondary: VRMSecondary = model.get_node_or_null("secondary")
	if secondary != null:
		# Mark bones as "spring bones" if they are defined as such in the VRM.
		for spring_bone in secondary.spring_bones:
			for bone_name in spring_bone.joint_nodes:
				var bone_item: TreeItem = items_by_bone_name.get(bone_name)
				if bone_item != null: bone_item.set_icon(0, ICON_BONE_SPRING)

	var group := get_current_collider_group(true)
	load_colliders(group.data)
	_update_share_options()
	share.select(group.option_idx)

	# This was disabled anyway, so I'm commenting it out.

	# # Clear "from_vrm" from everything loaded because we'll correlate
	# # loaded colliders in the next step.
	# for collider in collider_data:
	# 	collider["from_vrm"] = false

	# # Add colliders from VRM (the ones used for springbone collisions).
	# var model = $ModelController.get_node_or_null("Model")
	# if model:
	# 	var secondary_path = NodePath("secondary") #model.vrm_secondary
	# 	var secondary = model.get_node_or_null(secondary_path)

	# 	var do_vrm_colliders = false
	# 	if secondary != null and do_vrm_colliders:
	# 		var collider_groups = secondary.collider_groups
	# 		for collider_group in collider_groups:
	# 			for sphere_collider in collider_group.colliders:

	# 				# FIXME: Add support for capsules.
	# 				if sphere_collider.is_capsule:
	# 					continue

	# 				var bone_name = sphere_collider.bone

	# 				var new_collider = {}

	# 				new_collider["position"] = [
	# 					sphere_collider.offset[0],
	# 					sphere_collider.offset[1],
	# 					sphere_collider.offset[2]]

	# 				new_collider["radius"] = sphere_collider.radius
	# 				new_collider["bone_name"] = bone_name
	# 				new_collider["from_vrm"] = true

	# 				# See if this new one matches and existing collider.
	# 				var found_collider = null
	# 				for existing_collider in collider_data:
	# 					var fields_to_compare = [
	# 						"position", "radius",
	# 						"bone_name" ]

	# 					var is_this_collider = true
	# 					for field in fields_to_compare:
	# 						if not _compare_values(existing_collider[field], new_collider[field]):
	# 							is_this_collider = false
	# 							break

	# 					if is_this_collider:
	# 						existing_collider["from_vrm"] = true
	# 						found_collider = existing_collider
	# 						break

	# 				# No loaded collider found? Add it.
	# 				if found_collider == null:
	# 					collider_data.append(new_collider)


func load_colliders(colliders: Array[Dictionary]) -> void:
	var skeleton := _get_skeleton()

	# Clear out existing colliders.
	for child in skeleton.get_children():
		if child is not AvatarCollider: continue
		skeleton.remove_child(child)
		child.queue_free()

	for collider_data in colliders:
		_add_collider(collider_data)

func save_colliders() -> Array[Dictionary]:
	var colliders: Array[Dictionary]
	for child in _get_skeleton().get_children():
		if child is not AvatarCollider: continue
		colliders.append(child.save_settings())
	return colliders


func _ready():
	register_serializable_subwindow()
	visibility_changed.connect(func():
		# Keep collider visibility in sync with settings window.
		var is_window_visible := is_visible_in_tree()
		_set_collider_visibility(is_window_visible))

func _get_skeleton() -> Skeleton3D:
	return _get_app_root().get_skeleton()

func _add_bone_recursive(skeleton: Skeleton3D, bone_idx: int, parent: TreeItem) -> TreeItem:
	var bone_name := skeleton.get_bone_name(bone_idx)

	var is_known := KNOWN_BONES.has(bone_name)
	if is_known: _ensure_parents_always_visible(parent)
	# Spring bone detection is done separately in setup_for_current_model.
	var icon := ICON_BONE_KNOWN if is_known else ICON_BONE_UNKNOWN

	var item := hierarchy.create_item(parent)
	item.set_icon(0, icon)
	item.set_text(0, bone_name)
	item.set_text_overrun_behavior(0, TextServer.OverrunBehavior.OVERRUN_NO_TRIMMING)
	item.set_meta("type", TreeItemType.BONE)
	item.set_meta("bone_idx", bone_idx)
	item.set_meta("bone_name", bone_name)
	items_by_bone_name[bone_name] = item

	# Make sure that only known bones are expanded by default.
	# This avoids chains of spring bones taking up a lot of space.
	if not is_known: item.collapsed = true

	for child_bone_idx in skeleton.get_bone_children(bone_idx):
		var child_item := _add_bone_recursive(skeleton, child_bone_idx, item)
		if not item.has_meta("first_bone_item"): item.set_meta("first_bone_item", child_item)

	return item

## To ensure that parent items of known bones are always visible, this function
## is called recursive on its parents. For example, the samplesnek model has a
## "MaybeHips" bone that most of the rest of the skeleton is parented to.
func _ensure_parents_always_visible(item: TreeItem) -> void:
	if (item == null) or (item.get_icon(0) == ICON_BONE_KNOWN): return
	item.set_meta("always_visible", true)
	item.collapsed = false
	_ensure_parents_always_visible(item.get_parent())

func _add_collider(collider_data: Dictionary) -> TreeItem:
	var collider: AvatarCollider = AVATAR_COLLIDER.instantiate()
	collider.load_settings(collider_data)
	collider.body.input_event.connect(_on_collider_input_event.bind(collider))
	_get_skeleton().add_child(collider)

	var bone_item: TreeItem = items_by_bone_name.get(collider.bone_name)
	if bone_item == null: return null

	var item := hierarchy.create_item(bone_item)
	item.set_text_overrun_behavior(0, TextServer.OverrunBehavior.OVERRUN_NO_TRIMMING)
	item.set_meta("type", TreeItemType.COLLIDER)
	item.set_meta("collider", collider)

	if   collider.shape is SphereShape3D:   item.set_icon(0, ICON_SPHERE)  ; item.set_text(0, "Sphere")
	elif collider.shape is CapsuleShape3D:  item.set_icon(0, ICON_CAPSULE) ; item.set_text(0, "Capsule")
	elif collider.shape is CylinderShape3D: item.set_icon(0, ICON_CYLINDER); item.set_text(0, "Cylinder")
	elif collider.shape is BoxShape3D:      item.set_icon(0, ICON_BOX)     ; item.set_text(0, "Box")
	if collider.from_vrm: item.set_text(0, "[VRM] " + item.get_text(0))

	# Ensure that collider items show up before child bones. This makes
	# sure that if there's a lot of child bones (and their decendants)
	# the colliders show up next to the bone they're attached to.
	if bone_item.has_meta("first_bone_item"):
		item.move_before(bone_item.get_meta("first_bone_item"))

	collider.set_meta("tree_item", item)
	collider.visible = is_visible_in_tree()
	return item

func _set_collider_visibility(value: bool) -> void:
	var skeleton := _get_skeleton()
	if not skeleton: return
	for child in skeleton.get_children():
		if child is AvatarCollider:
			child.visible = value

func _update_bone_visibility_recursive(item: TreeItem) -> void:
	item.visible = true
	if not item.get_meta("always_visible", false):
		match item.get_icon(0):
			ICON_BONE_UNKNOWN : item.visible = show_unknown
			ICON_BONE_SPRING  : item.visible = show_spring
	for child in item.get_children():
		_update_bone_visibility_recursive(child)

func _update_share_options() -> void:
	var shared_group_names: Array[String]
	var unique_model_files: Array[String]
	for group_name in collider_groups:
		var num_users = collider_groups[group_name].users.size()
		if num_users > 1: shared_group_names.append(group_name)
		else:             unique_model_files.append(group_name)
	shared_group_names.sort()
	unique_model_files.sort()

	share.clear()
	for group_name in shared_group_names:
		share.add_icon_item(ICON_GROUP, group_name)
		collider_groups[group_name].option_idx = share.item_count - 1
	for model_file in unique_model_files:
		share.add_item(model_file)
		collider_groups[model_file].option_idx = share.item_count - 1

	var group := get_current_collider_group()
	var is_shared := (group.users.size() > 1)
	rename.disabled = not is_shared
	unlink.disabled = not is_shared
	reset .disabled = is_shared

	# In case the name was currently being edited.
	share.visible = true
	name_edit.visible = false


## Loads properties from the specified collider and updates the settings widgets with its values.
func _load_from_collider(collider: AvatarCollider) -> void:
	var body  := collider.body
	var shape := collider.shape

	rot     .visible = (shape is not SphereShape3D)
	sphere  .visible = (shape is SphereShape3D)
	capsule .visible = (shape is CapsuleShape3D)
	cylinder.visible = (shape is CylinderShape3D)
	box     .visible = (shape is BoxShape3D)

	_update_values(pos, body.position * 100)
	_update_values(rot, _stay_within_180(body.rotation_degrees))

	if   shape is SphereShape3D:   _update_values(sphere  , [ shape.radius * 100 ])
	elif shape is CapsuleShape3D:  _update_values(capsule , [ shape.radius * 100, shape.height * 100 ])
	elif shape is CylinderShape3D: _update_values(cylinder, [ shape.radius * 100, shape.height * 100 ])
	elif shape is BoxShape3D:      _update_values(box     , shape.size * 100)

## Helper function that will update child nodes with names "X", "Y" and "Z"
## (or fewer) with the specified values, which can be a Vector3 or Array[float].
func _update_values(group: Container, values: Variant) -> void:
	const NAMES := [ "X", "Y", "Z" ]
	if values is Vector3: values = [ values.x, values.y, values.z ]
	for i in range(values.size()): group.get_node(NAMES[i]).set_value_no_signal(values[i])

## Ensures that the input degrees are within -180° and +180°.
func _stay_within_180(deg: Vector3) -> Vector3:
	return Vector3(fmod(deg.x + 540, 360) - 180, fmod(deg.y + 540, 360) - 180, fmod(deg.z + 540, 360) - 180)

## Saves the settings widget's value to the specified collider, updating its properties.
func _save_to_collider(collider: AvatarCollider) -> void:
	collider.body.position = Vector3(pos.get_node("X").value, pos.get_node("Y").value, pos.get_node("Z").value) / 100
	collider.body.rotation_degrees = Vector3(rot.get_node("X").value, rot.get_node("Y").value, rot.get_node("Z").value)

	if collider.shape is SphereShape3D:
		collider.shape.radius = sphere.get_node("X").value / 100
	elif collider.shape is CapsuleShape3D:
		collider.shape.radius = capsule.get_node("X").value / 100
		collider.shape.height = capsule.get_node("Y").value / 100
	elif collider.shape is CylinderShape3D:
		collider.shape.radius = cylinder.get_node("X").value / 100
		collider.shape.height = cylinder.get_node("Y").value / 100
	elif collider.shape is BoxShape3D:
		collider.shape.size = Vector3(box.get_node("X").value, box.get_node("Y").value, box.get_node("Z").value) / 100


func _on_show_toggled(_toggled_on: bool) -> void:
	_update_bone_visibility_recursive(hierarchy.get_root())

func _on_hierarchy_item_selected() -> void:
	var item := hierarchy.get_selected()
	var item_type: TreeItemType = item.get_meta("type")

	bone_options.visible      = (item_type == TreeItemType.BONE)
	collider_settings.visible = (item_type == TreeItemType.COLLIDER)

	if selected_item != null:
		var prev_item_type: TreeItemType = selected_item.get_meta("type")
		match prev_item_type:
			TreeItemType.BONE:
				pass
			TreeItemType.COLLIDER:
				var prev_collider: AvatarCollider = selected_item.get_meta("collider")
				prev_collider.selected = false
	selected_item = item

	match item_type:
		TreeItemType.BONE:
			pass
		TreeItemType.COLLIDER:
			var collider: AvatarCollider = item.get_meta("collider")
			collider.selected = true
			_load_from_collider(collider)

func _on_collider_input_event(
	_camera: Node, event: InputEvent,
	_position: Vector3, _normal: Vector3, _shape_idx: int,
	collider: AvatarCollider,
) -> void:
	if not is_visible_in_tree(): return # don't do anything if window isn't visible
	var mouse := event as InputEventMouseButton
	if (mouse != null) and (mouse.button_index == MouseButton.MOUSE_BUTTON_LEFT) and mouse.pressed:
		var item: TreeItem = collider.get_meta("tree_item")
		hierarchy.set_selected(item, 0)
		hierarchy.ensure_cursor_is_visible()
		hierarchy.queue_redraw() # BUG: https://github.com/godotengine/godot/issues/98485
		collider.get_viewport().set_input_as_handled()

func _on_remove_pressed() -> void:
	var item := hierarchy.get_selected()
	var sibling_index := maxi(0, item.get_index() - 1)
	var bone_item := item.get_parent()
	var collider: AvatarCollider = item.get_meta("collider")
	item.free() # removes the item from the hierarchy

	_get_skeleton().remove_child(collider)
	update_current_model_collider_data()
	collider.queue_free()

	# Select a sibling collider, or if that doesn't exist, the parent bone item.
	var sibling_item := bone_item.get_child(sibling_index)
	if (sibling_item != null) and (sibling_item.get_meta("type") == TreeItemType.COLLIDER):
		sibling_item.select(0)
	else:
		bone_item.select(0)

func _on_add_sphere_pressed() -> void:
	_add_collider({ "bone_name": selected_item.get_meta("bone_name"), "shape": "SPHERE" }).select(0)
func _on_add_capsule_pressed() -> void:
	_add_collider({ "bone_name": selected_item.get_meta("bone_name"), "shape": "CAPSULE" }).select(0)
func _on_add_cylinder_pressed() -> void:
	_add_collider({ "bone_name": selected_item.get_meta("bone_name"), "shape": "CYLINDER" }).select(0)
func _on_add_box_pressed() -> void:
	_add_collider({ "bone_name": selected_item.get_meta("bone_name"), "shape": "BOX" }).select(0)

func _on_any_value_changed(_value: float) -> void:
	var item := hierarchy.get_selected()
	var collider: AvatarCollider = item.get_meta("collider")
	_save_to_collider(collider)
	update_current_model_collider_data()


func _on_rename_pressed() -> void:
	rename.disabled = true
	unlink.disabled = true
	reset .disabled = true
	share    .visible = false
	name_edit.visible = true
	name_edit.text = get_current_collider_group().name
	name_edit.grab_focus()

func _on_share_item_selected(index: int) -> void:
	var model_name := get_current_model_file_name()
	var old_group  := get_current_collider_group()
	_erase_user(old_group, model_name)
	var new_group_name := share.get_item_text(index)
	var new_group := collider_groups[new_group_name]
	new_group.users.append(model_name)
	model_files[model_name] = new_group
	_update_share_options()
	setup_for_current_model()

func _on_name_edit_text_submitted(new_text: String) -> void:
	var group := get_current_collider_group()
	var old_group_name := group.name
	var new_group_name := new_text.strip_edges()
	if old_group_name != new_group_name:
		_rename_group(group, new_group_name)
		_update_share_options()
	else:
		name_edit.release_focus()

func _on_name_edit_focus_exited() -> void:
	rename.disabled = false
	unlink.disabled = false
	reset .disabled = true
	share    .visible = true
	name_edit.visible = false

func _on_unlink_pressed() -> void:
	var model_name := get_current_model_file_name()
	var old_group  := get_current_collider_group()
	_erase_user(old_group, model_name)
	var new_group := _create_collider_group(model_name)
	new_group.data = old_group.data.duplicate(true)
	new_group.is_default = old_group.is_default
	_update_share_options()
	share.select(new_group.option_idx)

func _on_reset_pressed() -> void:
	var group := get_current_collider_group()
	group.data = create_default_colliders()
	group.is_default = true
	setup_for_current_model()


func _create_collider_group(model_name: String) -> ColliderDataGroup:
	var group := ColliderDataGroup.new()
	group.name = model_name
	group.users.append(model_name)
	collider_groups[model_name] = group
	model_files[model_name] = group
	return group

func _erase_user(group: ColliderDataGroup, model_name: String) -> void:
	group.users.erase(model_name)
	if group.users.is_empty():
		collider_groups.erase(group.name)
	if group.users.size() == 1:
		_rename_group(group, group.users[0])

func _rename_group(group: ColliderDataGroup, new_name: String) -> void:
	if group.name == new_name: return

	# Basic protection against reusing existing group/file names.
	# This isn't idiot proof. One could create a group by one name,
	# and later load a model with the same name, causing a conflict.
	var existing_model: ColliderDataGroup = model_files.get(new_name)
	assert((existing_model == null) or (existing_model == group))
	assert(not collider_groups.has(new_name))

	collider_groups.erase(group.name)
	collider_groups[new_name] = group
	group.name = new_name
