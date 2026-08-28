extends SceneTree

## Test para Task 2: Contrato dinámico de DungeonArchetype y DungeonConfig sin enums rígidos.

func _init() -> void:
	print("--- Running test_dynamic_dungeon_archetype_contract (Task 2) ---")
	var archetype_script = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
	var config_script = preload("res://src/dungeon_generator/config/dungeon_config.gd")

	# 1. Test StringName resolution
	assert(archetype_script.resolve_id(&"necropolis") == &"necropolis", "StringName must resolve directly")
	assert(archetype_script.resolve_id("temple") == &"temple", "String must resolve to StringName")
	assert(archetype_script.resolve_id("NECROPOLIS") == &"necropolis", "Case insensitive resolution")
	assert(archetype_script.resolve_id(1) == &"necropolis", "Legacy int enum 1 must map to necropolis")
	assert(archetype_script.resolve_id(99) == &"generic", "Unmapped int enum must map gracefully to generic")
	print("  [OK] DungeonArchetype.resolve_id() works for strings, stringnames, and legacy integer enums.")

	# 2. Test DungeonConfig dynamic archetype assignment
	var cfg = config_script.new()
	assert(cfg.get_effective_archetype_id() == &"necropolis" or cfg.get_effective_archetype_id() == &"generic", "Config has default effective archetype")

	cfg.archetype_id = &"necropolis"
	assert(cfg.get_effective_archetype_id() == &"necropolis", "Config provides explicit archetype_id")

	cfg.archetype_id = &"custom_dungeon"
	assert(cfg.get_effective_archetype_id() == &"custom_dungeon", "Config allows any dynamic archetype StringName")
	print("  [OK] DungeonConfig.get_effective_archetype_id() accepts dynamic StringNames.")

	print("\n==================================================================")
	print("[PASS] test_dynamic_dungeon_archetype_contract passed 100%!")
	print("==================================================================\n")
	quit(0)
