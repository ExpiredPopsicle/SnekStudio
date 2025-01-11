extends BasicSubWindow

func _ready() -> void:
	register_serializable_subwindow()
	super._ready()

func _on_button_fake_chat_message_pressed():
	_get_app_root()._on_handle_channel_chat_message(
		%TextEditFakeUsername.text,
		%TextEditFakeDisplayname.text,
		%TextEditFakeChatMessage.text,
		int(%TextEditChatBitsCount.text))
		
func _on_button_fake_redeem_pressed():
	_get_app_root()._on_handle_channel_points_redeem(
		%TextEditFakeUsername.text,
		%TextEditFakeDisplayname.text,
		%TextEditFakeRedeemName.text,
		%TextEditFakeChatMessage.text)

func _on_button_fake_raid_pressed():
	_get_app_root()._on_handle_channel_raid(
		%TextEditFakeUsername.text,
		%TextEditFakeDisplayname.text,
		int(%TextEditRaidUserCount.text))
	
