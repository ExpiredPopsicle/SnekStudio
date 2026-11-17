class_name AltStreamIntegration
extends Mod_Base

@export var autoconnect := true
@export var channel := ""

var has_initialized := false
var status_label := Label.new()
var connect_button := Button.new()

func _ready() -> void:
	var altstream = $AltstreamService

	altstream.connected.connect(func():
		print_log("Connected!"))
	altstream.connection_failed.connect(func(error: String):
		if error: print_log("Failed to connect: " + error)
		else: print_log("Failed to connect!"))
	altstream.disconnected.connect(func(error: String):
		if error: print_log("Disconnected: " + error)
		else: print_log("Disconnected!"))

	altstream.chat_message_received.connect(func(user, message, _reward_name):
		get_app()._on_handle_channel_chat_message(user.username, user.display_name, message.text, 0))
	altstream.reward_redeemed.connect(func(user, _message_id, reward_name, user_input):
		get_app()._on_handle_channel_points_redeem(user.username, user.display_name, reward_name, user_input))
	altstream.raid_incoming.connect(func(user, raider_count):
		get_app()._on_handle_channel_raid(user.username, user.display_name, raider_count))

	add_tracked_setting("autoconnect", "Auto-connect on startup")
	add_tracked_setting("channel", "Altstream Channel")

	var settings: Container = get_settings_window()
	settings.add_child(status_label)
	settings.add_child(connect_button)
	connect_button.pressed.connect(_on_connect_pressed)

	var channel_widget: LineEdit = _settings_widgets_by_setting_name["channel"]
	channel_widget.text_changed  .connect(func(_text: String): altstream.stop())
	channel_widget.text_submitted.connect(func(_text: String): altstream.channel = channel)
	channel_widget.focus_exited  .connect(func(): altstream.channel = channel)

func scene_init() -> void:
	# This is called once when the mod is enabled, after settings have loaded,
	# but also when the model is changed, which we don't care about.
	if has_initialized: return
	has_initialized = true

	var altstream = $AltstreamService
	altstream.channel = channel
	if autoconnect: altstream.start()

func _process(_delta: float) -> void:
	match $AltstreamService.client.status:
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
	var altstream = $AltstreamService
	if altstream.client.status == EventStreamClient.Status.DISCONNECTED:
		altstream.channel = channel
		altstream.start()
	else:
		altstream.stop()
