extends SceneTree

const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")
const _DungeonResultScript = preload("res://src/dungeon_generator/core/data/dungeon_result.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_phase2_contracts ---")

	# Test 1: Grid Vacío
	var grid_empty := CellGrid.new(10, 10, CellGrid.CellType.VOID)
	assert(grid_empty.get_width() == 10 and grid_empty.get_height() == 10, "Dimensions must be 10x10")
	var void_cells := grid_empty.find_cells_of_type(CellGrid.CellType.VOID)
	assert(void_cells.size() == 100, "Empty grid must have exactly 100 VOID cells")
	print("  [OK] Test 1: Empty grid contains 100 VOID cells")

	# Test 2: Bounds
	assert(grid_empty.is_in_bounds(Vector2i(0, 0)), "(0,0) must be in bounds")
	assert(grid_empty.is_in_bounds(Vector2i(9, 9)), "(9,9) must be in bounds")
	assert(not grid_empty.is_in_bounds(Vector2i(-1, 0)), "(-1,0) must be out of bounds")
	assert(not grid_empty.is_in_bounds(Vector2i(10, 0)), "(10,0) must be out of bounds")
	assert(not grid_empty.is_in_bounds(Vector2i(0, 10)), "(0,10) must be out of bounds")
	assert(grid_empty.get_cell(Vector2i(-5, -5)) == CellGrid.CellType.VOID, "Out of bounds get_cell must return VOID")
	print("  [OK] Test 2: Bounds centralized and safe")

	# Test 3: Lectura y Escritura
	grid_empty.set_cell(Vector2i(5, 5), CellGrid.CellType.FLOOR)
	assert(grid_empty.get_cell(Vector2i(5, 5)) == CellGrid.CellType.FLOOR, "Cell (5,5) must be FLOOR")
	assert(grid_empty.is_walkable(Vector2i(5, 5)), "FLOOR must be walkable")
	assert(not grid_empty.is_solid(Vector2i(5, 5)), "FLOOR must not be solid")
	grid_empty.set_cell(Vector2i(5, 6), CellGrid.CellType.COLUMN)
	assert(grid_empty.get_cell(Vector2i(5, 6)) == CellGrid.CellType.COLUMN, "Cell (5,6) must be COLUMN")
	assert(grid_empty.is_solid(Vector2i(5, 6)), "COLUMN must be solid")
	assert(not grid_empty.is_walkable(Vector2i(5, 6)), "COLUMN must not be walkable")
	print("  [OK] Test 3: Read/Write with CellType values verified")

	# Test 4: Aislamiento
	assert(grid_empty.get_cell(Vector2i(4, 5)) == CellGrid.CellType.VOID, "Neighbor (4,5) must remain untouched")
	assert(grid_empty.get_cell(Vector2i(6, 5)) == CellGrid.CellType.VOID, "Neighbor (6,5) must remain untouched")
	assert(grid_empty.get_cell(Vector2i(5, 4)) == CellGrid.CellType.VOID, "Neighbor (5,4) must remain untouched")
	print("  [OK] Test 4: Cell mutation isolation verified")

	# Test 5: RoomData
	var room := RoomData.new(1, Rect2i(2, 3, 6, 8), &"combat")
	assert(room.id == 1, "Room ID must be 1")
	assert(room.rect == Rect2i(2, 3, 6, 8), "Room rect must match")
	assert(room.get_center() == Vector2i(5, 7), "Room center must be (5,7)")
	assert(room.get_area() == 48, "Room area must be 48")
	assert(room.contains_point(Vector2i(3, 4)), "Room contains point (3,4)")
	assert(not room.contains_point(Vector2i(1, 1)), "Room does not contain point (1,1)")
	print("  [OK] Test 5: RoomData contracts verified")

	# Test 6: RoomConnection y StructuralValidator
	var conn = _RoomConnectionScript.new(0, 1, 2, true)
	assert(conn.connects_room(1), "Connection connects room 1")
	assert(conn.connects_room(2), "Connection connects room 2")
	assert(conn.get_other_room_id(1) == 2, "Other room for 1 is 2")
	assert(conn.get_other_room_id(2) == 1, "Other room for 2 is 1")
	assert(conn.get_other_room_id(99) == -1, "Other room for invalid ID is -1")

	var validator = _StructuralValidatorScript.new()
	var test_rooms: Array[RoomData] = [
		RoomData.new(1, Rect2i(1, 1, 4, 4), &"start"),
		RoomData.new(2, Rect2i(5, 5, 4, 4), &"goal")
	]
	var test_conns = [conn]
	var report = validator.call("validate_structure", grid_empty, test_rooms, test_conns)
	assert(report.is_valid, "StructuralValidator must report valid structure: %s" % str(report.errors))

	# Test 6.1: Validación de error en self-connection
	var bad_conn = _RoomConnectionScript.new(1, 1, 1)
	var bad_report = validator.call("validate_structure", grid_empty, test_rooms, [bad_conn])
	assert(not bad_report.is_valid, "Self-connection must be caught as error")
	print("  [OK] Test 6: RoomConnection and StructuralValidator verified")

	# Test 7: Snapshot Textual y Determinismo
	var pipeline = _DungeonPipelineScript.new()
	var cfg1 := DungeonConfig.new()
	cfg1.seed = 424242
	cfg1.use_fixed_seed = true

	var cfg2 := DungeonConfig.new()
	cfg2.seed = 424242
	cfg2.use_fixed_seed = true

	var res1 = pipeline.call("generate", cfg1, 5, true)
	var res2 = pipeline.call("generate", cfg2, 5, true)
	assert(res1 != null and res2 != null, "Generations must succeed")

	var snap1: String = res1.call("to_debug_string")
	var snap2: String = res2.call("to_debug_string")
	assert(snap1 == snap2, "ASCII debug snapshots must be 100%% identical for same seed")
	assert(res1.connections.size() > 0, "DungeonResult must have populated RoomConnections")
	print("  [OK] Test 7: Textual debug snapshot determinism verified")

	# Test 8: Generación Pura sin Render
	assert(res1.grid is CellGrid, "Result must contain pure CellGrid")
	assert(res1.rooms.size() >= 4, "Result must contain RoomData list")
	print("  [OK] Test 8: 100%% headless generation without visual/render nodes verified")

	print("[PASS] test_phase2_contracts succeeded completely.")
	quit(0)
