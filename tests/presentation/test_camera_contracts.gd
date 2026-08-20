extends SceneTree

const IsometricCameraRigScript = preload("res://src/presentation/camera/isometric_camera_rig.gd")

var _signal_emitted: bool = false
var _emitted_target: Node3D = null
var _signal_count: int = 0

func _on_target_changed(t: Node3D) -> void:
	print("DEBUG: CALLBACK ENTERED: ", t)
	_signal_emitted = true
	_emitted_target = t
	_signal_count += 1

func _init() -> void:
	print("==================================================================")
	print("--- Running test_camera_contracts ---")
	print("==================================================================")

	var rig = IsometricCameraRigScript.new()
	assert(rig != null, "FAIL: IsometricCameraRig should instantiate")

	# 1. Configuración isométrica inicial
	assert(rig.yaw_degrees == 45.0, "FAIL: Default yaw should be 45 degrees")
	assert(is_equal_approx(rig.pitch_degrees, 35.264), "FAIL: Default pitch should be ~35.264 degrees (true isometric)")
	assert(rig.roll_degrees == 0.0, "FAIL: Default roll should be 0.0 degrees")

	# 2. Conectar señal a método explícito
	rig.target_changed.connect(_on_target_changed)

	var dummy_target := Node3D.new()
	dummy_target.name = "DummyTarget"

	print("DEBUG: Before set_target -> rig.target: ", rig.target)
	print("DEBUG: Dummy target instance: ", dummy_target)

	# 3. Primer set_target (null -> dummy_target)
	rig.set_target(dummy_target)

	print("DEBUG: After set_target -> rig.target: ", rig.target)
	print("DEBUG: Signal emitted: ", _signal_emitted)
	print("DEBUG: Emitted target: ", _emitted_target)
	print("DEBUG: Signal count: ", _signal_count)

	assert(rig.target == dummy_target, "FAIL: set_target should assign target")
	assert(_signal_emitted, "FAIL: set_target should emit target_changed signal")
	assert(_emitted_target == dummy_target, "FAIL: target_changed should pass target node")
	assert(_signal_count == 1, "FAIL: signal_count should be exactly 1 after first transition")

	# 4. Asignación redundante (dummy_target -> dummy_target, no debe emitir de nuevo)
	_signal_emitted = false
	rig.set_target(dummy_target)
	assert(not _signal_emitted, "FAIL: Redundant set_target should NOT re-emit signal")
	assert(_signal_count == 1, "FAIL: signal_count should remain 1")

	# 5. Clear target (dummy_target -> null)
	_signal_emitted = false
	rig.clear_target()
	print("DEBUG: After clear_target -> rig.target: ", rig.target)
	print("DEBUG: Signal emitted after clear: ", _signal_emitted)
	print("DEBUG: Emitted target after clear: ", _emitted_target)
	print("DEBUG: Signal count after clear: ", _signal_count)

	assert(rig.target == null, "FAIL: clear_target should set target to null")
	assert(_signal_emitted, "FAIL: clear_target should emit target_changed signal with null")
	assert(_emitted_target == null, "FAIL: clear_target emitted target should be null")
	assert(_signal_count == 2, "FAIL: signal_count should be 2 after clear")

	dummy_target.free()
	rig.free()

	print("[PASS] test_camera_contracts completed successfully.")
	quit(0)
