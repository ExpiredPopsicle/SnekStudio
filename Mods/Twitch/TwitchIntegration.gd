extends Mod_Base

func scene_init():

	super.scene_init()
	var app = get_app()

	$TwitchService.handle_channel_chat_message.connect(
		app._on_handle_channel_chat_message)
	$TwitchService.handle_channel_points_redeem.connect(
		app._on_handle_channel_points_redeem)
	$TwitchService.handle_channel_raid.connect(
		app._on_handle_channel_raid)

func scene_shutdown():

	super.scene_shutdown()
	var app = get_app()

	$TwitchService.handle_channel_chat_message.disconnect(
		app._on_handle_channel_chat_message)
	$TwitchService.handle_channel_points_redeem.disconnect(
		app._on_handle_channel_points_redeem)
	$TwitchService.handle_channel_raid.disconnect(
		app._on_handle_channel_raid)

func _ready() -> void:
	var twitch : TwitchService = TwitchService.new()
	twitch.name = "TwitchService"
	twitch.twitch_client_id = "mcelg5q6vbtp2phjxi3d5u4shb6uzh"
	twitch.config_root = get_app().get_config_location()
	add_child(twitch)
