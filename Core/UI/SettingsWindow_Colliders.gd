@tool
class_name SettingsWindowColliders
extends BasicSubWindow

enum TreeItemType { BONE, COLLIDER }

## Known common bones that a user will likely want to add colliders to.
## By default, bones not in this list aren't listed in the hierarchy.
const KNOWN_BONES := [
	"Hips", "Spine", "Chest", "Neck", "Head",
	"LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"RightLowerLeg", "RightUpperLeg", "RightFoot",
]

const ICON_BONE     := preload("res://Core/UI/Images/godot/Bone.svg")
const ICON_SPHERE   := preload("res://Core/UI/Images/godot/SphereShape3D.svg")
const ICON_CAPSULE  := preload("res://Core/UI/Images/godot/CapsuleShape3D.svg")
const ICON_CYLINDER := preload("res://Core/UI/Images/godot/CylinderShape3D.svg")
const ICON_BOX      := preload("res://Core/UI/Images/godot/BoxShape3D.svg")

const AVATAR_COLLIDER := preload("res://Core/AvatarColliders/AvatarCollider.tscn")

# TODO: Click collider to select it.
# TODO: Differentiate between known, unknown and physical bones with icon.
# TODO: Implement toggles to hide unknown and/or physical bones.
# TODO: Implement shared collider settings.
# TODO: Improve default collider settings to include body, arms, hands and legs.
# TODO: Option to mirror changes / added colliders.
# TODO: Highlight selected bones.
# TODO: Revisit VRM colliders.

var collider_data_by_model_name: Dictionary[String, Array]

var items_by_bone_name : Dictionary[String, TreeItem]
var selected_item      : TreeItem

@onready var hierarchy : Tree = %Hierarchy

@onready var bone_options      : Container = %BoneOptions
@onready var collider_settings : Container = %ColliderSettings

@onready var pos      : Container = %Position
@onready var rot      : Container = %Rotation
@onready var sphere   : Container = %Sphere
@onready var capsule  : Container = %Capsule
@onready var cylinder : Container = %Cylinder
@onready var box      : Container = %Box


func load_settings(settings: Variant) -> void:
	# NOTE: This is a little workaround to ensure that each value in
	#       collider_data_by_model_name is actually a typed Array[Dictionary].
	collider_data_by_model_name = {}
	for model_name in settings:
		var colliders: Array[Dictionary]
		colliders.append_array(settings[model_name])
		collider_data_by_model_name[model_name] = colliders

func save_settings() -> Variant:
	return collider_data_by_model_name


## Saves the current collider data into collider_data_by_model_name.
## Note that this doesn't save the colliders to file (yet).
## The app needs to save its settings for that to happen.
func update_current_model_collider_data() -> void:
	var model_name: String = _get_app_root()._get_current_model_base_name()
	collider_data_by_model_name[model_name] = save_colliders()

## Get settings for colliders for this model, as an array of Dictionaries
## containing their settings (not the actual instantiated collider objects).
func get_collider_data_for_model_name(model_name: String, create_defaults_if_missing := false) -> Array[Dictionary]:
	if collider_data_by_model_name.has(model_name):
		return collider_data_by_model_name[model_name]
	if create_defaults_if_missing:
		var default_colliders := create_default_colliders(_get_skeleton())
		collider_data_by_model_name[model_name] = default_colliders
		return default_colliders
	return []

func create_default_colliders(_skeleton: Skeleton3D) -> Array[Dictionary]:
	return [
		{
			"bone_name" : "Head",
			"position"  : [ 0.0, 0.1, 0.02 ],
			"radius"    : 0.12,
		},
	]

func setup_for_current_model() -> void:
	hierarchy.clear()
	items_by_bone_name.clear()
	selected_item = null

	var skeleton := _get_skeleton()
	var hips_idx := skeleton.find_bone("Hips")
	assert(hips_idx >= 0) # TODO: Could the "Hips" bone be missing?

	_add_bone_recursive(skeleton, hips_idx, null)
	_set_unknown_visible_recursive(true, hierarchy.get_root())

	var model_name: String = _get_app_root()._get_current_model_base_name()
	var collider_data := get_collider_data_for_model_name(model_name, true)

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

	load_colliders(collider_data)
	#collider_data_by_model_name[model_name] = save_colliders()

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

func _get_skeleton() -> Skeleton3D:
	return _get_app_root().get_skeleton()

func _add_bone_recursive(skeleton: Skeleton3D, bone_idx: int, parent: TreeItem) -> TreeItem:
	var bone_name := skeleton.get_bone_name(bone_idx)
	var item := hierarchy.create_item(parent)
	item.set_icon(0, ICON_BONE)
	item.set_text(0, bone_name)
	item.set_text_overrun_behavior(0, TextServer.OverrunBehavior.OVERRUN_NO_TRIMMING)
	item.set_meta("type", TreeItemType.BONE)
	item.set_meta("bone_idx", bone_idx)
	item.set_meta("bone_name", bone_name)
	items_by_bone_name[bone_name] = item

	# Make sure that only known bones are expanded by default.
	# This avoids chains of spring bones taking up a lot of space.
	if not KNOWN_BONES.has(bone_name): item.collapsed = true

	for child_bone_idx in skeleton.get_bone_children(bone_idx):
		var child_item := _add_bone_recursive(skeleton, child_bone_idx, item)
		if not item.has_meta("first_bone_item"): item.set_meta("first_bone_item", child_item)

	return item

func _add_collider(collider_data: Dictionary) -> TreeItem:
	var collider: AvatarCollider = AVATAR_COLLIDER.instantiate()
	collider.load_settings(collider_data)
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
	collider.visible = visible
	return item

func _set_collider_visibility(value: bool) -> void:
	var skeleton := _get_skeleton()
	if not skeleton: return
	for child in skeleton.get_children():
		if child is AvatarCollider:
			child.visible = value

func _set_unknown_visible_recursive(value: bool, item: TreeItem) -> void:
	item.visible = value or KNOWN_BONES.has(item.get_text(0))
	for child in item.get_children(): _set_unknown_visible_recursive(value, child)


func show_window():
	super.show_window()
	_set_collider_visibility(true)

func close_window():
	super.close_window()
	_set_collider_visibility(false)


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
