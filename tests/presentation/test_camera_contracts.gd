extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_contracts ---")
	print("==================================================================")

	var rig = IsometricCameraRigScript.new()
	assert(rig != null, "FAIL: IsometricCameraRig should instantiate")

	# Verificar configuración isométrica inicial
	assert(rig.yaw_degrees == 45.0, "FAIL: Default yaw should be 45 degrees")
	assert(is_equal_approx(rig.pitch_degrees, 35.264), "FAIL: Default pitch should be ~35.264 degrees (true isometric)")
	assert(rig.roll_degrees == 0.0, "FAIL: Default roll should be 0.0 degrees")

	# Verificar API de Target
	var dummy_target := Node3D.new()
	var signal_emitted := false
	var emitted_target: Node3D = null
	rig.target_changed.connect(func(t: Node3D):
		signal_emitted = true
		emitted_target = t
	)

	rig.set_target(dummy_target)
	assert(rig.target == dummy_target, "FAIL: set_target should assign target")
	assert(signal_emitted, "FAIL: set_target should emit target_changed signal")
	assert(emitted_target == dummy_target, "FAIL: target_changed should pass target node")

	signal_emitted = false
	rig.clear_target()
	assert(rig.target == null, "FAIL: clear_target should set target to null")
	assert(signal_emitted, "FAIL: clear_target should emit target_changed signal with null")

	dummy_target.free()
	rig.free()

	print("[PASS] test_camera_contracts completed successfully.")
	quit(0)
