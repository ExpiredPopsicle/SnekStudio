class_name AltStreamIntegration
extends Mod_Base

@warning_ignore("shadowed_global_identifier")
static var EventStreamClient: GDScript = preload("res://Mods/AltStreamIntegration/EventStreamClient.gd")

@export var autoconnect := true
@export var channel := ""

var has_initialized := false
var status_label := Label.new()
var connect_button := Button.new()

func _ready() -> void:
	var alt_stream = $AltStream

	alt_stream.connected.connect(func():
		print_log("Connected!"))
	alt_stream.connection_failed.connect(func(error: String):
		if error: print_log("Failed to connect: " + error)
		else: print_log("Failed to connect!"))
	alt_stream.disconnected.connect(func(error: String):
		if error: print_log("Disconnected: " + error)
		else: print_log("Disconnected!"))

	alt_stream.chat_message_received.connect(func(user, message, _reward_name):
		get_app()._on_handle_channel_chat_message(user.username, user.display_name, message.text, 0))
	alt_stream.reward_redeemed.connect(func(user, _message_id, reward_name, user_input):
		get_app()._on_handle_channel_points_redeem(user.username, user.display_name, reward_name, user_input))
	alt_stream.raid_incoming.connect(func(user, raider_count):
		get_app()._on_handle_channel_raid(user.username, user.display_name, raider_count))

	add_tracked_setting("autoconnect", "Auto-connect on startup")
	add_tracked_setting("channel", "AltStream Channel")

	var settings: Container = get_settings_window()
	settings.add_child(status_label)
	settings.add_child(connect_button)
	connect_button.pressed.connect(_on_connect_pressed)

	var channel_widget: LineEdit = _settings_widgets_by_setting_name["channel"]
	channel_widget.text_changed  .connect(func(_text: String): alt_stream.stop())
	channel_widget.text_submitted.connect(func(_text: String): alt_stream.channel = channel)
	channel_widget.focus_exited  .connect(func(): alt_stream.channel = channel)

func scene_init() -> void:
	# This is called once when the mod is enabled, after settings have loaded,
	# but also when the model is changed, which we don't care about.
	if has_initialized: return
	has_initialized = true

	var alt_stream = $AltStream
	alt_stream.channel = channel
	if autoconnect: alt_stream.start()

func _process(_delta: float) -> void:
	match $AltStream.client.status:
		EventStreamClient.Status.CONNECTED:
			status_label.text = "Status: ✅ Connected"
			connect_button.text = "Disconnect"
		EventStreamClient.Status.CONNECTING:
			status_label.text = "Status: ⏳ Connecting ..."
			connect_button.text = "Disconnect"
		EventStreamClient.Status.DISCONNECTED:
			status_label.text = "Status: ❌ Disconnected"
			connect_button.text = "Connect"

func _on_connect_pressed() -> void:
	var alt_stream = $AltStream
	if alt_stream.client.status == EventStreamClient.Status.DISCONNECTED:
		alt_stream.channel = channel
		alt_stream.start()
	else:
		alt_stream.stop()
