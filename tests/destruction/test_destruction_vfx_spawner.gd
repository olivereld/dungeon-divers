extends SceneTree

const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")
const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_vfx_spawner (Task 3) ---")
	print("==================================================================")
	var reg = _VFXRegistryScript.new()
	var spawner = _VFXSpawnerScript.new(reg)

	var parent = Node3D.new()
	var xform = Transform3D(Basis(), Vector3(12.0, 0.5, 24.0))

	var vfx_node = spawner.spawn_effect("small_dust", xform, parent)
	assert(vfx_node != null, "FAIL: small_dust node must be spawned")
	assert(vfx_node.position.is_equal_approx(Vector3(12.0, 0.5, 24.0)), "FAIL: position mismatch")
	assert(vfx_node.get_parent() == parent, "FAIL: parent mismatch")

	# Retorno limpio de null ante effect_id desconocido
	assert(spawner.spawn_effect("unknown_effect", xform, parent) == null, "FAIL: unknown fx must return null")

	parent.free()
	print("[PASS] test_destruction_vfx_spawner passed 100%!")
	print("==================================================================")
	quit(0)
