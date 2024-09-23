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
