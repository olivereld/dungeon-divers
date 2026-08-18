extends SceneTree

## Suite de pruebas unitarias para PR-10E: MultiFloorGenerator & StairPlanner.

func _init() -> void:
	print("--- Running test_multifloor_generation (PR-10E) ---")

	var multi_gen_script = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
	var stair_planner_script = preload("res://src/dungeon_generator/core/stair_planner.gd")
	var cell_grid_script = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

	var config := DungeonConfig.new()
	config.grid_width = 32
	config.grid_height = 32
	config.total_floors = 3
	config.mission_depth = 4
	config.seed = 133742
	config.use_fixed_seed = true

	var generator := multi_gen_script.new()
	var result: DungeonMultiFloorResult = generator.generate_multi_floor(config)

	# 1. Validar Invariantes Globales del Resultado Multi-Piso
	assert(result != null, "MultiFloorResult must not be null")
	assert(result.is_valid, "Multi-floor generation must be valid")
	assert(result.get_floor_count() == 3, "Must generate exactly 3 floors")
	assert(result.vertical_connections.size() == 2, "Must generate 2 vertical connections for 3 floors (F0-F1, F1-F2)")
	print("  [OK] Multi-floor 3-level dungeon generated successfully")

	# 2. Validar Invariantes de los Pisos Individuales
	for f_num in [0, 1, 2]:
		var f_data: DungeonFloorData = result.get_floor(f_num)
		assert(f_data != null, "Floor %d data must exist" % f_num)
		assert(f_data.grid != null, "Floor %d grid must exist" % f_num)
		assert(f_data.has_stairs(), "Floor %d must have stair endpoints" % f_num)
		assert(not f_data.rooms.is_empty(), "Floor %d must contain rooms" % f_num)

	# 3. Validar Conexiones y Tipos de Celda
	var f0: DungeonFloorData = result.get_floor(0)
	var f1: DungeonFloorData = result.get_floor(1)
	var f2: DungeonFloorData = result.get_floor(2)

	assert(f0.stairs.size() == 1, "Floor 0 must have 1 stair (Ascending to F1)")
	assert(f1.stairs.size() == 2, "Floor 1 must have 2 stairs (Descending to F0, Ascending to F2)")
	assert(f2.stairs.size() == 1, "Floor 2 must have 1 stair (Descending to F1)")

	# Comprobar que en CellGrid se marcaron los tipos correctos
	var stair_f0: StairData = f0.stairs[0]
	assert(not stair_f0.is_downward, "Stair on F0 must be upward")
	assert(f0.grid.get_cell(stair_f0.cell) == cell_grid_script.CellType.STAIRS_UP, "Cell on F0 must be STAIRS_UP")

	var stair_f2: StairData = f2.stairs[0]
	assert(stair_f2.is_downward, "Stair on F2 must be downward")
	assert(f2.grid.get_cell(stair_f2.cell) == cell_grid_script.CellType.STAIRS_DOWN, "Cell on F2 must be STAIRS_DOWN")
	print("  [OK] Stair counts, directions, and CellGrid types verified across all 3 floors")

	# 4. Validar Determinismo Bit a Bit
	var result2: DungeonMultiFloorResult = generator.generate_multi_floor(config)
	assert(result.get_floor_count() == result2.get_floor_count(), "Floor counts must match")
	for f_num in range(3):
		var st1 = result.get_floor(f_num).stairs[0]
		var st2 = result2.get_floor(f_num).stairs[0]
		assert(st1.cell == st2.cell and st1.stair_id == st2.stair_id, "Stair data on floor %d must be bit-identical" % f_num)
	print("  [OK] Multi-floor generator determinism verified")

	print("\n>>> ALL PR-10E MULTIFLOOR GENERATION TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
