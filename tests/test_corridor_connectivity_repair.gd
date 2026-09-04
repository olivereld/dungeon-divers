class_name TestCorridorConnectivityRepair
extends SceneTree

## Suite de pruebas para CorridorConnectivityRepair (Fase 6.1.1).

const _CellGridJournalScript = preload("res://src/dungeon_generator/core/repair/cell_grid_journal.gd")
const _CorridorConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/corridor_connectivity_repair.gd")
const _CorridorCarveResultScript = preload("res://src/dungeon_generator/core/data/corridor_carve_result.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _CorridorPlanScript = preload("res://src/dungeon_generator/core/data/corridor_plan.gd")
const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")

func _init() -> void:
	print("\n--- Running test_corridor_connectivity_repair ---")

	test_corridor_repair_already_valid()
	test_corridor_repair_success()
	test_corridor_repair_rollback_on_impossible()

	print("--- All test_corridor_connectivity_repair tests passed successfully! ---\n")
	quit(0)

func test_corridor_repair_already_valid() -> void:
	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var initial_res = _CorridorCarveResultScript.new()
	initial_res.is_valid = true

	var repair_res = _CorridorConnectivityRepairScript.repair_missing_corridors(
		grid, [], [], [], initial_res, 123
	)

	assert(repair_res.success, "Must return success for already valid result")
	print("  [OK] Test 1: Already valid corridor result returns immediately with success")

func test_corridor_repair_success() -> void:
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room_a := RoomData.new(0, Rect2i(2, 2, 6, 6))
	var room_b := RoomData.new(1, Rect2i(20, 2, 6, 6))
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	# Entradas: room_a EAST (pos=(8,5), inner=(7,5), outer=(9,5))
	var ent_a = _RoomEntranceScript.new(0, 0, Vector2i(8, 5), _RoomEntranceScript.EAST, Vector2i(7, 5), Vector2i(9, 5))
	# Entradas: room_b WEST (pos=(19,5), inner=(20,5), outer=(18,5))
	var ent_b = _RoomEntranceScript.new(1, 0, Vector2i(19, 5), _RoomEntranceScript.WEST, Vector2i(20, 5), Vector2i(18, 5))
	var pair = _EntrancePairScript.new(0, ent_a, ent_b)
	var conn = _RoomConnectionScript.new(0, 0, 1, true)

	var initial_res = _CorridorCarveResultScript.new()
	initial_res.add_failure(0, "SIMULATED_FAILURE")

	var plan = _CorridorPlanScript.new()
	var req = _CorridorRequestScript.new(0, 0, 1)
	req.bind_physical_entrances(pair)
	plan.add_request(req)
	plan.seal()

	var repair_res = _CorridorConnectivityRepairScript.repair_missing_corridors(
		grid, [room_a, room_b], [pair], [conn], initial_res, 456, null, plan
	)

	assert(repair_res.success, "Corridor repair must succeed")
	assert(repair_res.corridor_res.is_valid, "Repaired result must be valid")
	assert(repair_res.corridor_res.paths.size() == 1, "Repaired result must contain 1 carved path")

	# Verificar que el camino es transitable entre 8,5 y 19,5
	for x in range(8, 20):
		assert(grid.is_walkable(Vector2i(x, 5)), "Carved corridor cell (x=%d, y=5) must be walkable" % x)

	print("  [OK] Test 2: CorridorConnectivityRepair successfully carves and connects missing corridor")

func test_corridor_repair_rollback_on_impossible() -> void:
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room_a := RoomData.new(0, Rect2i(2, 2, 6, 6))
	var room_b := RoomData.new(1, Rect2i(20, 2, 6, 6))
	grid.fill_rect(room_a.rect, CellGrid.CellType.FLOOR)
	grid.fill_rect(room_b.rect, CellGrid.CellType.FLOOR)

	# Bloquear el paso con una barrera vertical de VOID que corte toda la rejilla
	for y in range(30):
		grid.set_cell(Vector2i(14, y), CellGrid.CellType.VOID)

	var grid_before: Array = []
	for y in range(30):
		for x in range(30):
			grid_before.append(grid.get_cell(Vector2i(x, y)))

	var ent_a = _RoomEntranceScript.new(0, 0, Vector2i(8, 5), _RoomEntranceScript.EAST, Vector2i(7, 5), Vector2i(9, 5))
	var ent_b = _RoomEntranceScript.new(1, 0, Vector2i(19, 5), _RoomEntranceScript.WEST, Vector2i(20, 5), Vector2i(18, 5))
	var pair = _EntrancePairScript.new(0, ent_a, ent_b)
	var conn = _RoomConnectionScript.new(0, 0, 1, true)

	var initial_res = _CorridorCarveResultScript.new()
	initial_res.add_failure(0, "BLOCKED")

	var plan = _CorridorPlanScript.new()
	var req = _CorridorRequestScript.new(0, 0, 1)
	req.bind_physical_entrances(pair)
	plan.add_request(req)
	plan.seal()

	var repair_res = _CorridorConnectivityRepairScript.repair_missing_corridors(
		grid, [room_a, room_b], [pair], [conn], initial_res, 789, null, plan
	)

	assert(not repair_res.success, "Corridor repair must fail when path is physically impossible")

	var grid_after: Array = []
	for y in range(30):
		for x in range(30):
			grid_after.append(grid.get_cell(Vector2i(x, y)))

	assert(grid_before == grid_after, "Grid must be 100% bit-for-bit identical after corridor rollback")
	print("  [OK] Test 3: CorridorConnectivityRepair executes 100% rollback when corridor carving is impossible")
