extends SceneTree

## Suite de pruebas unitarias para PR-10B: Contenedores Multi-Piso (DungeonFloorData & DungeonMultiFloorResult).

func _init() -> void:
	print("--- Running test_multi_floor_data (PR-10B) ---")

	var stair_data_script = preload("res://src/dungeon_generator/core/data/stair_data.gd")
	var floor_connection_script = preload("res://src/dungeon_generator/core/data/floor_connection.gd")
	var floor_data_script = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")
	var multi_floor_result_script = preload("res://src/dungeon_generator/core/data/dungeon_multi_floor_result.gd")
	var cell_grid_script = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

	# 1. Validar Creación e Invariantes de DungeonFloorData
	var grid_f0 = cell_grid_script.new(20, 20)
	var floor_0 = floor_data_script.new(0, grid_f0)
	assert(floor_0.floor_number == 0, "Floor number must be 0")
	assert(not floor_0.has_stairs(), "Initially floor must not have stairs")

	var stair_0 = stair_data_script.new("stair_f0_up", 0, Vector2i(8, 8), 0.0, "vconn_0_1", false)
	floor_0.add_stair(stair_0)
	assert(floor_0.has_stairs(), "Floor must have stairs after addition")
	assert(floor_0.get_stair_at(Vector2i(8, 8)) == stair_0, "get_stair_at must return correct stair")
	assert(floor_0.get_stair_at(Vector2i(0, 0)) == null, "get_stair_at must return null for empty cell")
	print("  [OK] DungeonFloorData properties and stair management verified")

	# 2. Validar Creación e Invariantes de DungeonMultiFloorResult
	var grid_f1 = cell_grid_script.new(20, 20)
	var floor_1 = floor_data_script.new(1, grid_f1)
	var stair_1 = stair_data_script.new("stair_f1_down", 1, Vector2i(8, 8), 0.0, "vconn_0_1", true)
	floor_1.add_stair(stair_1)

	var vconn = floor_connection_script.new(
		"vconn_0_1",
		0, 1,
		stair_0.stair_id, stair_1.stair_id,
		stair_0.cell, stair_1.cell
	)

	var multi_result = multi_floor_result_script.new(1337)
	multi_result.add_floor(floor_0)
	multi_result.add_floor(floor_1)
	multi_result.add_vertical_connection(vconn)

	assert(multi_result.get_floor_count() == 2, "Must contain exactly 2 floors")
	assert(multi_result.get_floor(0) == floor_0, "Floor 0 must match")
	assert(multi_result.get_floor(1) == floor_1, "Floor 1 must match")
	assert(multi_result.get_floor(2) == null, "Non-existing floor must return null")

	var floor_nums: Array[int] = multi_result.get_floor_numbers()
	assert(floor_nums.size() == 2 and floor_nums[0] == 0 and floor_nums[1] == 1, "Floor numbers must be [0, 1]")

	# 3. Validar Consultas Cruzadas
	var f0_conns: Array = multi_result.get_vertical_connections_for_floor(0)
	assert(f0_conns.size() == 1 and f0_conns[0] == vconn, "Floor 0 must have exactly 1 vertical connection")

	var found_stair: StairData = multi_result.get_stair_data("stair_f1_down")
	assert(found_stair == stair_1, "get_stair_data must locate stair across all floors")
	print("  [OK] DungeonMultiFloorResult cross-floor queries and hierarchy verified")

	# 4. Validar Conversión from_dungeon_result
	var d_res := DungeonResult.new()
	d_res.floor_number = 3
	d_res.grid = grid_f0
	d_res.seed_used = 42

	var converted_floor: DungeonFloorData = floor_data_script.from_dungeon_result(d_res, [stair_0])
	assert(converted_floor.floor_number == 3, "Converted floor number must match")
	assert(converted_floor.seed_used == 42, "Converted seed must match")
	assert(converted_floor.stairs.size() == 1, "Converted stairs must match")
	print("  [OK] DungeonFloorData.from_dungeon_result conversion verified")

	print("\n>>> ALL PR-10B MULTI-FLOOR DATA TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
