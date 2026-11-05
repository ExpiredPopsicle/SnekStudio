class_name Altstream

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

enum Role {
	BROADCASTER, ## The streamer.
	MODERATOR,   ## Channel moderator.
	SUBSCRIBER,  ## Platform supporter.
	SUPPORTER,   ## Channel supporter.
	# NOTE: Yes this is confusing. Hopefully it'll get fixed.
}

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
