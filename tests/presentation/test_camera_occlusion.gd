extends SceneTree

const CameraOcclusionDetectorScript = preload("res://src/presentation/camera/camera_occlusion_detector.gd")
const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_occlusion ---")
	print("==================================================================")

	var detector = CameraOcclusionDetectorScript.new()
	assert(detector != null, "FAIL: CameraOcclusionDetector should instantiate")
	assert(not detector.is_target_occluded(), "FAIL: Initial occlusion state should be false")

	# Mock de obstáculos
	var mock_wall := StaticBody3D.new()
	mock_wall.name = "WallObstacle"

	var started_fired := false
	var ended_fired := false
	var occluders_received: Array[Node3D] = []

	detector.occlusion_started.connect(func(occs: Array[Node3D]):
		started_fired = true
		occluders_received = occs
	)
	detector.occlusion_ended.connect(func(occs: Array[Node3D]):
		ended_fired = true
	)

	# 1. Simular detección de obstáculo
	detector._update_occlusion_state([mock_wall])
	assert(detector.is_target_occluded(), "FAIL: Target should be marked as occluded")
	assert(started_fired, "FAIL: occlusion_started should be emitted on transition")
	assert(occluders_received.has(mock_wall), "FAIL: occluders array should contain blocking obstacle")

	# 2. Misma lista no debe re-emitir la señal (evento de borde discreto)
	started_fired = false
	detector._update_occlusion_state([mock_wall])
	assert(not started_fired, "FAIL: occlusion_started must NOT emit redundantly without state change")

	# 3. Limpiar obstáculo
	detector._update_occlusion_state([])
	assert(not detector.is_target_occluded(), "FAIL: Target should not be occluded")
	assert(ended_fired, "FAIL: occlusion_ended should be emitted when obstacle is cleared")

	# 4. Probar integración con el Rig
	var rig = IsometricCameraRigScript.new()
	assert(rig.get_occlusion_detector() != null, "FAIL: IsometricCameraRig should have CameraOcclusionDetector")
	assert(not rig.is_target_occluded(), "FAIL: Rig should report is_target_occluded = false initially")

	var rig_started := false
	rig.occlusion_started.connect(func(occs: Array[Node3D]):
		rig_started = true
	)
	rig._on_occlusion_started([mock_wall])
	assert(rig_started, "FAIL: Rig should forward occlusion_started signal")

	mock_wall.free()
	detector.free()
	rig.free()

	print("[PASS] test_camera_occlusion completed successfully.")
	quit(0)
