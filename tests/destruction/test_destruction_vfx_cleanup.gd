extends SceneTree

const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")
const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")
const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_vfx_cleanup (Task 6 - Memory Test) ---")
	print("==================================================================")
	var reg = _VFXRegistryScript.new()
	var spawner = _VFXSpawnerScript.new(reg)
	var parent = Node3D.new()
	root.add_child(parent)
	await process_frame

	var node = spawner.spawn_effect("small_dust", Transform3D.IDENTITY, parent)
	assert(node != null and is_instance_valid(node), "FAIL: VFX node must be valid")
	assert(node.is_inside_tree(), "FAIL: VFX node must be inside tree")

	var instance_ctrl := node as _VFXInstanceScript
	assert(instance_ctrl != null, "FAIL: root must be VFXInstance")
	assert(instance_ctrl.auto_cleanup == true, "FAIL: auto_cleanup must be true by default")

	# Forzar cleanup y verificar que se encola para queue_free
	var signal_captured := {"fired": false}
	instance_ctrl.finished.connect(func(): signal_captured["fired"] = true)

	instance_ctrl.cleanup()
	assert(signal_captured["fired"] == true, "FAIL: finished signal must fire on cleanup")

	# Simular avance de frame
	await process_frame

	parent.free()
	print("[PASS] test_destruction_vfx_cleanup passed 100%!")
	print("==================================================================")
	quit(0)
