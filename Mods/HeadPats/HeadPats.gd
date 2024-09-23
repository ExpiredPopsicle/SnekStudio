extends Mod_Base

@export var headpats_scene : PackedScene
@export var redeem_name : String = "Give me headpats"
@export var countdown : float = 5.0

func handle_channel_point_redeem(_redeemer_username, _redeemer_display_name, redeem_title, _user_input):
	if redeem_title == redeem_name:
		var skel = get_skeleton()
		if skel:
			var new_node = headpats_scene.instantiate()
			new_node.lifetime = countdown
			skel.add_child(new_node)
			add_autodelete_object(new_node)

func _ready():
	add_tracked_setting("redeem_name", "Redeem name", {"is_redeem" : true})
	add_tracked_setting(
		"countdown", "Seconds active",
		{"min" : 0.0,
		 "max" : 3600.0})
