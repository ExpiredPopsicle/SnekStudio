class_name AltStreamIntegration
extends Mod_Base

@export var autoconnect := true
@export var channel := ""

var has_initialized := false
var status_label := Label.new()
var connect_button := Button.new()

@onready var altstream: AltstreamService = $AltstreamService

func _ready() -> void:
	altstream.connected.connect(func():
		print_log("Connected!"))
	altstream.connection_failed.connect(func(error: String):
		if error: print_log("Failed to connect: " + error)
		else: print_log("Failed to connect!"))
	altstream.disconnected.connect(func(error: String):
		if error: print_log("Disconnected: " + error)
		else: print_log("Disconnected!"))

	altstream.chat_message_received.connect(func(message: Altstream.Message, _reply_to: Altstream.Message, _is_highlight: bool):
		get_app()._on_handle_channel_chat_message(message.author.channel_name, message.author.display_name, message.text, 0))
	altstream.reward_redeemed.connect(func(user: Altstream.User, _message_id: String, reward_name: String, user_input: String):
		get_app()._on_handle_channel_points_redeem(user.channel_name, user.display_name, reward_name, user_input))
	altstream.raid_received.connect(func(user: Altstream.User, viewers: int):
		get_app()._on_handle_channel_raid(user.channel_name, user.display_name, viewers))

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

	# Wait until settings have been loaded, which happens after
	# the node is added to the scene tree and `_ready` is called.
	await get_tree().process_frame
	altstream.channel = channel
	if autoconnect: altstream.start()

func _process(_delta: float) -> void:
	var client := altstream.client
	match client.status:
		EventStreamClient.Status.CONNECTED:
			status_label.text = "Status: ✅ Connected"
			connect_button.text = "Disconnect"
		EventStreamClient.Status.CONNECTING:
			if not client.is_reconnecting:
				status_label.text = "Status: ⏳ Connecting ..."
			elif client.reconnection_delay <= 0.0:
				status_label.text = "Status: ♻️ Reconnecting ... (attempt #%d)" \
								  % client.reconnection_attempt
			else:
				status_label.text = "Status: ♻️ Reconnecting ... (attempt #%d, in %ds)" \
								  % [ client.reconnection_attempt, ceilf(client.reconnection_delay) ]
			connect_button.text = "Disconnect"
		EventStreamClient.Status.DISCONNECTED:
			status_label.text = "Status: ❌ Disconnected"
			connect_button.text = "Connect"

func _on_connect_pressed() -> void:
	if altstream.client.status == EventStreamClient.Status.DISCONNECTED:
		altstream.channel = channel
		altstream.start()
	else:
		altstream.stop()
