class_name AltStreamIntegration
extends Mod_Base

# NOTE: Internal API, subject to change.
# Reference: https://github.com/MachaCeleste/AltStreamLib
const HOST     := "https://altstream.online"
const ENDPOINT := "/api/chat/stream?channel=%s"

class User:
	var username: String
	var display_name: String
	var avatar_url: String
	var user_color: Color
	func _to_string() -> String: return display_name

class Message:
	var id: String
	var text: String
	var sent_at: int
	var sticker_url: String
	var reply_to_id: String
	var reply_to_username: String
	var reply_to_display_name: String
	func _to_string() -> String: return text

signal connected
signal disconnected

signal chat_message(user: User, message: Message, reward_name: String)
signal chat_message_pinned(user: User, message: Message, pinned_by: String)
signal chat_message_unpinned()
signal chat_message_deleted(message_id: String)
signal chat_clear()

signal raid_incoming(from: User, raider_count: int)
signal raid_outgoing_start(target: User, viewer_count: int, countdown: int)
signal raid_outgoing_cancel()

signal reward_redeemed(user: User, message_id: int, reward_name: String, user_input: String)
signal shoutout(target: User, game_name: String, game_cover_url: String, shouted_by: User)

@export var autoconnect := true
@export var channel := ""

var has_initialized := false
var status_label := Label.new()
var connect_button := Button.new()
var client := EventStreamClient.new()
var timer: SceneTreeTimer

func _init() -> void:
	client.connected.connect(_on_connected)
	client.disconnected.connect(_on_disconnected)
	client.connection_failed.connect(_on_connection_failed)
	client.event_received.connect(_on_event_received)

	chat_message.connect(func(user: User, message: Message, _reward_name: String):
		get_app()._on_handle_channel_chat_message(user.username, user.display_name, message.text, 0))
	reward_redeemed.connect(func(user: User, _message_id: int, reward_name: String, user_input: String):
		get_app()._on_handle_channel_points_redeem(user.username, user.display_name, reward_name, user_input))
	raid_incoming.connect(func(user: User, raider_count: int):
		get_app()._on_handle_channel_raid(user.username, user.display_name, raider_count))

func _ready():
	add_tracked_setting("autoconnect", "Auto-connect on startup")
	add_tracked_setting("channel", "AltStream Channel")

	var settings: Container = get_settings_window()
	settings.add_child(status_label)
	settings.add_child(connect_button)
	connect_button.pressed.connect(_on_connect_pressed)

	var channel_widget: LineEdit = _settings_widgets_by_setting_name["channel"]
	channel_widget.text_changed.connect(func(_text: String): client.close())
	channel_widget.text_submitted.connect(func(_text: String):
		if client.status == EventStreamClient.Status.DISCONNECTED:
			_on_connect_pressed())

func scene_init() -> void:
	# This is called once when the mod is enabled, after settings have loaded,
	# but also when the model is changed, which we don't care about.
	if has_initialized: return
	has_initialized = true
	if autoconnect: _on_connect_pressed()

func _process(_delta: float) -> void:
	client.poll()
	match client.status:
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
	if client.status == EventStreamClient.Status.DISCONNECTED:
		if not channel.is_empty():
			client.connect_to_host(HOST, ENDPOINT % channel)
	else:
		client.close()

func _on_connected() -> void:
	print_log("Connected!")
	connected.emit()
func _on_disconnected(error: String) -> void:
	if error: print_log("Disconnected: " + error)
	else: print_log("Disconnected!")
	disconnected.emit()
func _on_connection_failed(error: String) -> void:
	if error: print_log("Failed to connect: " + error)
	else: print_log("Failed to connect!")

func _on_event_received(_event: String, data: String) -> void:
	var messages := JSON.parse_string(data) as Array
	if not messages: return

	for msg: Dictionary in messages:
		var source  := _try_get_string(msg, "source")
		var message := _message_from_msg(msg)
		var user    := _user_from_msg(msg)

		if source == "local":
			if user.username and user.display_name and message.text:
				chat_message.emit(user, message, "")
			return

		# "Special" messages (for the lack of an official name) typically come
		# in the format "[KIND]:{...}". While `source` may match kind, it may
		# also just be "system", so we'll just ignore it for this.
		var special := _special_regex.search(message.text)
		if special:
			var kind  := special.get_string(1)
			var value := special.get_string(2)
			message.text = "" # Don't ever expose this in our API.

			# Most of these hold a stringified JSON object which we're parsing
			# here, but there are exceptions, like `[DELETE]` and `[CLEAR_CHAT]`.
			var obj: Dictionary = JSON.parse_string(value) if value.begins_with("{") else {}

			match kind:
				"[HIGHLIGHT]":
					user.username    = _try_get_string(obj, "from")
					message.text     = _try_get_string(obj, "text")
					var reward_name := _try_get_string(obj, "rewardName")
					if user.username and user.display_name and message.text and reward_name:
						# Highlighted messages show up mostly as regular
						# chat messages, so we'll emit them as such.
						chat_message.emit(user, message, reward_name)

				"[CHAT_PIN]":
					user    = _user_from_msg(obj)
					message = _message_from_msg(obj)
					var pinned_by := _try_get_string(obj, "pinnedBy")
					if user.username and user.display_name and message.text and pinned_by:
						chat_message_pinned.emit(user, message, pinned_by)

				"[CHAT_UNPIN]":
					chat_message_unpinned.emit()

				"[DELETE]":
					var message_id := value
					chat_message_deleted.emit(message_id)

				"[CLEAR_CHAT]":
					chat_clear.emit()

				"[RAID_START]":
					var target := User.new()
					target.username     = _try_get_string(obj, "targetUsername")
					target.display_name = _try_get_string(obj, "targetDisplayName")
					target.avatar_url   = _try_get_string(obj, "targetImage")
					var viewers   := _try_get_int(obj, "viewers")
					var countdown := _try_get_int(obj, "countdownSeconds")
					if target.username and target.display_name:
						raid_outgoing_start.emit(target, viewers, countdown)

				"[RAID_CANCEL]":
					raid_outgoing_cancel.emit()

				"[REDEMPTION]":
					user.username    = _try_get_string(obj, "from")
					var reward_name := _try_get_string(obj, "rewardName")
					var user_input  := _try_get_string(obj, "userInput") # optional
					if user.username and user.display_name and reward_name:
						reward_redeemed.emit(user, message.id, reward_name, user_input)

				"[SHOUTOUT]":
					var target := User.new()
					target.username     = _try_get_string(obj, "targetUsername")
					target.display_name = _try_get_string(obj, "targetDisplayName")
					target.avatar_url   = _try_get_string(obj, "targetAvatar")
					var game_name      := _try_get_string(obj, "gameName")
					var game_cover_url := _try_get_string(obj, "gameCover")
					if target.username and target.display_name:
						shoutout.emit(user, game_name, game_cover_url, user)
			return

		# Incoming raid notifications have a unique text format that
		# we need to manually match and parse (see `_raid_regex`).
		var raid := _raid_regex.search(message.text)
		if raid:
			user.username = raid.get_string(1)
			var raider_count := int(raid.get_string(2))
			if user.username and user.display_name:
				raid_incoming.emit(user, raider_count)
			return


static var _special_regex := RegEx.create_from_string("^(\\[\\w+\\])(?:\\:(.*))?$")
static var _raid_regex    := RegEx.create_from_string("^@(\\w+) is raiding with a party of \"(\\d+)\"")

## Returns the value associated with `key` from this `Dictionary` as a `String`,
## or `default` if it's missing or a different data type (such as `TYPE_NIL`).
static func _try_get_string(dict: Dictionary, key: String, default := "") -> String:
	var variant = dict.get(key)
	return variant if (variant is String) else default

static func _try_get_int(dict: Dictionary, key: String, default := -1) -> int:
	var variant = dict.get(key)
	if variant is int: return variant
	elif variant is float: return roundi(variant)
	else: return default

static func _parse_color(value: String) -> Color:
	if value.is_empty(): return Color.WHITE
	var rgb := value.trim_prefix("#").hex_to_int()
	return Color.hex((rgb << 16) | 0x000000FF)

static func _user_from_msg(msg: Dictionary) -> User:
	var user := User.new()
	user.username     = _try_get_string(msg, "authorUsername")
	user.display_name = _try_get_string(msg, "author")
	user.avatar_url   = _try_get_string(msg, "authorImage")
	user.user_color   = _parse_color(
		_try_get_string(msg, "userColor"))
	return user

static func _message_from_msg(msg: Dictionary) -> Message:
	var message := Message.new()
	message.id          = _try_get_string(msg, "id")
	message.text        = _try_get_string(msg, "text")
	message.sent_at     = _try_get_int(msg, "sentAt")
	message.sticker_url = _try_get_string(msg, "stickerUrl")
	message.reply_to_id           = _try_get_string(msg, "replyToId")
	message.reply_to_username     = _try_get_string(msg, "replyToAuthor")
	message.reply_to_display_name = _try_get_string(msg, "replyToUsername")
	return message
