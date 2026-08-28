extends SceneTree

const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionModeScript = preload("res://src/destruction/core/destruction_mode.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_destruction_registry_loading ---")
	print("==================================================================")

	var reg := _DestructionRegistryScript.new()
	assert(reg.has_definition(&"crypt_urn_banded_floor"), "FAIL: registry must have crypt_urn_banded_floor")
	assert(reg.has_definition(&"skull_pile"), "FAIL: registry must have skull_pile")
	assert(reg.has_definition(&"candle_cluster"), "FAIL: registry must have candle_cluster")
	assert(reg.has_definition(&"fortress_chest_corner"), "FAIL: registry must have fortress_chest_corner")

	var urn_def = reg.get_definition(&"crypt_urn_banded_floor")
	assert(urn_def.durability == 20.0, "FAIL: urn durability")
	assert(urn_def.destruction_mode == _DestructionModeScript.Mode.BREAK, "FAIL: urn mode")
	assert(urn_def.replacement_asset == &"crypt_rubble_corner", "FAIL: urn replacement")

	var skull_def = reg.get_definition(&"skull_pile")
	assert(skull_def.destruction_mode == _DestructionModeScript.Mode.COLLAPSE, "FAIL: skull mode")
	assert(skull_def.durability == 15.0, "FAIL: skull durability")

	var candle_def = reg.get_definition(&"candle_cluster")
	assert(candle_def.destruction_mode == _DestructionModeScript.Mode.EXTINGUISH, "FAIL: candle mode")
	assert(candle_def.durability == 5.0, "FAIL: candle durability")

	print("  [OK] Registry loaded %d definitions successfully." % reg.size())
	print("[PASS] test_destruction_registry_loading passed with 100% success!")
	print("==================================================================")
	quit(0)
