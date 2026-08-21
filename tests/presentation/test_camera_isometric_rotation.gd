extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")
const PlayerTestScript = preload("res://src/character_test/player_test.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_camera_isometric_rotation ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "IsoTestWorld"
	get_root().add_child(root)

	var rig = IsometricCameraRigScript.new()
	root.add_child(rig)

	var player = PlayerTestScript.new()
	root.add_child(player)

	await process_frame

	var cam := rig.get_camera()
	var pivot: Node3D = rig.get_node("CameraPivot")

	# 1. Proyección Ortogonal
	assert(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "FAIL: Camera projection must be strictly PROJECTION_ORTHOGONAL")

	# 2. Invariante de orientación isométrica
	var initial_rot := pivot.rotation
	assert(is_equal_approx(rig.yaw_degrees, 45.0), "FAIL: Yaw must be 45 degrees")
	assert(is_equal_approx(rig.pitch_degrees, 35.264), "FAIL: Pitch must be ~35.264 degrees")
	assert(is_equal_approx(rig.roll_degrees, 0.0), "FAIL: Roll must be 0.0 degrees")

	rig.set_target(player)
	rig.teleport_to_target()

	# 3. Rotar jugador 180 grados
	player.rotation_degrees.y = 180.0
	rig.process_physics_step(0.016)

	assert(pivot.rotation.is_equal_approx(initial_rot), "FAIL: Player rotation must NOT affect CameraPivot rotation")
	assert(cam.global_rotation.is_equal_approx(pivot.global_rotation), "FAIL: Camera3D must retain strict isometric orientation")

	# 4. Desplazar jugador en diagonal y verificar que solo cambia la traslación, no la rotación
	player.global_position = Vector3(25.0, 0.0, -18.0)
	for _i in range(60):
		rig.process_physics_step(0.016)

	assert(pivot.rotation.is_equal_approx(initial_rot), "FAIL: Target translation must NOT affect CameraPivot rotation")

	root.free()

	print("[PASS] test_camera_isometric_rotation completed successfully.")
	quit(0)
