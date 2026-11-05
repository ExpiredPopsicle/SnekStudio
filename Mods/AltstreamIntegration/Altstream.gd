class_name AltStream
extends Node

# This is required for SnekStudio runtime mod loading.
# If you're using these types in your own project, get rid of these two lines!
@warning_ignore("shadowed_global_identifier")
static var EventStreamClient: GDScript = preload("res://Mods/AltstreamIntegration/EventStreamClient.gd")

const HOST     := "https://altstream.online"
const ENDPOINT := "/api/chat/stream?channel=%s"

enum Role {
	BROADCASTER, # The streamer.
	MODERATOR,   # Channel moderator.
	SUBSCRIBER,  # Platform supporter.
	SUPPORTER,   # Channel supporter.
	# NOTE: Yes this is confusing. Hopefully it'll will get fixed.
}

# NOTE: Some fields are available depending on the message type.
#       For example, `username` and `roles` might not be set as expected.

class User:
	var username     : String
	var display_name : String # "author" in the API
	var pronouns     : String
	var roles        : Dictionary[Role, bool]
	var badges       : Array[Role]
	var avatar_url   : String
	var user_color   : Color
	func _to_string() -> String: return display_name

class Message:
	var id      : String
	var text    : String
	var sent_at : int
	var reply_to_id           : String
	var reply_to_username     : String
	var reply_to_display_name : String
	func _to_string() -> String: return text

signal connected
signal connection_failed(error: String)
signal disconnected(error: String)

signal chat_message_received(user: User, message: Message, highlight_reward_name: String)
signal chat_sticker_received(user: User, message_id: String, name: String, url: String)
signal chat_message_pinned(user: User, message: Message, pinned_by: String)
signal chat_message_unpinned()
signal chat_message_deleted(message_id: String)
signal chat_cleared()

signal raid_incoming(from: User, _raider_count: int) # raider count currently unavailable
signal raid_outgoing_started(target: User, viewer_count: int, countdown: int)
signal raid_outgoing_cancelled()

signal reward_redeemed(user: User, message_id: String, reward_name: String, user_input: String)
signal user_shouted_out(target: User, game_name: String, game_cover_url: String, shouted_by: User)

@export var autoconnect := true
@export var channel := ""

func start() -> void:
	if channel.is_empty():
		printerr("Altstream: no channel provided")
		return
	if client.status == EventStreamClient.Status.DISCONNECTED:
		client.connect_to_host(HOST, ENDPOINT % channel)

func stop() -> void:
	client.close()


# Above this comment is the public API of this type.
# Below you can find the implementation details.
# You should not need to access this.

enum Type {
	MESSAGE,      ## Regular chat message.
	HIGHLIGHT,    ## Highlighted chat message.
	REDEMPTION,   ## Reward redemption.
	TIP,          ## Ko-Fi tip received.
	SHOP,         ## Ko-Fi shop purchase.
	SUBSCRIPTION, ## New Ko-Fi membership.
	PIN,          ## Message being pinned.
	UNPIN,        ## Currently active pin removed.
	SHOUTOUT,     ## Another user shouted out.
	RAID,         ## Incoming / outgoing raids.
	DELETE,       ## Chat message deleted.
	CLEAR,        ## Chat cleared.
	SYSTEM,       ## Some messages don't have a unique message type.
}

var client = EventStreamClient.new()

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
	for msg in JSON.parse_string(event_data):
		var message := _message_from_msg(msg)
		var user    := _user_from_msg(msg)
		var data: Dictionary[String, Variant]
		data.assign(msg.get("data", {}))

		match _type_lookup.get(msg.get("type")):
			Type.MESSAGE      : _handle_message(message, user, msg)
			Type.HIGHLIGHT    : _handle_highlight(message, user, data)
			Type.REDEMPTION   : _handle_redemption(message, user, data)
			Type.TIP          : pass
			Type.SHOP         : pass # TODO: Implement Ko-Fi events.
			Type.SUBSCRIPTION : pass
			Type.PIN          : _handle_pin(data)
			Type.UNPIN        : chat_message_unpinned.emit()
			Type.SHOUTOUT     : _handle_shoutout(user, data)
			Type.RAID         : _handle_raid(user, data)
			Type.DELETE       : _handle_delete(msg)
			Type.CLEAR        : chat_cleared.emit()

			Type.SYSTEM:
				if message.text.begins_with("[RAID_CANCEL]"):
					raid_outgoing_cancelled.emit()

func _handle_message(message: Message, user: User, raw_msg: Dictionary) -> void:
	var sticker_name := _try_get_string(raw_msg, "stickerName")
	var sticker_url  := _try_get_string(raw_msg, "stickerUrl")
	if message.text: chat_message_received.emit(user, message, "")
	if sticker_name: chat_sticker_received.emit(user, message.id, sticker_name, sticker_url)

# Highlighted messages show up mostly as regular chat messages, so we'll emit them as such.
func _handle_highlight(message: Message, user: User, data: Dictionary[String, Variant]) -> void:
	message.text     = _try_get_string(data, "text")
	var reward_name := _try_get_string(data, "rewardName")
	chat_message_received.emit(user, message, reward_name)

func _handle_redemption(message: Message, user: User, data: Dictionary[String, Variant]) -> void:
	var reward_name := _try_get_string(data, "rewardName")
	var user_input  := _try_get_string(data, "userInput") # optional
	reward_redeemed.emit(user, message.id, reward_name, user_input)

func _handle_pin(data: Dictionary[String, Variant]) -> void:
	var user      := _user_from_msg(data)
	var message   := _message_from_msg(data)
	var pinned_by := _try_get_string(data, "pinnedBy")
	chat_message_pinned.emit(user, message, pinned_by)

func _handle_shoutout(user: User, data: Dictionary[String, Variant]) -> void:
	var target := User.new()
	target.username     = _try_get_string(data, "targetUsername")
	target.display_name = _try_get_string(data, "targetDisplayName")
	target.avatar_url   = _try_get_string(data, "targetAvatar")
	var game_name      := _try_get_string(data, "gameName")
	var game_cover_url := _try_get_string(data, "gameCover")
	user_shouted_out.emit(target, game_name, game_cover_url, user)

func _handle_raid(user: User, data: Dictionary[String, Variant]) -> void:
	if data.has("targetUsername"):
		var target := User.new()
		target.username     = _try_get_string(data, "targetUsername")
		target.display_name = _try_get_string(data, "targetDisplayName")
		target.avatar_url   = _try_get_string(data, "targetImage")
		var viewers   := _try_get_int(data, "viewers")
		var countdown := _try_get_int(data, "countdownSeconds")
		raid_outgoing_started.emit(target, viewers, countdown)
	else:
		raid_incoming.emit(user, 0)

func _handle_delete(raw_msg: Dictionary) -> void:
	var target_id := _try_get_string(raw_msg, "targetId")
	chat_message_deleted.emit(target_id)


static var _type_lookup: Dictionary[String, Type]
static var _role_lookup: Dictionary[String, Role]
static func _static_init() -> void:
	for key: String in Type: _type_lookup[key.to_lower()] = Type[key]
	for key: String in Role: _role_lookup[key.to_lower()] = Role[key]

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
	user.pronouns     = _try_get_string(msg, "authorPronouns")
	user.avatar_url   = _try_get_string(msg, "authorImage")
	user.user_color   = _parse_color(_try_get_string(msg, "userColor"))

	for role: int in Role.values():
		user.roles[role] = false
	if msg.get("roles") is Dictionary:
		for role: String in msg.roles:
			if _role_lookup.has(role):
				user.roles[_role_lookup[role]] = (msg.roles[role] == true)

	if msg.get("badges") is Array:
		for badge: String in msg.badges:
			if _role_lookup.has(badge):
				user.badges.append(_role_lookup[badge])

	return user

static func _message_from_msg(msg: Dictionary) -> Message:
	var message := Message.new()
	message.id      = _try_get_string(msg, "id")
	message.text    = _try_get_string(msg, "text")
	message.sent_at = _try_get_int   (msg, "sentAt")
	message.reply_to_id           = _try_get_string(msg, "replyToId")
	message.reply_to_username     = _try_get_string(msg, "replyToUsername")
	message.reply_to_display_name = _try_get_string(msg, "replyToAuthor")
	return message
