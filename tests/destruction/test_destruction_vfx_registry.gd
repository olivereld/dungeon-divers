extends SceneTree

const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_vfx_registry (Task 1) ---")
	print("==================================================================")
	var reg = _VFXRegistryScript.new()
	assert(reg.has_effect("small_dust"), "FAIL: small_dust must be defined in vfx.json")
	assert(reg.get_scene_path("small_dust") == "res://scenes/vfx/destruction/vfx_small_dust.tscn", "FAIL: scene path mismatch")
	assert(reg.has_effect("stone_break"), "FAIL: stone_break must be defined")
	assert(reg.has_effect("wood_break"), "FAIL: wood_break must be defined")
	assert(reg.has_effect("bone_collapse"), "FAIL: bone_collapse must be defined")
	assert(reg.has_effect("heavy_dust"), "FAIL: heavy_dust must be defined")

	print("[PASS] test_destruction_vfx_registry passed 100%!")
	print("==================================================================")
	quit(0)
