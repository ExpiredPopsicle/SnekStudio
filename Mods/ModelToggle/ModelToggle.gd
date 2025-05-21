extends Mod_Base

var model_name : String = ""
var redeem_name : String = ""
var start_hidden : bool = true
var time_until_undo : float = 0.0
var keybind_action_name : String = ""
var keybind_prefix : String = ""

var currently_toggled : bool = false
var current_time_until_undo : float = 0.0

func scene_init():
	var skel = get_skeleton()
	var model = skel.get_node_or_null(model_name)
	if model:
		model.visible = !start_hidden

func _reset_visibility():
	var skel = get_skeleton()
	var model = skel.get_node_or_null(model_name)
	if model:
		model.visible = true

func scene_shutdown():
	_reset_visibility()
	
func _update_model():
	var skel = get_skeleton()
	var model = skel.get_node_or_null(model_name)
	if model:
		if currently_toggled:
			model.visible = start_hidden
		else:
			model.visible = !start_hidden

func handle_channel_point_redeem(_redeemer_username, _redeemer_display_name, _redeem_title, _user_input):
	if _redeem_title == redeem_name:
		if currently_toggled and time_until_undo:
			current_time_until_undo += time_until_undo
		else:
			currently_toggled = !currently_toggled
			current_time_until_undo = time_until_undo
		
		_update_model()

func _input(event: InputEvent) -> void:
	if InputMap.has_action(keybind_prefix + keybind_action_name) \
		and event.is_action_pressed(keybind_prefix + keybind_action_name):
		print_log("Toggling via keybind.")
		currently_toggled = !currently_toggled
		_update_model()

func _handle_global_mod_message(key : String, values : Dictionary):
	if not key == "Keybinds":
		return
	keybind_prefix = values["prefix"]

func check_configuration() -> PackedStringArray:
	var errors : PackedStringArray = []
	
	if keybind_prefix == "" and keybind_action_name != "":
		errors.append("No Keybinds mod installed. Keybind toggle for model will not work.")

	return errors

func _process(delta):
	
	if current_time_until_undo > 0.0:
		current_time_until_undo -= delta
		if current_time_until_undo <= 0.0:
			currently_toggled = false
			_update_model()
			current_time_until_undo = 0.0

func load_before(_settings_old : Dictionary, _settings_new : Dictionary):
	_reset_visibility()

func load_after(_settings_old : Dictionary, _settings_new : Dictionary):
	_update_model()

func _ready():
	add_tracked_setting("start_hidden", "Start hidden")
	add_tracked_setting("model_name", "Model name")
	add_tracked_setting("keybind_action_name", "Toggle keybind action name")
	add_tracked_setting("redeem_name", "Redeem name", {"is_redeem" : true})
	add_tracked_setting("time_until_undo", "Time until reset", {"min": 0.0, "max":24*60})
	update_settings_ui()
