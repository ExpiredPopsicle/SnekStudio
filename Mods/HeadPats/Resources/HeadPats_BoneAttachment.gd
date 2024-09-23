extends BoneAttachment3D

@export var lifetime : float = 5.0

func _physics_process(delta):
	lifetime -= delta
	if lifetime < 0.0:
		queue_free()
