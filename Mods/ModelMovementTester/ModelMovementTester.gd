extends Mod_Base
class_name Mod_ModelMovementTester

var test_movement := false

var t: float = 0.0

func _ready() -> void:
	add_tracked_setting(
		"test_movement",
		"Test Movement")

func scene_shutdown() -> void:
	var controller := get_model_controller()

	controller.model_transform.origin = Vector3.ZERO
	controller.model_transform.basis = Basis.IDENTITY

func _process(delta: float) -> void:
	if test_movement:
		test_model_movement(delta)

## Use this to test 6 axes of model movement.
func test_model_movement(delta: float) -> void:
	var controller := get_model_controller()

	t += delta
	controller.model_transform.origin = Vector3(sin(t),
												cos(t),
												sin(t))
	controller.model_transform.basis = Basis.IDENTITY.rotated(
											Vector3(sin(t),
													cos(t),
													sin(t)).normalized(),
											PI/4.0)
