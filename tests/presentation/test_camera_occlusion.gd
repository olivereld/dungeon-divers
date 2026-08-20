extends SceneTree

const CameraOcclusionDetectorScript = preload("res://src/presentation/camera/camera_occlusion_detector.gd")
const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

var _started_fired: bool = false
var _ended_fired: bool = false
var _occluders_received: Array[Node3D] = []

var _rig_started: bool = false
var _rig_ended: bool = false

func _on_detector_occlusion_started(occs: Array[Node3D]) -> void:
	print("DEBUG: _on_detector_occlusion_started received: ", occs)
	_started_fired = true
	_occluders_received = occs

func _on_detector_occlusion_ended(occs: Array[Node3D]) -> void:
	print("DEBUG: _on_detector_occlusion_ended received: ", occs)
	_ended_fired = true

func _on_rig_occlusion_started(occs: Array[Node3D]) -> void:
	print("DEBUG: _on_rig_occlusion_started received: ", occs)
	_rig_started = true

func _on_rig_occlusion_ended(occs: Array[Node3D]) -> void:
	print("DEBUG: _on_rig_occlusion_ended received: ", occs)
	_rig_ended = true

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_occlusion ---")
	print("==================================================================")

	var root := Node3D.new()
	get_root().add_child(root)

	var detector = CameraOcclusionDetectorScript.new()
	root.add_child(detector)
	assert(detector != null, "FAIL: CameraOcclusionDetector should instantiate")
	assert(not detector.is_target_occluded(), "FAIL: Initial occlusion state should be false")

	detector.occlusion_started.connect(_on_detector_occlusion_started)
	detector.occlusion_ended.connect(_on_detector_occlusion_ended)

	# Mock de obstáculo
	var mock_wall := StaticBody3D.new()
	mock_wall.name = "WallObstacle"
	root.add_child(mock_wall)

	# 1. Simular detección de obstáculo (false -> true)
	print("DEBUG: triggering occlusion transition false -> true")
	detector._update_occlusion_state([mock_wall])
	assert(detector.is_target_occluded(), "FAIL: Target should be marked as occluded")
	assert(_started_fired, "FAIL: occlusion_started should be emitted on transition")
	assert(_occluders_received.has(mock_wall), "FAIL: occluders array should contain blocking obstacle")

	# 2. Misma lista no debe re-emitir la señal (evento de borde discreto)
	_started_fired = false
	print("DEBUG: triggering redundant occlusion state (true -> true)")
	detector._update_occlusion_state([mock_wall])
	assert(not _started_fired, "FAIL: occlusion_started must NOT emit redundantly without state change")

	# 3. Limpiar obstáculo (true -> false)
	_ended_fired = false
	print("DEBUG: clearing occlusion state (true -> false)")
	detector._update_occlusion_state([])
	assert(not detector.is_target_occluded(), "FAIL: Target should not be occluded")
	assert(_ended_fired, "FAIL: occlusion_ended should be emitted when obstacle is cleared")

	# 4. Probar integración con el Rig
	var rig = IsometricCameraRigScript.new()
	root.add_child(rig)
	assert(rig.get_occlusion_detector() != null, "FAIL: IsometricCameraRig should have CameraOcclusionDetector")
	assert(not rig.is_target_occluded(), "FAIL: Rig should report is_target_occluded = false initially")

	rig.occlusion_started.connect(_on_rig_occlusion_started)
	rig.occlusion_ended.connect(_on_rig_occlusion_ended)

	rig._on_occlusion_started([mock_wall])
	assert(_rig_started, "FAIL: Rig should forward occlusion_started signal")

	root.free()

	print("[PASS] test_camera_occlusion completed successfully.")
	quit(0)
