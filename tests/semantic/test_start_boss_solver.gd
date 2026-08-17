class_name TestStartBossSolver
extends SceneTree

const _StartBossSolverScript = preload("res://src/dungeon_generator/core/semantic/start_boss_solver.gd")

func _init() -> void:
	print("--- Running test_start_boss_solver ---")

	var solver = _StartBossSolverScript.new()
	var grid := CellGrid.new(20, 20)

	var r0 := RoomData.new(0, Rect2i(2, 2, 4, 4), &"explore")
	var r1 := RoomData.new(1, Rect2i(8, 2, 4, 4), &"explore")
	var r2 := RoomData.new(2, Rect2i(14, 2, 4, 4), &"explore")

	for r in [r0, r1, r2]:
		for y in range(r.rect.position.y, r.rect.end.y):
			for x in range(r.rect.position.x, r.rect.end.x):
				grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var rooms: Array[RoomData] = [r0, r1, r2]
	var conns: Array[RoomConnection] = [
		RoomConnection.new(0, 0, 1, true),
		RoomConnection.new(1, 1, 2, true)
	]
	var depth_map: Dictionary = { 0: 0, 1: 1, 2: 2 }

	# Test 1: Selección por centro lexicográfico mínimo para Start y máxima profundidad para Boss
	var res1 := solver.resolve_start_and_boss(rooms, conns, grid, null, depth_map)
	assert(res1["start_room_id"] == 0, "Start room should be r0 (min lexicographical coord)")
	assert(res1["boss_room_id"] == 2, "Boss room should be r2 (max depth = 2)")
	print("  [OK] Test 1: Start/Boss default resolution by coord and max depth")

	# Test 2: Prioridad de room_type explícito (&"start", &"boss")
	r1.room_type = &"start"
	r0.room_type = &"boss"
	var res2 := solver.resolve_start_and_boss(rooms, conns, grid, null, depth_map)
	assert(res2["start_room_id"] == 1, "Start room should respect room_type == start")
	assert(res2["boss_room_id"] == 0, "Boss room should respect room_type == boss")
	print("  [OK] Test 2: Start/Boss resolution by room_type tags")

	# Test 3: Desempate determinista de Boss en caso de misma profundidad
	r0.room_type = &"explore"
	r1.room_type = &"explore"
	var r3 := RoomData.new(3, Rect2i(8, 8, 4, 4), &"explore")
	for y in range(r3.rect.position.y, r3.rect.end.y):
		for x in range(r3.rect.position.x, r3.rect.end.x):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)
	rooms.append(r3)
	depth_map[3] = 2 # r2 y r3 ambos tienen depth 2; r3 tiene mayor id

	var res3 := solver.resolve_start_and_boss(rooms, conns, grid, null, depth_map)
	assert(res3["boss_room_id"] == 3, "Boss room tiebreak should pick highest room_id (3 > 2)")
	print("  [OK] Test 3: Boss tiebreak determinism by higher room_id")

	print("[PASS] test_start_boss_solver succeeded with 100% assertions passing!")
	quit(0)
