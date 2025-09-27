class_name Gizmo3D
extends Node3D
## Gizmo3D encapsulates the Godot Engines 3D move/scale/rotation gizmos into a customizable node for use at runtime.
## The major differences are that you can edit all transformations at the same time, and customization options have
## been added.
##
## Translated from C++ to GDScript with alterations, from
## [url=https://github.com/godotengine/godot/blob/master/editor/plugins/node_3d_editor_plugin.h]source[/url] and
## [url=https://github.com/godotengine/godot/blob/master/editor/plugins/node_3d_editor_plugin.cpp]header[/url] file.

const DEFAULT_FLOAT_STEP := 0.001
const MAX_Z := 1000000.0

## The width for the move arrows - Godot value is .065f.
const GIZMO_ARROW_WIDTH = .12
## The height of the move arrows.
const GIZMO_ARROW_SIZE := 0.35
## Tolerance for interacting with rotation gizmo.
const GIZMO_RING_HALF_WIDTH := .1
## The size of the move and scale plane gizmos.
const GIZMO_PLANE_SIZE := .2
## Distance from center for plane gizmos.
const GIZMO_PLANE_DST := .3
## The circle size for the rotation gizmo.
const GIZMO_CIRCLE_SIZE := 1.1
## Distance from center for scale arrows.
const GIZMO_SCALE_OFFSET := GIZMO_CIRCLE_SIZE - .3
## Distance from center for move arrows - Godot value is GIZMO_CIRCLE_SIZE + .3f.
const GIZMO_ARROW_OFFSET := GIZMO_CIRCLE_SIZE + .15

## Used to limit which transformations are being edited.
@export_flags("Move", "Rotate", "Scale")
var mode = ToolMode.MOVE | ToolMode.SCALE | ToolMode.ROTATE

@export_flags_3d_render
var _layers := 1
## The 3D render layers this gizmo is visible on.
var layers: int:
	get:
		return _layers
	set(value):
		_layers = value
		if !is_node_ready():
			return
		for i in range(3):
			RenderingServer.instance_set_layer_mask(_move_gizmo_instance[i], _layers)
			RenderingServer.instance_set_layer_mask(_move_plane_gizmo_instance[i], _layers)
			RenderingServer.instance_set_layer_mask(_rotate_gizmo_instance[i], _layers)
			RenderingServer.instance_set_layer_mask(_scale_gizmo_instance[i], _layers)
			RenderingServer.instance_set_layer_mask(_scale_plane_gizmo_instance[i], _layers)
			RenderingServer.instance_set_layer_mask(_axis_gizmo_instance[i], _layers)
		RenderingServer.instance_set_layer_mask(_rotate_gizmo_instance[3], _layers)
		for key in _selections:
			var item = _selections[key]
			RenderingServer.instance_set_layer_mask(item.sbox_instance, _layers)
			RenderingServer.instance_set_layer_mask(item.sbox_instance_offset, _layers)
			RenderingServer.instance_set_layer_mask(item.sbox_xray_instance, _layers)
			RenderingServer.instance_set_layer_mask(item.sbox_xray_instance_offset, _layers)

## The nodes this gizmo will apply transformations to.
var _selections : Dictionary[Node3D, SelectedItem]
## Whether or not transformations will be snapped to rotate_snap, scale_snap, and/or translate_snap.
var _snapping : bool
## Shift modifier for snapping at lower intervals.
var _shift_snap : bool
## Whether or not transformations will be snapped to [member rotate_snap], [member scale_snap], and/or [member translate_snap].
var snapping: bool:
	get:
		return _snapping
var _message : String
## A displayable message describing the current transformation being applied, for example "Rotating: {60.000} degrees".
var message: String:
	get:
		return _message

var _editing: bool:
	set(value):
		if _editing and not value:
			emit_signal("transform_end", _edit.mode)
		_editing = value
		if !value:
			_message = ""
## If the user is currently interacting with is gizmo.
var editing: bool:
	get:
		return _editing

var _hovering: bool
## If the user is currently hovering over a gizmo.
var hovering: bool:
	get:
		return _hovering

@export_group("Style")
## The size of the gizmo before distance based scaling is applied.
@export_range(30, 200)
var size := 80.0
## If the X/Y/Z axes extending to infinity are drawn.
@export
var show_axes := true
## If the box encapsulating the target nodes is drawn.
@export
var show_selection_box := true
## Whether to show the line from the gizmo origin to the cursor when rotating.
@export
var show_rotation_line := true

## Alpha value for all gizmos and the selection box.
@export_range(0.0, 1.0)
var _opacity := .9
## Alpha value for all gizmos and the selection box.
var opacity : float:
	get:
		return _opacity
	set(value):
		if is_node_ready():
			_set_colors()
		_opacity = value

## The colors of the gizmos. 0 is the X axis, 1 is the Y axis, and 2 is the Z axis.
@export
var _colors : Array[Color] = [
	Color(0.96, 0.20, 0.32),
	Color(0.53, 0.84, 0.01),
	Color(0.16, 0.55, 0.96)
]
## The colors of the gizmos. 0 is the X axis, 1 is the Y axis, and 2 is the Z axis.
var colors : Array[Color]:
	get:
		return _colors
	set(value):
		if is_node_ready():
			_set_colors()
		_colors = value

## The color of the AABB surrounding the target nodes.
@export
var _selection_box_color := Color(1.0, .5, 0)
## The color of the AABB surrounding the target nodes.
var selection_box_color : Color:
	get:
		return _selection_box_color
	set(value):
		if is_node_ready():
			_selection_box_mat.albedo_color = Color(value, value.a * opacity)
			_selection_box_xray_mat.albedo_color = Color(value, value.a * opacity)
		_selection_box_color = value

@export_group("Position")
## Whether the gizmo is displayed using the targets local coordinate space, or the global space.
@export
var use_local_space : bool
## Value to snap rotations to, if enabled.
@export_range(0.0, 360.0)
var rotate_snap := 15.0
## Value to snap translations to, if enabled.
@export_range(0.0, 10.0)
var translate_snap := 1.0
## Value to snap scaling to, if enabled.
@export_range(0.0, 5.0)
var scale_snap := .25

var _move_gizmo : Array[ArrayMesh] = []
var _move_arrow_gizmo : Array[ArrayMesh] = []
var _move_plane_gizmo : Array[ArrayMesh] = []
var _rotate_gizmo : Array[ArrayMesh] = []
var _scale_gizmo : Array[ArrayMesh] = []
var _scale_plane_gizmo : Array[ArrayMesh] = []
var _axis_gizmo : Array[ArrayMesh] = []
var _gizmo_color : Array[StandardMaterial3D] = []
var _plane_gizmo_color : Array[StandardMaterial3D] = []
var _rotate_gizmo_color : Array[ShaderMaterial] = []
var _gizmo_color_hl : Array[StandardMaterial3D] = []
var _plane_gizmo_color_hl : Array[StandardMaterial3D] = []
var _rotate_gizmo_color_hl : Array[ShaderMaterial] = []

var _move_gizmo_instance : Array[RID] = []
var _move_arrow_gizmo_instance : Array[RID] = []
var _move_plane_gizmo_instance : Array[RID] = []
var _rotate_gizmo_instance : Array[RID] = []
var _scale_gizmo_instance : Array[RID] = []
var _scale_plane_gizmo_instance : Array[RID] = []
var _axis_gizmo_instance : Array[RID] = []

var _selection_box : ArrayMesh
var _selection_box_xray : ArrayMesh
var _selection_box_mat : StandardMaterial3D
var _selection_box_xray_mat : StandardMaterial3D

var _edit := EditData.new()
var _gizmo_scale := 1.0

var _surface : Control

enum ToolMode { MOVE = 1, ROTATE = 2, SCALE = 4, ALL = 7 }
enum TransformMode { NONE, ROTATE, TRANSLATE, SCALE }
enum TransformPlane { VIEW, X, Y, Z, YZ, XZ, XY }

## Emitted when the user begins interacting with the gizmo.
signal transform_begin(mode : TransformMode)
## Emitted as the user continues to interact with the gizmo.
## NOTE: For rotations, value is in radians.
signal transform_changed(mode : TransformMode, value : Vector3)
## Emitted when the user stops interacting with the gizmo.
signal transform_end(mode : TransformMode)

func _ready() -> void:
	_move_gizmo.resize(3)
	_move_arrow_gizmo.resize(3)
	_move_plane_gizmo.resize(3)
	_rotate_gizmo.resize(4)
	_scale_gizmo.resize(3)
	_scale_plane_gizmo.resize(3)
	_axis_gizmo.resize(3)
	_gizmo_color.resize(3)
	_plane_gizmo_color.resize(3)
	_rotate_gizmo_color.resize(4)
	_gizmo_color_hl.resize(3)
	_plane_gizmo_color_hl.resize(3)
	_rotate_gizmo_color_hl.resize(4)
	
	_move_gizmo_instance.resize(3)
	_move_arrow_gizmo_instance.resize(3)
	_move_plane_gizmo_instance.resize(3)
	_rotate_gizmo_instance.resize(4)
	_scale_gizmo_instance.resize(3)
	_scale_plane_gizmo_instance.resize(3)
	_axis_gizmo_instance.resize(3)
	
	_init_indicators()
	_set_colors()
	_init_gizmo_instance()
	_update_transform_gizmo()
	visibility_changed.connect(func(): _set_visibility(visible))
	
	_surface = Control.new()
	add_child(_surface)
	
	layers = _layers
	colors = _colors
	selection_box_color = _selection_box_color

## 2D drawing using the RenderingServer and surface Control.
## https://github.com/godotengine/godot/blob/65eb6643522abbe8ebce6428fe082167a7df14f9/editor/scene/3d/node_3d_editor_plugin.cpp#L3436
func _draw():
	var ci = _surface.get_canvas_item()
	RenderingServer.canvas_item_clear(ci)
	if _edit.mode == TransformMode.ROTATE and _edit.show_rotation_line and show_rotation_line:
		var center = _point_to_screen(_edit.center)
		
		var handleColor : Color
		match _edit.plane:
			TransformPlane.X:
				handleColor = colors[0]
			TransformPlane.Y:
				handleColor = colors[1]
			TransformPlane.Z:
				handleColor = colors[2]
		handleColor = Color.from_hsv(handleColor.h, 0.25, 1.0, 1)
		
		RenderingServer.canvas_item_add_line(
			ci,
			_edit.mouse_pos,
			center,
			handleColor,
			2)

## Get the current translation snap value.
## https://github.com/godotengine/godot/blob/65eb6643522abbe8ebce6428fe082167a7df14f9/editor/scene/3d/node_3d_editor_plugin.cpp#L9935
func get_translate_snap():
	var snap = translate_snap
	if _shift_snap:
		snap /= 10.0
	return snap

## Get the current rotation snap value.
## https://github.com/godotengine/godot/blob/65eb6643522abbe8ebce6428fe082167a7df14f9/editor/scene/3d/node_3d_editor_plugin.cpp#L9943
func get_rotation_snap():
	var snap = rotate_snap
	if _shift_snap:
		snap /= 3.0
	return snap

## Get the current scale snap value.
## https://github.com/godotengine/godot/blob/65eb6643522abbe8ebce6428fe082167a7df14f9/editor/scene/3d/node_3d_editor_plugin.cpp#L9951
func get_scale_snap():
	var snap = scale_snap
	if _shift_snap:
		snap /= 2.0
	return snap

func _unhandled_input(event : InputEvent) -> void:
	_hovering = false
	if !visible:
		_editing = false
	elif event is InputEventKey:
		if event.keycode == KEY_CTRL:
			_snapping = event.pressed
		elif event.keycode == KEY_SHIFT:
			_shift_snap = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if !event.pressed:
			_editing = false
			_update_transform_gizmo_view()
			_edit.mode = TransformMode.NONE
			return
		_edit.mouse_pos = event.position
		_editing = _transform_gizmo_select(event.position)
		if _editing:
			emit_signal("transform_begin", _edit.mode)
	elif event is InputEventMouseMotion:
		if _editing:
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_edit.mouse_pos = event.position
				var value := _update_transform(false)
				emit_signal("transform_changed", _edit.mode, value)
			return
		_hovering = _transform_gizmo_select(event.position, true)

#region Selection

## Add a node to the list of nodes currently being edited.
func select(target : Node3D) -> void:
	_selections[target] = _get_editor_data()

## Remove a node from the list of nodes currently being edited.
func deselect(target : Node3D) -> bool:
	var item = _selections.get(target)
	if item == null:
		return false
	_selections.erase(target)
	RenderingServer.free_rid(item.sbox_instance)
	RenderingServer.free_rid(item.sbox_instance_offset)
	RenderingServer.free_rid(item.sbox_xray_instance)
	RenderingServer.free_rid(item.sbox_xray_instance_offset)
	return true

## Check if a node is currently selected.
func is_selected(target : Node3D) -> bool:
	return _selections.has(target)

## Remove all nodes from the list of nodes currently being edited.
func clear_selection() -> void:
	for key in _selections:
		var item = _selections[key]
		RenderingServer.free_rid(item.sbox_instance)
		RenderingServer.free_rid(item.sbox_instance_offset)
		RenderingServer.free_rid(item.sbox_xray_instance)
		RenderingServer.free_rid(item.sbox_xray_instance_offset)
	_selections.clear()

## Get the number of nodes currently being edited.
func get_selected_count() -> int:
	return _selections.size()

#endregion

func _enter_tree() -> void:
	get_tree().root.focus_exited.connect(_on_focus_exited)

func _process(delta : float) -> void:
	_update_transform_gizmo()
	_draw()

func _exit_tree() -> void:
	get_tree().root.focus_exited.disconnect(_on_focus_exited)
	for i in range(3):
		RenderingServer.free_rid(_move_gizmo_instance[i])
		RenderingServer.free_rid(_move_arrow_gizmo_instance[i])
		RenderingServer.free_rid(_move_plane_gizmo_instance[i])
		RenderingServer.free_rid(_rotate_gizmo_instance[i])
		RenderingServer.free_rid(_scale_gizmo_instance[i])
		RenderingServer.free_rid(_scale_plane_gizmo_instance[i])
		RenderingServer.free_rid(_axis_gizmo_instance[i])
	RenderingServer.free_rid(_rotate_gizmo_instance[3])
	clear_selection()

func _on_focus_exited() -> void:
	_editing = false
	_hovering = false
	_snapping = false
	_shift_snap = false;

func _init_gizmo_instance() -> void:
	for i in range(3):
		_move_gizmo_instance[i] = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_move_gizmo_instance[i], _move_gizmo[i].get_rid())
		RenderingServer.instance_set_scenario(_move_gizmo_instance[i], get_world_3d().scenario)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_move_gizmo_instance[i], RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_layer_mask(_move_gizmo_instance[i], layers)
		RenderingServer.instance_geometry_set_flag(_move_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
		RenderingServer.instance_geometry_set_flag(_move_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
		
		_move_arrow_gizmo_instance[i] = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_move_arrow_gizmo_instance[i], _move_arrow_gizmo[i].get_rid())
		RenderingServer.instance_set_scenario(_move_arrow_gizmo_instance[i], get_world_3d().scenario)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_move_arrow_gizmo_instance[i], RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_layer_mask(_move_arrow_gizmo_instance[i], layers)
		RenderingServer.instance_geometry_set_flag(_move_arrow_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
		RenderingServer.instance_geometry_set_flag(_move_arrow_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
		
		_move_plane_gizmo_instance[i] = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_move_plane_gizmo_instance[i], _move_plane_gizmo[i].get_rid())
		RenderingServer.instance_set_scenario(_move_plane_gizmo_instance[i], get_world_3d().scenario)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_move_plane_gizmo_instance[i], RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_layer_mask(_move_plane_gizmo_instance[i], layers)
		RenderingServer.instance_geometry_set_flag(_move_plane_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
		RenderingServer.instance_geometry_set_flag(_move_plane_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
		
		_rotate_gizmo_instance[i] = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_rotate_gizmo_instance[i], _rotate_gizmo[i].get_rid())
		RenderingServer.instance_set_scenario(_rotate_gizmo_instance[i], get_world_3d().scenario)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_rotate_gizmo_instance[i], RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_layer_mask(_rotate_gizmo_instance[i], layers)
		RenderingServer.instance_geometry_set_flag(_rotate_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
		RenderingServer.instance_geometry_set_flag(_rotate_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
		
		_scale_gizmo_instance[i] = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_scale_gizmo_instance[i], _scale_gizmo[i].get_rid())
		RenderingServer.instance_set_scenario(_scale_gizmo_instance[i], get_world_3d().scenario)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_scale_gizmo_instance[i], RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_layer_mask(_scale_gizmo_instance[i], layers)
		RenderingServer.instance_geometry_set_flag(_scale_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
		RenderingServer.instance_geometry_set_flag(_scale_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
		
		_scale_plane_gizmo_instance[i] = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_scale_plane_gizmo_instance[i], _scale_plane_gizmo[i].get_rid())
		RenderingServer.instance_set_scenario(_scale_plane_gizmo_instance[i], get_world_3d().scenario)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_scale_plane_gizmo_instance[i], RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_layer_mask(_scale_plane_gizmo_instance[i], layers)
		RenderingServer.instance_geometry_set_flag(_scale_plane_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
		RenderingServer.instance_geometry_set_flag(_scale_plane_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
		
		_axis_gizmo_instance[i] = RenderingServer.instance_create()
		RenderingServer.instance_set_base(_axis_gizmo_instance[i], _axis_gizmo[i].get_rid())
		RenderingServer.instance_set_scenario(_axis_gizmo_instance[i], get_world_3d().scenario)
		RenderingServer.instance_geometry_set_cast_shadows_setting(_axis_gizmo_instance[i], RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF)
		RenderingServer.instance_set_layer_mask(_axis_gizmo_instance[i], layers)
		RenderingServer.instance_geometry_set_flag(_axis_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
		RenderingServer.instance_geometry_set_flag(_axis_gizmo_instance[i], RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
	
	_rotate_gizmo_instance[3] = RenderingServer.instance_create()
	RenderingServer.instance_set_base(_rotate_gizmo_instance[3], _rotate_gizmo[3].get_rid())
	RenderingServer.instance_set_scenario(_rotate_gizmo_instance[3], get_world_3d().scenario)
	RenderingServer.instance_geometry_set_cast_shadows_setting(_rotate_gizmo_instance[3], RenderingServer.ShadowCastingSetting.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_layer_mask(_rotate_gizmo_instance[3], layers)
	RenderingServer.instance_geometry_set_flag(_rotate_gizmo_instance[3], RenderingServer.InstanceFlags.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
	RenderingServer.instance_geometry_set_flag(_rotate_gizmo_instance[3], RenderingServer.InstanceFlags.INSTANCE_FLAG_USE_BAKED_LIGHT, false)

func _init_indicators() -> void:
	# Inverted zxy.
	var ivec := Vector3(0, 0, - 1)
	var nivec := Vector3(-1, -1, 0)
	var ivec2 := Vector3(-1, 0, 0)
	var ivec3 := Vector3(0, -1, 0)
	
	for i in range(3):
		_move_gizmo[i] = ArrayMesh.new()
		_move_arrow_gizmo[i] = ArrayMesh.new()
		_move_plane_gizmo[i] = ArrayMesh.new()
		_rotate_gizmo[i] = ArrayMesh.new()
		_scale_gizmo[i] = ArrayMesh.new()
		_scale_plane_gizmo[i] = ArrayMesh.new()
		_axis_gizmo[i] = ArrayMesh.new()
		
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.disable_fog = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		GizmoHelper.set_on_top_of_alpha(mat, true)
		_gizmo_color[i] = mat
		_gizmo_color_hl[i] = mat.duplicate()
		
#region Translate
		var surf_tool := _create_arrow([
			nivec * 0.0 + ivec * GIZMO_ARROW_OFFSET,
			nivec * 0.01 + ivec * GIZMO_ARROW_OFFSET,
			nivec * 0.01 + ivec * GIZMO_ARROW_OFFSET,
			nivec * GIZMO_ARROW_WIDTH + ivec * GIZMO_ARROW_OFFSET,
			nivec * 0.0 + ivec * (GIZMO_ARROW_OFFSET + GIZMO_ARROW_SIZE)
		], ivec, 5, 16)
		surf_tool.set_material(mat)
		surf_tool.commit(_move_gizmo[i])
		
		surf_tool = _create_arrow([
			nivec * 0.0 + ivec * 0.0,
			nivec * 0.01 + ivec * 0.0,
			nivec * 0.01 + ivec * GIZMO_ARROW_OFFSET,
			nivec * GIZMO_ARROW_WIDTH + ivec * GIZMO_ARROW_OFFSET,
			nivec * 0.0 + ivec * (GIZMO_ARROW_OFFSET + GIZMO_ARROW_SIZE)
		], ivec, 5, 16)
		surf_tool.set_material(mat)
		surf_tool.commit(_move_arrow_gizmo[i])
#endregion
#region Plane translation
		surf_tool = SurfaceTool.new()
		surf_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var vec := ivec2 - ivec3
		var plane := [
			vec * GIZMO_PLANE_DST,
			vec * GIZMO_PLANE_DST + ivec2 * GIZMO_PLANE_SIZE,
			vec * (GIZMO_PLANE_DST + GIZMO_PLANE_SIZE),
			vec * GIZMO_PLANE_DST - ivec3 * GIZMO_PLANE_SIZE
		]
		
		var ma := Basis(ivec, PI / 2)
		var points := [
			ma * plane[0],
			ma * plane[1],
			ma * plane[2],
			ma * plane[3]
		]
		surf_tool.add_vertex(points[0])
		surf_tool.add_vertex(points[1])
		surf_tool.add_vertex(points[2])

		surf_tool.add_vertex(points[0])
		surf_tool.add_vertex(points[2])
		surf_tool.add_vertex(points[3])
		
		var plane_mat := StandardMaterial3D.new()
		plane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plane_mat.disable_fog = true
		plane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plane_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		GizmoHelper.set_on_top_of_alpha(plane_mat,true)
		_plane_gizmo_color[i] = plane_mat
		surf_tool.set_material(plane_mat)
		surf_tool.commit(_move_plane_gizmo[i])
		_plane_gizmo_color_hl[i] = plane_mat.duplicate()
#endregion
#region Rotation
		surf_tool = SurfaceTool.new()
		surf_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		var CIRCLE_SEGMENTS := 128
		var CIRCLE_SEGMENT_THICKNESS := 3
		
		var step := TAU / CIRCLE_SEGMENTS
		for j in range(CIRCLE_SEGMENTS):
			var basis := Basis(ivec, j * step)
			var vertex := basis * (ivec2 * GIZMO_CIRCLE_SIZE)
			for k in range(CIRCLE_SEGMENT_THICKNESS):
				var ofs := Vector2(cos((TAU * k) / CIRCLE_SEGMENT_THICKNESS), sin((TAU * k) / CIRCLE_SEGMENT_THICKNESS))
				var normal := ivec * ofs.x + ivec2 * ofs.y
				surf_tool.set_normal(basis * normal)
				surf_tool.add_vertex(vertex)
		
		for j in range(CIRCLE_SEGMENTS):
			for k in range(CIRCLE_SEGMENT_THICKNESS):
				var current_ring := j * CIRCLE_SEGMENT_THICKNESS
				var next_ring := ((j + 1) % CIRCLE_SEGMENTS) * CIRCLE_SEGMENT_THICKNESS
				var current_segment := k
				var next_segment := (k + 1) % CIRCLE_SEGMENT_THICKNESS
				
				surf_tool.add_index(current_ring + next_segment)
				surf_tool.add_index(current_ring + current_segment)
				surf_tool.add_index(next_ring + current_segment)

				surf_tool.add_index(next_ring + current_segment)
				surf_tool.add_index(next_ring + next_segment)
				surf_tool.add_index(current_ring + next_segment)
		
		var rotate_shader := Shader.new()
		rotate_shader.code = r"
// 3D editor rotation manipulator gizmo shader.

shader_type spatial;

render_mode unshaded, depth_test_disabled, fog_disabled;

uniform vec4 albedo;

mat3 orthonormalize(mat3 m) {
	vec3 x = normalize(m[0]);
	vec3 y = normalize(m[1] - x * dot(x, m[1]));
	vec3 z = m[2] - x * dot(x, m[2]);
	z = normalize(z - y * (dot(y, m[2])));
	return mat3(x,y,z);
}

void vertex() {
	mat3 mv = orthonormalize(mat3(MODELVIEW_MATRIX));
	vec3 n = mv * VERTEX;
	float orientation = dot(vec3(0.0, 0.0, -1.0), n);
	if (orientation <= 0.005) {
		VERTEX += NORMAL * 0.02;
	}
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}"
		
		var rotate_mat := ShaderMaterial.new()
		rotate_mat.render_priority = Material.RENDER_PRIORITY_MAX
		rotate_mat.shader = rotate_shader
		_rotate_gizmo_color[i] = rotate_mat
		
		var arrays := surf_tool.commit_to_arrays()
		_rotate_gizmo[i].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_rotate_gizmo[i].surface_set_material(0, rotate_mat)
		
		_rotate_gizmo_color_hl[i] = rotate_mat.duplicate()
		
		if i == 2: # Rotation white outline
			var border_mat = rotate_mat.duplicate()
			
			var border_shader = Shader.new()
			border_shader.code = r"
// 3D editor rotation manipulator gizmo shader (white outline).

shader_type spatial;

render_mode unshaded, depth_test_disabled, fog_disabled;

uniform vec4 albedo;

mat3 orthonormalize(mat3 m) {
	vec3 x = normalize(m[0]);
	vec3 y = normalize(m[1] - x * dot(x, m[1]));
	vec3 z = m[2] - x * dot(x, m[2]);
	z = normalize(z - y * (dot(y, m[2])));
	return mat3(x, y, z);
}

void vertex() {
	mat3 mv = orthonormalize(mat3(MODELVIEW_MATRIX));
	mv = inverse(mv);
	VERTEX += NORMAL * 0.008;
	vec3 camera_dir_local = mv * vec3(0.0, 0.0, 1.0);
	vec3 camera_up_local = mv * vec3(0.0, 1.0, 0.0);
	mat3 rotation_matrix = mat3(cross(camera_dir_local, camera_up_local), camera_up_local, camera_dir_local);
	VERTEX = rotation_matrix * VERTEX;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
}"
			border_mat.shader = border_shader
			_rotate_gizmo_color[3] = border_mat
			
			_rotate_gizmo[3] = ArrayMesh.new()
			_rotate_gizmo[3].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			_rotate_gizmo[3].surface_set_material(0, border_mat)
#endregion
#region Scale
		surf_tool = _create_arrow([
			nivec * 0.0 + ivec * 0.0,
			nivec * 0.01 + ivec * 0.0,
			nivec * 0.01 + ivec * 1.0 * GIZMO_SCALE_OFFSET,
			nivec * 0.07 + ivec * 1.0 * GIZMO_SCALE_OFFSET,
			nivec * 0.07 + ivec * 1.2 * GIZMO_SCALE_OFFSET,
			nivec * 0.0 + ivec * 1.2 * GIZMO_SCALE_OFFSET
		], ivec, 6, 4)
		surf_tool.set_material(mat)
		surf_tool.commit(_scale_gizmo[i])
#endregion
#region Plane scale
		surf_tool = SurfaceTool.new()
		surf_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		
		vec = ivec2 - ivec3
		plane = [
			vec * GIZMO_PLANE_DST,
			vec * GIZMO_PLANE_DST + ivec2 * GIZMO_PLANE_SIZE,
			vec * (GIZMO_PLANE_DST + GIZMO_PLANE_SIZE),
			vec * GIZMO_PLANE_DST - ivec3 * GIZMO_PLANE_SIZE
		]
		
		ma = Basis(ivec, PI / 2)
		
		points = [
			ma * plane[0],
			ma * plane[1],
			ma * plane[2],
			ma * plane[3]
		]
		surf_tool.add_vertex(points[0])
		surf_tool.add_vertex(points[1])
		surf_tool.add_vertex(points[2])

		surf_tool.add_vertex(points[0])
		surf_tool.add_vertex(points[2])
		surf_tool.add_vertex(points[3])
		
		plane_mat = StandardMaterial3D.new()
		plane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plane_mat.disable_fog = true
		plane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plane_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		GizmoHelper.set_on_top_of_alpha(plane_mat, true)
		_plane_gizmo_color[i] = plane_mat
		surf_tool.set_material(plane_mat)
		surf_tool.commit(_scale_plane_gizmo[i])
		
		_plane_gizmo_color_hl[i] = plane_mat.duplicate()
#endregion
#region Lines to visualize transforms locked to an axis/plane
		surf_tool = SurfaceTool.new()
		surf_tool.begin(Mesh.PRIMITIVE_LINE_STRIP)
		
		vec = Vector3()
		vec[i] = 1
		# line extending through infinity(ish)
		surf_tool.add_vertex(vec * -1048576)
		surf_tool.add_vertex(Vector3())
		surf_tool.add_vertex(vec * 1048576)
		surf_tool.set_material(_gizmo_color_hl[i])
		surf_tool.commit(_axis_gizmo[i])
#endregion
	_generate_selection_boxes()

func _create_arrow(arrow : Array[Vector3], ivec : Vector3, arrow_points : int, arrow_sides : int) -> SurfaceTool:
	var surf_tool = SurfaceTool.new()
	surf_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		
	# Arrow profile	
	var arrow_sides_step := TAU / arrow_sides
	for k in range(arrow_sides):
		var maa := Basis(ivec, k * arrow_sides_step)
		var mbb := Basis(ivec, (k + 1) * arrow_sides_step)
		for j in range(arrow_points - 1):
			var apoints := [
				maa * arrow[j],
				mbb * arrow[j],
				mbb * arrow[j + 1],
				maa * arrow[j + 1]
			]
			surf_tool.add_vertex(apoints[0])
			surf_tool.add_vertex(apoints[1])
			surf_tool.add_vertex(apoints[2])
			
			surf_tool.add_vertex(apoints[0])
			surf_tool.add_vertex(apoints[2])
			surf_tool.add_vertex(apoints[3])
	return surf_tool

func _set_colors() -> void:
	for i in range(3):
		var col := Color(colors[i], colors[i].a * opacity)
		_gizmo_color[i].albedo_color = col
		_plane_gizmo_color[i].albedo_color = col
		_rotate_gizmo_color[i].set_shader_parameter("albedo", col)
		
		var albedo := Color.from_hsv(col.h, .25, 1.0, colors[i].a * opacity)
		_gizmo_color_hl[i].albedo_color = albedo
		_plane_gizmo_color_hl[i].albedo_color = albedo
		_rotate_gizmo_color_hl[i].set_shader_parameter("albedo", albedo)
	_rotate_gizmo_color[3].set_shader_parameter("albedo", Color(.75, .75, .75, opacity / 3.0))
	_select_gizmo_highlight_axis(-1)

func _update_transform_gizmo_view() -> void:
	if !visible:
		_set_visibility(false)
		return
	
	var camera := get_viewport().get_camera_3d()
	var xform := transform
	var camera_transform := camera.global_transform
	
	if xform.origin.is_equal_approx(camera_transform.origin):
		_set_visibility(false)
		return
	
	var camz := -camera_transform.basis[2].normalized()
	var camy := -camera_transform.basis[1].normalized()
	var p := Plane(camz, camera_transform.origin)
	var gizmoD := max(abs(p.distance_to(xform.origin)), 1e-06)
	var d0 = camera.unproject_position(camera_transform.origin + camz * gizmoD).y
	var d1 = camera.unproject_position(camera_transform.origin + camz * gizmoD + camy).y
	var dd = max(abs(d0 - d1), 1e-06)
	
	_gizmo_scale = size / abs(dd)
	var scale := Vector3.ONE * _gizmo_scale
	
	# if the determinant is zero, we should disable the gizmo from being rendered
	# this prevents supplying bad values to the renderer and then having to filter it out again
	if xform.basis.determinant() == 0:
		_set_visibility(false)
		return
	
	for i in range(3):
		var axis_angle : Transform3D
		if xform.basis[i].normalized().dot(xform.basis[(i + 1) % 3].normalized()) < 1.0:
			axis_angle = axis_angle.looking_at(xform.basis[i].normalized(), xform.basis[(i + 1) % 3].normalized())
		axis_angle.basis *= Basis.from_scale(scale)
		axis_angle.origin = xform.origin
		RenderingServer.instance_set_transform(_move_gizmo_instance[i], axis_angle)
		RenderingServer.instance_set_visible(_move_gizmo_instance[i], mode & ToolMode.MOVE and mode & ToolMode.SCALE)
		RenderingServer.instance_set_transform(_move_arrow_gizmo_instance[i], axis_angle)
		RenderingServer.instance_set_visible(_move_arrow_gizmo_instance[i], mode & ToolMode.MOVE and not mode & ToolMode.SCALE)
		RenderingServer.instance_set_transform(_move_plane_gizmo_instance[i], axis_angle)
		RenderingServer.instance_set_visible(_move_plane_gizmo_instance[i], mode & ToolMode.MOVE)
		RenderingServer.instance_set_transform(_rotate_gizmo_instance[i], axis_angle)
		RenderingServer.instance_set_visible(_rotate_gizmo_instance[i], mode & ToolMode.ROTATE)
		RenderingServer.instance_set_transform(_scale_gizmo_instance[i], axis_angle)
		RenderingServer.instance_set_visible(_scale_gizmo_instance[i], mode & ToolMode.SCALE)
		RenderingServer.instance_set_transform(_scale_plane_gizmo_instance[i], axis_angle)
		RenderingServer.instance_set_visible(_scale_plane_gizmo_instance[i], mode & ToolMode.SCALE and not (mode & ToolMode.MOVE))
		RenderingServer.instance_set_transform(_axis_gizmo_instance[i], xform)
	
	var show := show_axes and editing
	RenderingServer.instance_set_visible(_axis_gizmo_instance[0], show and (_edit.plane == TransformPlane.X || _edit.plane == TransformPlane.XY || _edit.plane == TransformPlane.XZ))
	RenderingServer.instance_set_visible(_axis_gizmo_instance[1], show and (_edit.plane == TransformPlane.Y || _edit.plane == TransformPlane.XY || _edit.plane == TransformPlane.YZ))
	RenderingServer.instance_set_visible(_axis_gizmo_instance[2], show and (_edit.plane == TransformPlane.Z || _edit.plane == TransformPlane.XZ || _edit.plane == TransformPlane.YZ))
	
	# Rotation white outline
	xform = xform.orthonormalized()
	xform.basis *= xform.basis.scaled(scale)
	RenderingServer.instance_set_transform(_rotate_gizmo_instance[3], xform)
	RenderingServer.instance_set_visible(_rotate_gizmo_instance[3], mode & ToolMode.ROTATE)
	
	# Selection box
	for key in _selections:
		var bounds := _calculate_spatial_bounds(key)
		
		var offset := Vector3(0.005, 0.005, 0.005)
		var aabb_s := Basis.from_scale(bounds.size + offset)
		var t = key.global_transform.translated_local(bounds.position - offset / 2)
		t.basis *= aabb_s
		
		offset = Vector3(0.01, 0.01, 0.01)
		aabb_s = Basis.from_scale(bounds.size + offset)
		var t_offset = key.global_transform.translated_local(bounds.position - offset / 2)
		t_offset.basis *= aabb_s
	
		var item = _selections[key]
		RenderingServer.instance_set_transform(item.sbox_instance, t)
		RenderingServer.instance_set_visible(item.sbox_instance, show_selection_box)
		RenderingServer.instance_set_transform(item.sbox_instance_offset, t_offset)
		RenderingServer.instance_set_visible(item.sbox_instance_offset, show_selection_box)
		RenderingServer.instance_set_transform(item.sbox_xray_instance, t)
		RenderingServer.instance_set_visible(item.sbox_xray_instance, show_selection_box)
		RenderingServer.instance_set_transform(item.sbox_xray_instance_offset, t_offset)
		RenderingServer.instance_set_visible(item.sbox_xray_instance_offset, show_selection_box)

func _set_visibility(visible : bool) -> void:
	for i in range(3):
		RenderingServer.instance_set_visible(_move_gizmo_instance[i], visible)
		RenderingServer.instance_set_visible(_move_arrow_gizmo_instance[i], visible)
		RenderingServer.instance_set_visible(_move_plane_gizmo_instance[i], visible)
		RenderingServer.instance_set_visible(_rotate_gizmo_instance[i], visible)
		RenderingServer.instance_set_visible(_scale_gizmo_instance[i], visible)
		RenderingServer.instance_set_visible(_scale_plane_gizmo_instance[i], visible)
		RenderingServer.instance_set_visible(_axis_gizmo_instance[i], visible)
	RenderingServer.instance_set_visible(_rotate_gizmo_instance[3], visible)
	for key in _selections:
		var item = _selections[key]
		RenderingServer.instance_set_visible(item.sbox_instance, visible)
		RenderingServer.instance_set_visible(item.sbox_instance_offset, visible)
		RenderingServer.instance_set_visible(item.sbox_xray_instance, visible)
		RenderingServer.instance_set_visible(item.sbox_xray_instance_offset, visible)

func _generate_selection_boxes():
	# Use two AABBs to create the illusion of a slightly thicker line.
	var aabb := AABB(Vector3(), Vector3.ONE)
	
	# Create a x-ray (visible through solid surfaces) and standard version of the selection box.
	# Both will be drawn at the same position, but with different opacity.
	# This lets the user see where the selection is while still having a sense of depth.
	var st := SurfaceTool.new()
	var st_xray := SurfaceTool.new()
	
	st.begin(Mesh.PRIMITIVE_LINES)
	st_xray.begin(Mesh.PRIMITIVE_LINES)
	for i in range(12):
		var edge = GizmoHelper.get_edge(aabb, i)
		st.add_vertex(edge[0])
		st.add_vertex(edge[1])
		st_xray.add_vertex(edge[0])
		st_xray.add_vertex(edge[1])
	
	_selection_box_mat = StandardMaterial3D.new()
	_selection_box_mat.shading_mode =BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_box_mat.disable_fog = true
	_selection_box_mat.albedo_color = selection_box_color
	_selection_box_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	st.set_material(_selection_box_mat)
	_selection_box = st.commit()
	
	_selection_box_xray_mat = StandardMaterial3D.new()
	_selection_box_xray_mat.shading_mode =BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_box_xray_mat.disable_fog = true
	_selection_box_xray_mat.no_depth_test = true
	_selection_box_xray_mat.albedo_color = selection_box_color * Color(1, 1, 1, .15)
	_selection_box_xray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	st_xray.set_material(_selection_box_xray_mat)
	_selection_box_xray = st.commit()

func _select_gizmo_highlight_axis(axis : int) -> void:
	for i in range(3):
		if i == axis:
			_move_gizmo[i].surface_set_material(0, _gizmo_color_hl[i])
			_move_arrow_gizmo[i].surface_set_material(0, _gizmo_color_hl[i])
		else:
			_move_gizmo[i].surface_set_material(0, _gizmo_color[i])
			_move_arrow_gizmo[i].surface_set_material(0, _gizmo_color[i])
		if i + 6 == axis:
			_move_plane_gizmo[i].surface_set_material(0, _plane_gizmo_color_hl[i])
		else:
			_move_plane_gizmo[i].surface_set_material(0, _plane_gizmo_color[i])
		if i + 3 == axis:
			_rotate_gizmo[i].surface_set_material(0, _rotate_gizmo_color_hl[i])
		else:
			_rotate_gizmo[i].surface_set_material(0, _rotate_gizmo_color[i])
		if i + 9 == axis:
			_scale_gizmo[i].surface_set_material(0, _gizmo_color_hl[i])
		else:
			_scale_gizmo[i].surface_set_material(0, _gizmo_color[i])
		if i + 12 == axis:
			_scale_plane_gizmo[i].surface_set_material(0, _plane_gizmo_color_hl[i])
		else:
			_scale_plane_gizmo[i].surface_set_material(0, _plane_gizmo_color[i])

func _update_transform_gizmo():
	var count := 0
	var gizmo_center : Vector3
	var gizmo_basis : Basis
	
	for key in _selections:
		var item = _selections[key]
		var xf = key.global_transform
		gizmo_center += xf.origin
		if count == 0 and use_local_space:
			gizmo_basis = xf.basis
		count += 1
	
	visible = count > 0
	transform.origin = (gizmo_center / count) if count > 0 else Vector3()
	transform.basis = gizmo_basis if count == 1 else Basis()
	
	_update_transform_gizmo_view()

func _get_editor_data() -> SelectedItem:
	var item = SelectedItem.new()
	item.sbox_instance = RenderingServer.instance_create2(_selection_box.get_rid(), get_world_3d().scenario)
	item.sbox_instance_offset = RenderingServer.instance_create2(_selection_box.get_rid(), get_world_3d().scenario)
	RenderingServer.instance_geometry_set_cast_shadows_setting(item.sbox_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_geometry_set_cast_shadows_setting(item.sbox_instance_offset, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_layer_mask(item.sbox_instance, layers)
	RenderingServer.instance_set_layer_mask(item.sbox_instance_offset, layers)
	RenderingServer.instance_geometry_set_flag(item.sbox_instance, RenderingServer.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
	RenderingServer.instance_geometry_set_flag(item.sbox_instance, RenderingServer.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
	RenderingServer.instance_geometry_set_flag(item.sbox_instance_offset, RenderingServer.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
	RenderingServer.instance_geometry_set_flag(item.sbox_instance_offset, RenderingServer.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
	item.sbox_xray_instance = RenderingServer.instance_create2(_selection_box.get_rid(), get_world_3d().scenario)
	item.sbox_xray_instance_offset = RenderingServer.instance_create2(_selection_box.get_rid(), get_world_3d().scenario)
	RenderingServer.instance_geometry_set_cast_shadows_setting(item.sbox_xray_instance, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_geometry_set_cast_shadows_setting(item.sbox_xray_instance_offset, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	RenderingServer.instance_set_layer_mask(item.sbox_xray_instance, layers)
	RenderingServer.instance_set_layer_mask(item.sbox_xray_instance_offset, layers)
	RenderingServer.instance_geometry_set_flag(item.sbox_xray_instance, RenderingServer.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
	RenderingServer.instance_geometry_set_flag(item.sbox_xray_instance, RenderingServer.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
	RenderingServer.instance_geometry_set_flag(item.sbox_xray_instance_offset, RenderingServer.INSTANCE_FLAG_IGNORE_OCCLUSION_CULLING, true)
	RenderingServer.instance_geometry_set_flag(item.sbox_xray_instance_offset, RenderingServer.INSTANCE_FLAG_USE_BAKED_LIGHT, false)
	return item

func _transform_gizmo_select(screen_pos : Vector2, highlight_only := false):
	if !visible:
		return false
	
	if _selections.size() == 0:
		if highlight_only:
			_select_gizmo_highlight_axis(-1)
		return false
	
	var ray_pos := _get_ray_pos(screen_pos)
	var ray := _get_ray(screen_pos)
	var gt := transform
	
	if mode & ToolMode.MOVE:
		var col_axis := -1
		var colD : float = 1e20
		
		for i in range(3):
			var grabber_pos = gt.origin + gt.basis[i].normalized() * _gizmo_scale * (GIZMO_ARROW_OFFSET + (GIZMO_ARROW_SIZE * 0.5))
			var grabber_radius := _gizmo_scale * GIZMO_ARROW_SIZE
			
			var r := Geometry3D.segment_intersects_sphere(ray_pos, ray_pos + ray * MAX_Z, grabber_pos, grabber_radius)
			if r.size() != 0:
				var d := r[0].distance_to(ray_pos)
				if d < colD:
					colD = d
					col_axis = i
		
		var is_plane_translate := false
		# plane select
		if col_axis == -1:
			colD = 1e20
			
			for i in range(3):
				var ivec2 := gt.basis[(i + 1) % 3].normalized()
				var ivec3 := gt.basis[(i + 2) % 3].normalized()
				
				# Allow some tolerance to make the plane easier to click,
				# even if the click is actually slightly outside the plane.
				var grabber_pos = gt.origin + (ivec2 + ivec3) * _gizmo_scale * (GIZMO_PLANE_SIZE + GIZMO_PLANE_DST * 0.6667)
				
				var plane := Plane(gt.basis[i].normalized(), gt.origin)
				var r := plane.intersects_ray(ray_pos, ray)
				
				if r != null:
					var dist = r.distance_to(grabber_pos)
					# Allow some tolerance to make the plane easier to click,
					# even if the click is actually slightly outside the plane.
					if dist < _gizmo_scale * GIZMO_PLANE_SIZE * 1.5:
						var d := ray_pos.distance_to(r)
						if d < colD:
							colD = d
							col_axis = i
							
							is_plane_translate = true
		
		if col_axis != -1:
			if highlight_only:
				var axis := col_axis
				if is_plane_translate:
					axis += 6
				_select_gizmo_highlight_axis(axis)
			else:
				# handle plane translate
				_edit.mode = TransformMode.TRANSLATE
				_compute_edit(screen_pos)
				_edit.plane = TransformPlane.X + col_axis
				if is_plane_translate:
					_edit.plane += 3
			return true
		
	if mode & ToolMode.ROTATE:
		var col_axis := -1
		
		var ray_length = gt.origin.distance_to(ray_pos) + (GIZMO_CIRCLE_SIZE * _gizmo_scale) * 4.0
		var result := Geometry3D.segment_intersects_sphere(ray_pos, ray_pos + ray * ray_length, gt.origin, _gizmo_scale * GIZMO_CIRCLE_SIZE)
		if result.size() != 0:
			var hit_position := result[0]
			var hit_normal := result[1]
			if hit_normal.dot(_get_camera_normal()) < .05:
				hit_position = (hit_position * gt).abs()
				var min_axis = hit_position.min_axis_index()
				if hit_position[min_axis] < _gizmo_scale * GIZMO_RING_HALF_WIDTH:
					col_axis = min_axis
		
		if col_axis == -1:
			var colD : float = 1e20
			
			for i in range(3):
				var plane := Plane(gt.basis[i].normalized(), gt.origin)
				var r := plane.intersects_ray(ray_pos, ray)
				if r == null:
					continue
				
				var dist = r.distance_to(gt.origin)
				var r_dir = (r - gt.origin).normalized()
				
				if _get_camera_normal().dot(r_dir) <= .005:
					if dist > _gizmo_scale * (GIZMO_CIRCLE_SIZE - GIZMO_RING_HALF_WIDTH) and dist < _gizmo_scale * (GIZMO_CIRCLE_SIZE + GIZMO_RING_HALF_WIDTH):
						var d = ray_pos.distance_to(r)
						if d < colD:
							colD = d
							col_axis = i
		
		if col_axis != -1:
			if highlight_only:
				_select_gizmo_highlight_axis(col_axis + 3)
			else:
				# handle rotate
				_edit.mode = TransformMode.ROTATE
				_compute_edit(screen_pos)
				_edit.plane = TransformPlane.X + col_axis
			return true
	
	if mode & ToolMode.SCALE:
		var col_axis := -1
		var colD : float = 1e20
		
		for i in range(3):
			var grabber_pos := gt.origin + gt.basis[i].normalized() * _gizmo_scale * GIZMO_SCALE_OFFSET
			var grabber_radius := _gizmo_scale * GIZMO_ARROW_SIZE
			
			var r := Geometry3D.segment_intersects_sphere(ray_pos, ray_pos + ray * MAX_Z, grabber_pos, grabber_radius)
			if r.size() != 0:
				var d := r[0].distance_to(ray_pos)
				if d < colD:
					colD = d
					col_axis = i
		
		var is_plane_scale = false
		# plane select
		if col_axis == -1:
			colD = 1e20
			
			for i in range(3):
				var ivec2 := gt.basis[(i + 1) % 3].normalized()
				var ivec3 := gt.basis[(i + 2) % 3].normalized()
				
				# Allow some tolerance to make the plane easier to click,
				# even if the click is actually slightly outside the plane
				var grabber_pos := gt.origin + (ivec2 + ivec3) * _gizmo_scale * (GIZMO_PLANE_SIZE + GIZMO_PLANE_DST * 0.6667)
				
				var plane := Plane(gt.basis[i].normalized(), gt.origin)
				var r := plane.intersects_ray(ray_pos, ray)
				
				if r:
					var dist = r.distance_to(grabber_pos)
					# Allow some tolerance to make the plane easier to click,
					# even if the click is actually slightly outside the plane.
					if dist < (_gizmo_scale * GIZMO_PLANE_SIZE * 1.5):
						var d := ray_pos.distance_to(r)
						if d < colD:
							colD = d
							col_axis = i
							
							is_plane_scale = true
		
		if col_axis != -1:
			if highlight_only:
				var plane := 9
				if is_plane_scale:
					plane = 12
				_select_gizmo_highlight_axis(col_axis + plane)
			else:
				# handle scale
				var plane := 0
				if is_plane_scale:
					plane = 3
				_edit.mode = TransformMode.SCALE
				_compute_edit(screen_pos)
				_edit.plane = TransformPlane.X + col_axis + plane
			return true
	
	if highlight_only:
		_select_gizmo_highlight_axis(-1)
	return false

func _transform_gizmo_apply(node : Node3D, transform : Transform3D, local : bool) -> void:
	if transform.basis.determinant() == 0:
		return
	if local:
		node.transform = transform
	else:
		node.global_transform = transform

func _compute_transform(mode : TransformMode, original : Transform3D, original_local : Transform3D, motion : Vector3, extra : float, local : bool, orthogonal : bool) -> Transform3D:
	match mode:
		TransformMode.SCALE:
			if snapping:
				motion = motion.snappedf(extra)
			var s : Transform3D
			if local:
				s.basis = original_local.basis * Basis.from_scale(motion + Vector3.ONE)
				s.origin = original_local.origin
			else:
				s.basis = s.basis.scaled(motion + Vector3.ONE)
				var base := Transform3D(Basis.IDENTITY, _edit.center)
				s = base * (s * (base.inverse() * original))
				# Recalculate orthogonalized scale without moving origin.
				if orthogonal:
					s.basis = GizmoHelper.scaled_orthogonal(original.basis, motion + Vector3.ONE)
			return s
		TransformMode.TRANSLATE:
			if snapping:
				motion = motion.snappedf(extra)
			if local:
				return original_local.translated_local(motion)
			return original.translated(motion)
		TransformMode.ROTATE:
			if local:
				var axis := original_local.basis * motion
				return Transform3D(
					Basis(axis.normalized(), extra) * original_local.basis,
					original_local.origin)
			else:
				var blocal := original.basis * original_local.basis.inverse()
				var axis := motion * blocal
				return Transform3D(
					blocal * Basis(axis.normalized(), extra) * original_local.basis,
					Basis(motion, extra) * (original.origin - _edit.center) + _edit.center)
	push_error("Gizmo3D#ComputeTransform: Invalid mode")
	return Transform3D()

func _update_transform(shift : bool) -> Vector3:
	var ray_pos := _get_ray_pos(_edit.mouse_pos)
	var ray := _get_ray(_edit.mouse_pos)
	var snap := DEFAULT_FLOAT_STEP
	
	match _edit.mode:
		TransformMode.SCALE:
			var smotion_mask : Vector3
			var splane : Plane
			var splane_mv := false
			
			match _edit.plane:
				TransformPlane.VIEW:
					smotion_mask = Vector3.ZERO
					splane = Plane(_get_camera_normal(), _edit.center)
				TransformPlane.X:
					smotion_mask = transform.basis[0].normalized()
					splane = Plane(smotion_mask.cross(smotion_mask.cross(_get_camera_normal())).normalized(), _edit.center)
				TransformPlane.Y:
					smotion_mask = transform.basis[1].normalized()
					splane = Plane(smotion_mask.cross(smotion_mask.cross(_get_camera_normal())).normalized(), _edit.center)
				TransformPlane.Z:
					smotion_mask = transform.basis[2].normalized()
					splane = Plane(smotion_mask.cross(smotion_mask.cross(_get_camera_normal())).normalized(), _edit.center)
				TransformPlane.YZ:
					smotion_mask = transform.basis[2].normalized() + transform.basis[1].normalized()
					splane = Plane(transform.basis[0].normalized(), _edit.center)
					splane_mv = true
				TransformPlane.XZ:
					smotion_mask = transform.basis[2].normalized() + transform.basis[0].normalized()
					splane = Plane(transform.basis[1].normalized(), _edit.center)
					splane_mv = true
				TransformPlane.XY:
					smotion_mask = transform.basis[0].normalized() + transform.basis[1].normalized()
					splane = Plane(transform.basis[2].normalized(), _edit.center)
					splane_mv = true
			
			var sintersection := splane.intersects_ray(ray_pos, ray)
			if sintersection == null:
				return Vector3.ZERO
			
			var sclick := splane.intersects_ray(_edit.click_ray_pos, _edit.click_ray)
			if sclick == null:
				return Vector3.ZERO
			
			var smotion = sintersection - sclick
			if _edit.plane != TransformPlane.VIEW:
				if !splane_mv:
					smotion = smotion_mask.dot(smotion) * smotion_mask
				elif shift: # Alternative planar scaling mode
					smotion = smotion_mask.dot(smotion) * smotion_mask
			else:
				var center_click_dist = sclick.distance_to(_edit.center)
				var center_inters_dist = sintersection.distance_to(_edit.center)
				if center_click_dist == 0:
					return Vector3.ZERO
				var sscale = center_inters_dist - center_click_dist
				smotion = Vector3(sscale, sscale, sscale)
			
			smotion /= sclick.distance_to(_edit.center)
			
			# Disable local transformation for TRANSFORM_VIEW
			var slocal_coords := use_local_space and _edit.plane != TransformPlane.VIEW
			
			if snapping:
				snap = get_scale_snap()
			if slocal_coords:
				smotion = _edit.original.basis.inverse() * smotion
			
			smotion = _edit_scale(smotion)
			
			var smotion_snapped = smotion.snappedf(snap)
			var x := "%.3f" % smotion_snapped.x
			var y := "%.3f" % smotion_snapped.y
			var z := "%.3f" % smotion_snapped.z
			_message = TranslationServer.translate("Scaling") + ": (" + x + ", " + y + ", " + z + ")"
			
			_apply_transform(smotion, snap)
			return smotion
		TransformMode.TRANSLATE:
			var tmotion_mask : Vector3
			var tplane : Plane
			var tplane_mv = false
			
			match _edit.plane:
				TransformPlane.VIEW:
					tplane = Plane(_get_camera_normal(), _edit.center)
				TransformPlane.X:
					tmotion_mask = transform.basis[0].normalized()
					tplane = Plane(tmotion_mask.cross(tmotion_mask.cross(_get_camera_normal())).normalized(), _edit.center)
				TransformPlane.Y:
					tmotion_mask = transform.basis[1].normalized()
					tplane = Plane(tmotion_mask.cross(tmotion_mask.cross(_get_camera_normal())).normalized(), _edit.center)
				TransformPlane.Z:
					tmotion_mask = transform.basis[2].normalized()
					tplane = Plane(tmotion_mask.cross(tmotion_mask.cross(_get_camera_normal())).normalized(), _edit.center)
				TransformPlane.YZ:
					tplane = Plane(transform.basis[0].normalized(), _edit.center)
					tplane_mv = true
				TransformPlane.XZ:
					tplane = Plane(transform.basis[1].normalized(), _edit.center)
					tplane_mv = true
				TransformPlane.XY:
					tplane = Plane(transform.basis[2].normalized(), _edit.center)
					tplane_mv = true
			
			var tintersection := tplane.intersects_ray(ray_pos, ray)
			if tintersection == null:
				return Vector3.ZERO
			
			var tclick := tplane.intersects_ray(_edit.click_ray_pos, _edit.click_ray)
			if tclick == null:
				return Vector3.ZERO
			
			var tmotion = tintersection - tclick
			if _edit.plane != TransformPlane.VIEW and !tplane_mv:
				tmotion = tmotion_mask.dot(tmotion) * tmotion_mask
			
			# Disable local transformation for TRANSFORM_VIEW
			var tlocal_coords := use_local_space and _edit.plane != TransformPlane.VIEW
			
			if snapping:
				snap = get_translate_snap()
			if tlocal_coords:
				tmotion = transform.basis.inverse() * tmotion
			
			tmotion = _edit_translate(tmotion)
			
			var tmotion_snapped = tmotion.snappedf(snap)
			var x := "%.3f" % tmotion_snapped.x
			var y := "%.3f" % tmotion_snapped.y
			var z := "%.3f" % tmotion_snapped.z
			_message = TranslationServer.translate("Translating") + ": (" + x + ", " + y + ", " + z + ")"
			
			_apply_transform(tmotion, snap)
			return tmotion
		TransformMode.ROTATE:
			var rplane : Plane
			var camera := get_viewport().get_camera_3d()
			if camera.projection == Camera3D.ProjectionType.PROJECTION_PERSPECTIVE:
				var cam_to_obj = _edit.center - camera.global_transform.origin
				if !cam_to_obj.is_zero_approx():
					rplane = Plane(cam_to_obj.normalized(), _edit.center)
				else:
					rplane = Plane(_get_camera_normal(), _edit.center)
			else:
				rplane = Plane(_get_camera_normal(), _edit.center)
			
			var local_axis : Vector3
			var global_axis : Vector3
			match _edit.plane:
				TransformPlane.VIEW:
					# local_axis unused
					global_axis = rplane.normal
				TransformPlane.X:
					local_axis = Vector3(1, 0, 0)
				TransformPlane.Y:
					local_axis = Vector3(0, 1, 0)
				TransformPlane.Z:
					local_axis = Vector3(0, 0, 1)
			
			if _edit.plane != TransformPlane.VIEW:
				global_axis = (transform.basis * local_axis).normalized()
			
			var rintersection := rplane.intersects_ray(ray_pos, ray)
			if rintersection == null:
				return Vector3.ZERO
			
			var rclick := rplane.intersects_ray(_edit.click_ray_pos, _edit.click_ray)
			if rclick == null:
				return Vector3.ZERO
			
			var orthogonal_threshold := cos(deg_to_rad(85.0))
			var axis_is_orthogonal = abs(rplane.normal.dot(global_axis)) < orthogonal_threshold
			
			var angle : float
			if axis_is_orthogonal:
				_edit.show_rotation_line = false
				var projection_axis := rplane.normal.cross(global_axis)
				var delta = rintersection - rclick
				var projection = delta.dot(projection_axis)
				angle = (projection * (PI / 2.0)) / (_gizmo_scale * GIZMO_CIRCLE_SIZE)
			else:
				_edit.show_rotation_line = true
				var click_axis = (rclick - _edit.center).normalized()
				var current_axis = (rintersection - _edit.center).normalized()
				angle = click_axis.signed_angle_to(current_axis, global_axis)
			
			if snapping:
				snap = get_rotation_snap()
			
			var rlocal_coords = use_local_space and _edit.plane != TransformPlane.VIEW # Disable local transformation for TRANSFORM_VIEW
			var compute_axis := global_axis
			if rlocal_coords:
				compute_axis = local_axis
			
			var result := _edit_rotate(compute_axis * angle)
			if result != compute_axis * angle:
				compute_axis = result.normalized()
				angle = result.length()
			
			angle = snappedf(rad_to_deg(angle), snap)
			var d := "%.3f" % angle
			_message = TranslationServer.translate("Rotating") + ": {" + d + "} " + TranslationServer.translate("degrees")
			angle = deg_to_rad(angle)
			
			_apply_transform(compute_axis, angle)
			return compute_axis * angle
	
	return Vector3.ZERO

func _apply_transform(motion : Vector3, snap : float) -> void:
	var is_local_coords := use_local_space and _edit.plane != TransformPlane.VIEW
	for key in _selections:
		var item = _selections[key]
		var new_transform := _compute_transform(_edit.mode, item.target_global, item.target_original, motion, snap, is_local_coords, _edit.plane != TransformPlane.VIEW)
		_transform_gizmo_apply(key, new_transform, is_local_coords)
		_update_transform_gizmo()

func _compute_edit(point: Vector2) -> void:
	_edit.click_ray = _get_ray(point)
	_edit.click_ray_pos = _get_ray_pos(point)
	_edit.plane = TransformPlane.VIEW
	_update_transform_gizmo()
	_edit.center = transform.origin
	_edit.original = transform
	for key in _selections:
		var item = _selections[key]
		item.target_global = key.global_transform
		item.target_original = key.transform
		_selections[key] = item

func _calculate_spatial_bounds(parent : Node3D, omit_top_level := false, bounds_orientation := Transform3D.IDENTITY) -> AABB:
	var bounds : AABB
	
	var tbounds_orientation : Transform3D
	if bounds_orientation != Transform3D.IDENTITY:
		tbounds_orientation = bounds_orientation
	else:
		tbounds_orientation = parent.global_transform
	
	if parent == null:
		return AABB(Vector3(-0.2, -0.2, -0.2), Vector3(0.4, 0.4, 0.4))
	
	var xform_to_top_level_parent_space := tbounds_orientation.affine_inverse() * parent.global_transform
	
	if parent is VisualInstance3D:
		bounds = parent.get_aabb()
	else:
		bounds = AABB()
	bounds = xform_to_top_level_parent_space * bounds
	
	for child in parent.get_children():
		if child is not Node3D:
			continue
		if !(omit_top_level and child.top_level):
			var child_bounds := _calculate_spatial_bounds(child, omit_top_level, tbounds_orientation)
			bounds = bounds.merge(child_bounds)
	
	return bounds

func _get_ray_pos(pos : Vector2) -> Vector3:
	return get_viewport().get_camera_3d().project_ray_origin(pos)

func _get_ray(pos : Vector2) -> Vector3:
	return get_viewport().get_camera_3d().project_ray_normal(pos)

func _get_camera_normal() -> Vector3:
	return -get_viewport().get_camera_3d().global_transform.basis[2]

func _point_to_screen(point : Vector3) -> Vector2:
	return get_viewport().get_camera_3d().unproject_position(point)

## Optional method to override the user translating the gizmo.
func _edit_translate(translation : Vector3) -> Vector3:
	return translation

## Optional method to override the user scaling the gizmo.
func _edit_scale(scale : Vector3) -> Vector3:
	return scale

## Optional method to override the user rotating the gizmo.
func _edit_rotate(rotation : Vector3) -> Vector3:
	return rotation
