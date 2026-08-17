class_name TestRoomConnectivityRepair
extends SceneTree

## Suite de pruebas para RoomConnectivityRepair y CellGridJournal (Fase 6.1.1).

const _CellGridJournalScript = preload("res://src/dungeon_generator/core/repair/cell_grid_journal.gd")
const _RoomConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/room_connectivity_repair.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")

func _init() -> void:
	print("\n--- Running test_room_connectivity_repair ---")

	test_journal_preserves_initial_state()
	test_journal_rollback()
	test_main_region_priority_1_center()
	test_main_region_priority_2_size()
	test_main_region_priority_3_lexicographical()
	test_room_repair_success_and_contiguity()
	test_room_repair_rollback_on_failure()

	print("--- All test_room_connectivity_repair tests passed successfully! ---\n")
	quit(0)

func test_journal_preserves_initial_state() -> void:
	var grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	var pos := Vector2i(3, 3)
	grid.set_cell(pos, CellGrid.CellType.WALL)

	var journal = _CellGridJournalScript.new()
	journal.record_cell(grid, pos)

	# Modificar la celda dos veces
	grid.set_cell(pos, CellGrid.CellType.FLOOR)
	journal.record_cell(grid, pos) # No debe sobreescribir el estado inicial (WALL)

	grid.set_cell(pos, CellGrid.CellType.CORRIDOR)
	journal.record_cell(grid, pos)

	assert(grid.get_cell(pos) == CellGrid.CellType.CORRIDOR, "Grid must reflect latest change before rollback")

	journal.rollback(grid)
	assert(grid.get_cell(pos) == CellGrid.CellType.WALL, "Rollback must restore INITIAL state (WALL)")
	print("  [OK] Test 1: CellGridJournal preserves initial state across multiple modifications")

func test_journal_rollback() -> void:
	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	for y in range(5, 15):
		for x in range(5, 15):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.WALL)

	# Copia snapshot de referencia
	var grid_before: Array = []
	for y in range(20):
		for x in range(20):
			grid_before.append(grid.get_cell(Vector2i(x, y)))

	var journal = _CellGridJournalScript.new()
	for y in range(6, 14):
		for x in range(6, 14):
			var p := Vector2i(x, y)
			journal.record_cell(grid, p)
			grid.set_cell(p, CellGrid.CellType.FLOOR)

	journal.rollback(grid)

	var grid_after: Array = []
	for y in range(20):
		for x in range(20):
			grid_after.append(grid.get_cell(Vector2i(x, y)))

	assert(grid_before == grid_after, "Grid after rollback must be 100% bit-for-bit identical to grid before")
	print("  [OK] Test 2: CellGridJournal rollback restores 100% identical state")

func test_main_region_priority_1_center() -> void:
	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(2, 2, 10, 10))
	var center := room.get_center() # (7, 7)

	# Región A contiene center: tamaño 4
	var reg_a: Array[Vector2i] = [center, center + Vector2i(1, 0), center + Vector2i(0, 1), center + Vector2i(1, 1)]
	for p in reg_a:
		grid.set_cell(p, CellGrid.CellType.FLOOR)

	# Región B no contiene center: tamaño 12 (más grande)
	var reg_b: Array[Vector2i] = []
	for dy in range(3):
		for dx in range(4):
			var p := Vector2i(2 + dx, 2 + dy)
			reg_b.append(p)
			grid.set_cell(p, CellGrid.CellType.FLOOR)

	var regions: Array = [reg_b, reg_a]
	var selected_idx: int = _RoomConnectivityRepairScript._select_main_region_index(grid, room, regions)

	# Prioridad 1: Debe seleccionar reg_a porque contiene el centro
	assert(selected_idx == 1, "Must select region containing room.center (Priority 1)")
	print("  [OK] Test 3: Priority 1 (Center) correctly selects region containing room.center")

func test_main_region_priority_2_size() -> void:
	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(2, 2, 10, 10))
	# Centro es WALL
	grid.set_cell(room.get_center(), CellGrid.CellType.WALL)

	# Región A: tamaño 3
	var reg_a: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
	# Región B: tamaño 8
	var reg_b: Array[Vector2i] = [
		Vector2i(2, 8), Vector2i(3, 8), Vector2i(4, 8), Vector2i(5, 8),
		Vector2i(2, 9), Vector2i(3, 9), Vector2i(4, 9), Vector2i(5, 9)
	]

	var regions: Array = [reg_a, reg_b]
	var selected_idx: int = _RoomConnectivityRepairScript._select_main_region_index(grid, room, regions)

	# Prioridad 2: Debe seleccionar reg_b por mayor tamaño
	assert(selected_idx == 1, "Must select largest region when center is WALL (Priority 2)")
	print("  [OK] Test 4: Priority 2 (Size) correctly selects largest region")

func test_main_region_priority_3_lexicographical() -> void:
	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(2, 2, 10, 10))
	grid.set_cell(room.get_center(), CellGrid.CellType.WALL)

	# Dos regiones de igual tamaño (4 celdas cada una)
	var reg_a: Array[Vector2i] = [Vector2i(2, 5), Vector2i(3, 5), Vector2i(2, 6), Vector2i(3, 6)] # min_y = 5, min_x = 2
	var reg_b: Array[Vector2i] = [Vector2i(2, 8), Vector2i(3, 8), Vector2i(2, 9), Vector2i(3, 9)] # min_y = 8, min_x = 2

	var regions: Array = [reg_b, reg_a]
	var selected_idx: int = _RoomConnectivityRepairScript._select_main_region_index(grid, room, regions)

	# Prioridad 3: reg_a tiene menor y lexicográfico (5 < 8) -> índice 1 en regions
	assert(selected_idx == 1, "Must select region with smallest (y, x) lexicographical coordinate on tie (Priority 3)")
	print("  [OK] Test 5: Priority 3 (Lexicographical tiebreak) correctly resolves ties")

func test_room_repair_success_and_contiguity() -> void:
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(5, 5, 15, 15))

	# Crear dos islas separadas por un muro interno de 2 celdas
	# Región 1 (Centro)
	for y in range(9, 13):
		for x in range(9, 13):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	# Región 2 (Esquina noroeste de la sala)
	for y in range(5, 7):
		for x in range(5, 7):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	# Región 3 (Esquina sureste de la sala)
	for y in range(16, 19):
		for x in range(16, 19):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var val_before = _StructuralValidatorScript.validate_room_internal_connectivity(grid, room)
	assert(not val_before["is_valid"], "Room before repair must be invalid (3 disconnected regions)")
	assert(val_before["region_count"] == 3, "Room before repair must have 3 regions")

	var repair_res = _RoomConnectivityRepairScript.repair_room_internal_connectivity(grid, room, val_before, 999)
	assert(repair_res.success, "Repair must succeed")

	var val_after = _StructuralValidatorScript.validate_room_internal_connectivity(grid, room)
	assert(val_after["is_valid"], "Room after repair must be valid (1 contiguous region)")
	assert(val_after["region_count"] == 1, "Room after repair must have exactly 1 region")
	print("  [OK] Test 6: RoomConnectivityRepair connects 3 isolated islands into exactly 1 contiguous region")

func test_room_repair_rollback_on_failure() -> void:
	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room := RoomData.new(1, Rect2i(2, 2, 8, 8))

	# Isla 1
	grid.set_cell(Vector2i(2, 2), CellGrid.CellType.FLOOR)
	# Isla 2
	grid.set_cell(Vector2i(8, 8), CellGrid.CellType.FLOOR)

	# Bloquear todas las celdas intermedias con OBSTACLE para forzar imposibilidad de camino A*
	for y in range(2, 9):
		for x in range(2, 9):
			var p := Vector2i(x, y)
			if p != Vector2i(2, 2) and p != Vector2i(8, 8):
				grid.set_cell(p, CellGrid.CellType.OBSTACLE)

	var grid_before: Array = []
	for y in range(20):
		for x in range(20):
			grid_before.append(grid.get_cell(Vector2i(x, y)))

	var val_before = _StructuralValidatorScript.validate_room_internal_connectivity(grid, room)
	var repair_res = _RoomConnectivityRepairScript.repair_room_internal_connectivity(grid, room, val_before, 123)

	assert(not repair_res.success, "Repair must report failure when no valid path can be formed")

	var grid_after: Array = []
	for y in range(20):
		for x in range(20):
			grid_after.append(grid.get_cell(Vector2i(x, y)))

	assert(grid_before == grid_after, "Grid must be 100% restored after failed repair")
	print("  [OK] Test 7: RoomConnectivityRepair executes 100% rollback when repair cannot be completed")
