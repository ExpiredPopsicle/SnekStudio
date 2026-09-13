class_name StickDriver extends Node3D

func set_animation(value: Vector3) -> void:
	# safeguard if model doesnt have animation tree
	$AnimationTree.set("parameters/y_axis/blend_amount", value.y)
	$AnimationTree.set("parameters/x_axis/add_amount", value.x)
	$AnimationTree.set("parameters/twist/add_amount", value.z)
