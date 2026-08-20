extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_camera_smooth_follow ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "CameraTestWorld"
	get_root().add_child(root)

	var rig = IsometricCameraRigScript.new()
	rig.follow_speed = 10.0
	rig.acceleration = 20.0
	rig.deceleration = 30.0
	rig.dead_zone = 0.05
	rig.target_offset = Vector3(0.0, 1.0, 0.0)
	root.add_child(rig)

	var target := Node3D.new()
	target.name = "Target"
	root.add_child(target)
	target.position = Vector3.ZERO

	# Esperar a que el frame procese y el árbol y World3D estén completamente listos
	await process_frame

	assert(rig.is_inside_tree(), "FAIL: Camera rig must be inside SceneTree")
	assert(target.is_inside_tree(), "FAIL: Target must be inside SceneTree")
	assert(rig.get_world_3d() != null, "FAIL: Camera rig must have a World3D")

	rig.set_target(target)

	# 1. Teleport inicial dentro del árbol ya inicializado
	rig.teleport_to_target()
	assert(rig.global_position.is_equal_approx(Vector3(0.0, 1.0, 0.0)), "FAIL: teleport_to_target should immediately align to target + offset")

	# 2. Desplazar target 10 metros en X
	target.global_position = Vector3(10.0, 0.0, 0.0)

	# Simular un paso de físicas (0.016s)
	rig.process_physics_step(0.016)
	assert(rig.global_position.x > 0.0, "FAIL: Camera rig should accelerate towards target")
	assert(rig.global_position.x < 10.0, "FAIL: Camera rig should not snap instantly to target")

	# Simular 2 segundos de seguimiento continuo
	for _i in range(120):
		rig.process_physics_step(0.016)

	assert(rig.global_position.distance_to(Vector3(10.0, 1.0, 0.0)) < 0.05, "FAIL: Camera rig should converge within epsilon of target (10, 1, 0)")
	assert(is_equal_approx(rig.global_position.y, 1.0), "FAIL: Camera rig should maintain target_offset Y")

	root.free()

	print("[PASS] test_camera_smooth_follow completed successfully.")
	quit(0)
