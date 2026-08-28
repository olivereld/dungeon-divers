extends SceneTree

const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")
const _VFXSpawnerScript = preload("res://src/destruction/response/effects/destruction_vfx_spawner.gd")
const _VFXInstanceScript = preload("res://src/vfx/vfx_instance.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_vfx_library_completeness (Task 5) ---")
	print("==================================================================")
	var reg = _VFXRegistryScript.new()
	var spawner = _VFXSpawnerScript.new(reg)
	var parent = Node3D.new()

	var required = ["small_dust", "stone_break", "wood_break", "bone_collapse", "heavy_dust"]
	for fx_id in required:
		var node = spawner.spawn_effect(fx_id, Transform3D.IDENTITY, parent)
		assert(node != null, "FAIL: effect failed to spawn: %s" % fx_id)
		assert(node.name.begins_with("VFX_"), "FAIL: node prefix mismatch for %s" % fx_id)
		assert(node is _VFXInstanceScript, "FAIL: node must be an instance of VFXInstance")
		print("   [OK] Efecto validado: %s -> %s" % [fx_id, node.name])

	parent.free()
	print("[PASS] test_destruction_vfx_library_completeness passed 100%!")
	print("==================================================================")
	quit(0)
