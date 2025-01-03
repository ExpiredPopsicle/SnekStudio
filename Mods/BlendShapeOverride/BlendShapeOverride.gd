extends Mod_Base

var blendshape_name : String

func _ready() -> void:
	add_tracked_setting("blendshape_name", "Blendshape Name", {}, "")

func _process(delta: float) -> void:
	var model : Node3D = get_model()
	var anim_player : AnimationPlayer = model.find_child("AnimationPlayer", false, false)

	if blendshape_name in anim_player.get_animation_list():
		anim_player.play(blendshape_name)
		anim_player.advance(0)
		anim_player.stop()
