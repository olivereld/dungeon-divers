extends SceneTree

## Test unitario para Task 1: Data Model & Config Foundation (Fase Reforced).
## Valida el enum DoorType, la propiedad door_type en DoorPlacement y la configuración de políticas de puertas en DungeonConfig.

func _init() -> void:
	print("--- Running test_door_data_and_config ---")

	# 1. Validar script y enum DoorType
	var DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
	assert(DoorTypeScript != null, "DoorType script must exist")
	assert(DoorTypeScript.DoorType.CLOSED_DOOR == 0, "CLOSED_DOOR enum must be 0")
	assert(DoorTypeScript.DoorType.LOCKED_DOOR == 1, "LOCKED_DOOR enum must be 1")
	assert(DoorTypeScript.DoorType.OPEN_PASSAGE == 2, "OPEN_PASSAGE enum must be 2")
	print("  [OK] DoorType enum verified")

	# 2. Validar propiedades de política en DungeonConfig
	var cfg := DungeonConfig.new()
	assert("door_open_passage_chance" in cfg, "Config must have door_open_passage_chance")
	assert("door_single_door_chance" in cfg, "Config must have door_single_door_chance")
	assert("door_double_door_chance" in cfg, "Config must have door_double_door_chance")
	assert("min_corridor_length_for_double_doors" in cfg, "Config must have min_corridor_length_for_double_doors")
	assert("short_corridor_single_door_threshold" in cfg, "Config must have short_corridor_single_door_threshold")
	assert(is_equal_approx(cfg.door_open_passage_chance, 0.25), "Default door_open_passage_chance must be 0.25")
	assert(is_equal_approx(cfg.door_single_door_chance, 0.65), "Default door_single_door_chance must be 0.65")
	assert(is_equal_approx(cfg.door_double_door_chance, 0.10), "Default door_double_door_chance must be 0.10")
	assert(cfg.min_corridor_length_for_double_doors == 6, "Default min_corridor_length_for_double_doors must be 6")
	assert(cfg.short_corridor_single_door_threshold == 3, "Default short_corridor_single_door_threshold must be 3")
	print("  [OK] DungeonConfig DoorPlacementPolicy exports verified")

	# 3. Validar DoorPlacement con soporte de DoorType
	var DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
	var dp = DoorPlacementScript.new(1, 0, Vector2i(5, 5), 0, Vector2i(5, 4), Vector2i(5, 6))
	assert("door_type" in dp, "DoorPlacement must have door_type property")
	assert(dp.door_type == DoorTypeScript.DoorType.CLOSED_DOOR, "Default door_type must be CLOSED_DOOR")
	assert(dp.is_open_passage() == false, "Default is_open_passage must return false")

	dp.door_type = DoorTypeScript.DoorType.OPEN_PASSAGE
	assert(dp.is_open_passage() == true, "is_open_passage must return true when door_type is OPEN_PASSAGE")
	print("  [OK] DoorPlacement door_type and is_open_passage() verified")

	print("[PASS] test_door_data_and_config completed successfully!")
	quit(0)
