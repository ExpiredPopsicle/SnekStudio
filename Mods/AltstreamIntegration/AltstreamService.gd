class_name AltstreamService
extends Node

const HOST     := "https://altstream.online"
const ENDPOINT := "/api/v2/chat/stream?channel=%s"

signal connected
signal connection_failed(error: String)
signal disconnected(error: String)

# Since replies and highlighted messages are practically identical to regular
# chat messages (with some extra sauce on top), we use a single shared signal.
# That way, you're free to ignore the sauce if you don't need it.

signal chat_message_received(message: Altstream.Message, reply_to: Altstream.Message, is_highlight: bool)
signal chat_sticker_received(message: Altstream.Message, sticker_name: String, sticker_url: String)
signal reward_redeemed(user: Altstream.User, message_id: String, reward_name: String, user_input: String)

signal chat_message_pinned(message_id: String)
signal chat_message_unpinned()
signal chat_message_deleted(message_id: String)
signal chat_cleared()

signal user_followed(user: Altstream.User)
signal channel_shouted_out(target: Altstream.User, shouted_by: Altstream.User)

signal raid_received(from: Altstream.User, viewers: int)
signal raid_outgoing_started(target: Altstream.User, viewers: int, countdown: int)
signal raid_outgoing_cancelled()

@export var autoconnect := true
@export var channel := ""

func start() -> void:
	if channel.is_empty():
		printerr("AltstreamService: no channel provided")
		return
	if client.status == EventStreamClient.Status.DISCONNECTED:
		client.connect_to_host(HOST, ENDPOINT % channel)

func stop() -> void:
	client.close()


# Above this comment is the public API of this type.
# Below you can find the implementation details.
# You should not need to access this.

var client := EventStreamClient.new()

func _init() -> void:
	client.connected.connect(connected.emit)
	client.connection_failed.connect(connection_failed.emit)
	client.disconnected.connect(disconnected.emit)
	client.event_received.connect(_on_event_received)

func _ready() -> void:
	if autoconnect and (not channel.is_empty()): start()

func _process(_delta: float) -> void:
	client.poll()

func _on_event_received(_event: String, event_data: String) -> void:
	var data: Dictionary = JSON.parse_string(event_data)
	match Altstream.Type.get(data.get("type").to_upper()):
		Altstream.Type.MESSAGE        : _handle_message(data)
		Altstream.Type.REPLY          : _handle_reply(data)
		Altstream.Type.HIGHLIGHT      : _handle_highlight(data)
		Altstream.Type.REDEMPTION     : _handle_redemption(data)

		Altstream.Type.PIN            : _handle_pin(data)
		Altstream.Type.UNPIN          : chat_message_unpinned.emit()
		Altstream.Type.DELETE         : chat_message_deleted.emit(data["targetId"])
		Altstream.Type.CLEAR          : chat_cleared.emit()

		Altstream.Type.TIP            : pass
		Altstream.Type.SHOP           : pass # TODO: Implement Ko-Fi events.
		Altstream.Type.SUBSCRIPTION   : pass

		Altstream.Type.FOLLOW         : _handle_follow(data)
		Altstream.Type.SHOUTOUT       : _handle_shoutout(data)

		Altstream.Type.RAID_RECEIVED  : _handle_raid_received(data)
		Altstream.Type.RAID_STARTED   : _handle_raid_started(data)
		Altstream.Type.RAID_CANCELLED : raid_outgoing_cancelled.emit()

func _handle_message(data: Dictionary) -> void:
	var message := _message_from_msg(data)
	if data.has("sticker"):
		var sticker_name : String = data["sticker"]["sticker_name"]
		var sticker_url  : String = data["sticker"]["sticker_url"]
		chat_sticker_received.emit(message.id, sticker_name, sticker_url)
	else:
		chat_message_received.emit(message, null, false)

func _handle_reply(data: Dictionary) -> void:
	var message := _message_from_msg(data)
	var reply_to := Altstream.Message.new()
	reply_to.id = data["reply"]["id"]
	reply_to.author = Altstream.User.new()
	reply_to.author.channel_name = data["reply"]["messageAuthorChannelName"]
	reply_to.author.display_name = data["reply"]["messageAuthorDisplayName"]
	chat_message_received.emit(message, reply_to, false)

func _handle_highlight(data: Dictionary) -> void:
	var message := _message_from_msg(data)
	# Highlighted message event doesn't contain reward information anymore?
	chat_message_received.emit(message, null, true)

func _handle_redemption(data: Dictionary) -> void:
	var message := _message_from_msg(data)
	var reward_name : String = data["redemption"]["rewardName"]
	var user_input  : String = data["redemption"].get("userInput", "")
	reward_redeemed.emit(message.author, message.id, reward_name, user_input)

func _handle_pin(msg: Dictionary) -> void:
	var pinned_message_id: String = msg["message"]["id"]
	# Pin message event doesn't contain anything besides `text` anymore?
	chat_message_pinned.emit(pinned_message_id)

func _handle_follow(data: Dictionary) -> void:
	var user := _user_from_msg(data["followedBy"])
	user_followed.emit(user)

func _handle_shoutout(data: Dictionary) -> void:
	var message := _message_from_msg(data)
	var target  := _user_from_msg(data["shoutout"]["target"])
	channel_shouted_out.emit(target, message.author)

func _handle_raid_received(data: Dictionary) -> void:
	var user    := _user_from_msg(data["raid"]["from"])
	var viewers := int(data["raid"]["viewers"])
	raid_received.emit(user, viewers)

func _handle_raid_started(data: Dictionary) -> void:
	var target    := _user_from_msg(data["raid"]["to"])
	var viewers   := int(data["raid"]["viewers"])
	var countdown := int(data["raid"]["countdownSeconds"])
	raid_outgoing_started.emit(target, viewers, countdown)


static func _message_from_msg(data: Dictionary) -> Altstream.Message:
	var message := Altstream.Message.new()
	message.id      = data["id"]
	message.sent_at = int(data["sentAt"])
	if data.has("author" ): message.author = _user_from_msg(data["author"])
	if data.has("message"): message.text   = data["message"].get("text", "")
	return message

static func _user_from_msg(author: Dictionary) -> Altstream.User:
	var user := Altstream.User.new()
	user.channel_name = author["channelName"]
	user.display_name = author["displayName"]
	user.pronouns     = author.get("pronouns", "")
	user.avatar_url   = author.get("image", "")
	user.color        = _parse_color(author.get("color", ""))

	for role: int in Altstream.Role.values():
		user.roles[role] = false
	if author.get("roles") is Dictionary:
		for role_name: String in author.roles:
			if not author.roles[role_name]: continue
			var role = _role_from_string(role_name)
			if role is Altstream.Role: user.roles[role] = true

	if author.get("badges") is Array:
		for badge_name: String in author.badges:
			var badge = _role_from_string(badge_name)
			if badge is Altstream.Role: user.badges.append(badge)

	return user

static func _role_from_string(s: String) -> Variant:
	match s:
		"broadcaster"         : return Altstream.Role.BROADCASTER
		"moderator"           : return Altstream.Role.MODERATOR
		"channelSubscriber"   : return Altstream.Role.ALTSTREAM_SUBSCRIBER
		"altstreamSubscriber" : return Altstream.Role.CHANNEL_SUBSCRIBER
		"follower"            : return Altstream.Role.FOLLOWER
		"isBot"               : return Altstream.Role.BOT
	return null

static func _parse_color(value: String) -> Color:
	if value.is_empty(): return Color.WHITE
	var rgb := value.trim_prefix("#").hex_to_int()
	return Color.hex((rgb << 16) | 0x000000FF)
