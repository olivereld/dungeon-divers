extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_camera_zoom ---")
	print("==================================================================")

	var root := Node3D.new()
	root.name = "CameraTestWorld"
	get_root().add_child(root)

	var rig = IsometricCameraRigScript.new()
	rig.zoom_min = 8.0
	rig.zoom_max = 48.0
	rig.zoom_step = 2.0
	rig.default_zoom = 20.0
	rig.zoom_smoothing = 15.0
	root.add_child(rig)

	var cam := rig.get_camera()
	assert(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "FAIL: Camera must be ORTHOGONAL")

	# 1. Estado inicial
	rig.set_zoom(20.0)
	assert(is_equal_approx(rig.get_zoom(), 20.0), "FAIL: Initial target zoom should be 20.0")
	assert(is_equal_approx(cam.size, 20.0), "FAIL: Initial camera size should be 20.0")

	# 2. Zoom In
	rig.zoom_in(4.0)
	assert(is_equal_approx(rig.target_zoom, 16.0), "FAIL: target_zoom should be 16.0 after zoom_in(4)")

	# 3. Clamping mínimo
	rig.zoom_in(100.0)
	assert(is_equal_approx(rig.target_zoom, 8.0), "FAIL: target_zoom should clamp to zoom_min (8.0)")

	# 4. Clamping máximo
	rig.zoom_out(100.0)
	assert(is_equal_approx(rig.target_zoom, 48.0), "FAIL: target_zoom should clamp to zoom_max (48.0)")

	# 5. Interpolación suave hacia 48.0
	rig.process_zoom_step(0.05)
	assert(cam.size > 20.0 and cam.size < 48.0, "FAIL: Camera size should smoothly interpolate toward 48.0")

	for _i in range(120):
		rig.process_zoom_step(0.05)
	assert(is_equal_approx(cam.size, 48.0), "FAIL: Camera size should converge to 48.0")

	# 6. Interpolación suave de regreso hacia 24.0
	rig.set_zoom(24.0)
	rig.process_zoom_step(0.05)
	assert(cam.size > 24.0 and cam.size < 48.0, "FAIL: Camera size should smoothly interpolate toward 24.0")

	for _i in range(120):
		rig.process_zoom_step(0.05)
	assert(is_equal_approx(cam.size, 24.0), "FAIL: Camera size should converge to 24.0")

	root.free()

	print("[PASS] test_camera_zoom completed successfully.")
	quit(0)
