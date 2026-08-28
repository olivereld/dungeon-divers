extends SceneTree

const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_vfx_instance_generic (Task 2) ---")
	print("==================================================================")
	var root = Node3D.new()
	var vfx_ctrl = _VFXInstanceScript.new()
	vfx_ctrl.max_lifetime = 0.4
	vfx_ctrl.auto_cleanup = true
	vfx_ctrl.auto_play = false
	root.add_child(vfx_ctrl)

	# Añadir emisores arbitrarios hijos
	var p1 = CPUParticles3D.new()
	p1.one_shot = true
	p1.emitting = false
	vfx_ctrl.add_child(p1)

	var p2 = CPUParticles3D.new()
	p2.one_shot = true
	p2.emitting = false
	vfx_ctrl.add_child(p2)

	assert(p1.emitting == false, "FAIL: emitter should start inactive")
	vfx_ctrl.play()
	assert(p1.emitting == true, "FAIL: child emitter 1 must be emitting")
	assert(p2.emitting == true, "FAIL: child emitter 2 must be emitting")

	var finished_signal := {"fired": false}
	vfx_ctrl.finished.connect(func(): finished_signal["fired"] = true)

	vfx_ctrl.cleanup()
	assert(finished_signal["fired"] == true, "FAIL: finished signal must fire on cleanup")

	root.free()
	print("[PASS] test_destruction_vfx_instance_generic passed 100%!")
	print("==================================================================")
	quit(0)
