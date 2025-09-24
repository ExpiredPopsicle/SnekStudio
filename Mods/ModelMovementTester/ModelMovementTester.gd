extends Mod_Base
class_name Mod_ModelMovementTester

var test_movement := false

var t := 0.0

var movement_speed := 1.0

func _ready() -> void:
	add_tracked_setting(
		"test_movement",
		"Test Movement")
	add_tracked_setting(
		"movement_speed", "Movement Speed",
		{ "min" : 0.1, "max" : 2.0 })

func scene_shutdown() -> void:
	var controller := get_model_controller()

	# Throws errors when closing app
	controller.global_transform.origin = Vector3.ZERO
	controller.global_transform.basis = Basis.IDENTITY

func _process(delta: float) -> void:
	if test_movement:
		test_model_movement(delta * movement_speed)

## Use this to test 6 axes of model movement.
func test_model_movement(delta: float) -> void:
	var controller := get_model_controller()

	t += delta
	controller.global_transform.origin = Vector3(sin(t),
												cos(t),
												sin(t))
	controller.global_transform.basis = Basis.IDENTITY.rotated(
											Vector3(sin(t),
													cos(t),
													sin(t)).normalized(),
											PI/4.0)
