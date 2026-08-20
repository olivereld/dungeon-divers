extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_zoom ---")
	print("==================================================================")

	var rig = IsometricCameraRigScript.new()
	rig.zoom_min = 8.0
	rig.zoom_max = 48.0
	rig.zoom_step = 2.0
	rig.default_zoom = 20.0
	rig.zoom_smoothing = 15.0

	var cam = rig.get_camera()
	assert(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "FAIL: Camera must be ORTHOGONAL")

	# 1. Inicializar zoom
	rig.set_zoom(20.0)
	assert(is_equal_approx(rig.get_zoom(), 20.0), "FAIL: Initial zoom should match 20.0")

	# 2. Zoom In y Clamping
	rig.zoom_in(4.0)
	assert(is_equal_approx(rig.target_zoom, 16.0), "FAIL: target_zoom should be 16.0 after zoom_in(4)")

	rig.zoom_in(100.0)
	assert(is_equal_approx(rig.target_zoom, 8.0), "FAIL: target_zoom should clamp to zoom_min (8.0)")

	# 3. Zoom Out y Clamping
	rig.zoom_out(100.0)
	assert(is_equal_approx(rig.target_zoom, 48.0), "FAIL: target_zoom should clamp to zoom_max (48.0)")

	# 4. Interpolación suave de zoom en process
	rig.set_zoom(24.0)
	rig.process_zoom_step(0.1)
	assert(cam.size < 48.0 and cam.size > 24.0, "FAIL: Camera size should smoothly interpolate towards target_zoom")

	for _i in range(60):
		rig.process_zoom_step(0.05)
	assert(is_equal_approx(cam.size, 24.0), "FAIL: Camera size should converge to target_zoom")

	rig.free()
	print("[PASS] test_camera_zoom completed successfully.")
	quit(0)
