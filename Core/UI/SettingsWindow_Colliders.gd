extends BasicSubWindow

var _tree_items_by_bone = {}
var _root_item = null

func _add_collider(collider):
	var bone_name = collider["bone_name"]
	if bone_name in _tree_items_by_bone:
		var bone_item : TreeItem = _tree_items_by_bone[bone_name]
		var new_collider_item = %ColliderTree.create_item(bone_item)
		
		var collider_name = "Collider " + str(bone_item.get_child_count())
		if "from_vrm" in collider:
			if collider["from_vrm"]:
				collider_name = "[VRM] " + collider_name
		
		new_collider_item.set_text(0, collider_name)

	_update_sliders()

func update_from_app():
	var app = _get_app_root()
	var colliders = app.get_colliders()
	var skeleton : Skeleton3D = app.get_skeleton()
	
	# FIXME: Clear everything?
	_tree_items_by_bone = {}
	%ColliderTree.clear()
	var root = %ColliderTree.create_item()
	%ColliderTree.hide_root = true
	_root_item = root
	
	# Create tree items for all bones.
	for bone_index in skeleton.get_bone_count():
		var new_bone_item : TreeItem = %ColliderTree.create_item(root)
		var bone_name = skeleton.get_bone_name(bone_index)
		new_bone_item.set_text(0, bone_name)
		_tree_items_by_bone[bone_name] = new_bone_item
	
	# Create collider entries.
	for collider in colliders:
		_add_collider(collider)

	_update_sliders()

func _tag_current_collider(collider_list):
	var index = _get_selected_collider_index()
	if index == null:
		return
	
	collider_list[index]["selected"] = true

func _update_colliders_to_app(colliders):
	var app = _get_app_root()
	_tag_current_collider(colliders)
	for k in colliders:
		k["visible"] = visible
	app.set_colliders(colliders)

func _ready():
	register_serializable_subwindow()
	_update_sliders()

func _get_selected_bone():
	var selected_item : TreeItem = %ColliderTree.get_selected()
	if not selected_item:
		return null
		
	if selected_item.get_parent() == _root_item:
		return selected_item.get_text(0)
	else:
		return selected_item.get_parent().get_text(0)

func _get_selected_collider_in_bone():
	var selected_item : TreeItem = %ColliderTree.get_selected()
	if not selected_item:
		return null
		
	if selected_item.get_parent() == _root_item:
		return null
	else:
		return selected_item.get_index()
		

func _on_button_add_pressed():
	
	var bone_name = _get_selected_bone()
	if bone_name == null:
		return

	var app = _get_app_root()
	var colliders = app.get_colliders()
	
	var new_collider_entry = {}
	new_collider_entry["bone_name"] = bone_name
	new_collider_entry["radius"] = 0.5
	new_collider_entry["position"] = [0.0, 0.0, 0.0]
	colliders.append(new_collider_entry)
	_update_colliders_to_app(colliders)
	
	_add_collider(new_collider_entry)
	_update_sliders()

func _get_selected_collider_index():
	var collider_index = _get_selected_collider_in_bone()
	var bone_name = _get_selected_bone()
	
	var app = _get_app_root()
	var colliders = app.get_colliders()
	
	var found_collider = null
	var colliders_this_bone = 0
	var total_index = 0
	for c in colliders:
		if c["bone_name"] == bone_name:
			if colliders_this_bone == collider_index:
				found_collider = total_index
				break
			colliders_this_bone += 1
		total_index += 1

	return found_collider

func _on_button_remove_pressed():

	var collider_index = _get_selected_collider_in_bone()
	var bone_name = _get_selected_bone()
	
	var app = _get_app_root()
	var colliders = app.get_colliders()
	
	var found_collider = null
	var colliders_this_bone = 0
	var total_index = 0
	for c in colliders:
		if c["bone_name"] == bone_name:
			if colliders_this_bone == collider_index:
				found_collider = total_index
				break
			colliders_this_bone += 1
		total_index += 1

	if found_collider != null:
		
		var can_remove = true
		var collider_dict = colliders[found_collider]
		
		# Check to see if this is a VRM bone that we can't delete.
		if "from_vrm" in collider_dict:
			if collider_dict["from_vrm"]:
				can_remove = false

		if can_remove:
			colliders.remove_at(found_collider)
			_update_colliders_to_app(colliders)


	update_from_app()
	_update_sliders()

var _ignore_value_changed_temporarily = 0

func _update_sliders():
	
	_ignore_value_changed_temporarily += 1
	
	var selected_collider = _get_selected_collider_index()
	if not (selected_collider == null):
		%Slider_Container.visible = true
			
		var app = _get_app_root()
		var colliders = app.get_colliders()
		var actual_collider = colliders[selected_collider]

		%Position_Slider_X.value = actual_collider["position"][0]
		%Position_Slider_Y.value = actual_collider["position"][1]
		%Position_Slider_Z.value = actual_collider["position"][2]
		%Radius_Slider.value = actual_collider["radius"]
		
		%Radius_Slider.disabled = actual_collider["from_vrm"]
		%Position_Slider_X.disabled = actual_collider["from_vrm"]
		%Position_Slider_Y.disabled = actual_collider["from_vrm"]
		%Position_Slider_Z.disabled = actual_collider["from_vrm"]
		
		%CheckBox_Enabled.button_pressed = actual_collider["enabled"]

	else:
		%Slider_Container.visible = false
		
	_ignore_value_changed_temporarily -= 1

func _on_collider_tree_item_selected():
	_update_sliders()

	var app = _get_app_root()
	var colliders = app.get_colliders()
	_update_colliders_to_app(colliders)

func _on_slider_value_changed(value):
	
	if _ignore_value_changed_temporarily != 0:
		return
	
	_ignore_value_changed_temporarily += 1
	
	var selected_collider = _get_selected_collider_index()
	if not (selected_collider == null):
		var app = _get_app_root()
		var colliders = app.get_colliders()
		var actual_collider = colliders[selected_collider]
		
		actual_collider["position"] = [
			%Position_Slider_X.value,
			%Position_Slider_Y.value,
			%Position_Slider_Z.value]		
		
		actual_collider["radius"] = %Radius_Slider.value
		
		actual_collider["enabled"] = %CheckBox_Enabled.button_pressed
		
		_update_colliders_to_app(colliders)

	
	_ignore_value_changed_temporarily -= 1

func _on_check_box_enabled_pressed():
	_on_slider_value_changed(0)

func close_window():
	super.close_window()
	
	var root = _get_app_root()
	var skeleton = root.get_skeleton()
	if not skeleton:
		return
		
	for child in skeleton.get_children():
		if child is AvatarCollider:
			child.set_hidden(true)

func show_window():
	super.show_window()

	# Force an update so we reset visibilty on colliders.
	var app = _get_app_root()
	var colliders = app.get_colliders()
	_update_colliders_to_app(colliders)

	var root = _get_app_root()
	var skeleton = root.get_skeleton()
	if not skeleton:
		return
		
	for child in skeleton.get_children():
		print(child)
		if child is AvatarCollider:
			child.show()
