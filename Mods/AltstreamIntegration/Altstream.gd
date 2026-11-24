class_name Altstream

enum Type {
	MESSAGE,        ## Regular chat message.
	REPLY,          ## Reply to another chat message.
	HIGHLIGHT,      ## Highlighted chat message.
	REDEMPTION,     ## Reward redemption.

	PIN,            ## Message being pinned.
	UNPIN,          ## Currently active pin removed.
	DELETE,         ## Chat message deleted.
	CLEAR,          ## Chat cleared.

	TIP,            ## Ko-Fi tip received.
	SHOP,           ## Ko-Fi shop purchase.
	SUBSCRIPTION,   ## New Ko-Fi membership.

	FOLLOW,         ## User followed channel. (requires permission)
	SHOUTOUT,       ## Another user shouted out.

	RAID_RECEIVED,  ## Incoming raid.
	RAID_STARTED,   ## Outgoing raid started.
	RAID_CANCELLED, ## Outgoing raid cancelled.

	SYSTEM,         ## Currently not handled.
}

enum Role {
	BROADCASTER,
	MODERATOR,
	ALTSTREAM_SUBSCRIBER,
	CHANNEL_SUBSCRIBER,
	FOLLOWER,
	BOT,
}

class User:
	var channel_name : String ## Unique channel ID (all-lowercase).
	var display_name : String ## Custom display name.
	var pronouns     : String ## For example "She/Her", may be empty.
	var roles        : Dictionary[Role, bool]
	var badges       : Array[Role] # TODO: Add non-role badges.
	var avatar_url   : String
	var color        : Color
	func _to_string() -> String: return display_name

class Message:
	var id      : String
	var sent_at : int
	var author  : User   # may be null
	var text    : String # may be empty
	func _to_string() -> String: return text
