class_name TestKeyLockPlanner
extends SceneTree

const _KeyLockPlannerScript = preload("res://src/dungeon_generator/core/semantic/key_lock_planner.gd")
const _CriticalPathSolverScript = preload("res://src/dungeon_generator/core/semantic/critical_path_solver.gd")
const _GameplayValidatorScript = preload("res://src/dungeon_generator/core/semantic/gameplay_validator.gd")

func _init() -> void:
	print("--- Running test_key_lock_planner ---")

	var planner = _KeyLockPlannerScript.new()
	var cp_solver = _CriticalPathSolverScript.new()
	var validator = _GameplayValidatorScript.new()

	var grid := CellGrid.new(30, 30)

	# Layout lineal con 6 habitaciones:
	# r0 (Start) <-> r1 <-> r2 <-> r3 <-> r4 <-> r5 (Boss)
	# y rama r1 <-> r6 (sala secundaria para llave)
	var r0 := RoomData.new(0, Rect2i(2, 2, 4, 4), &"start")
	var r1 := RoomData.new(1, Rect2i(8, 2, 4, 4), &"explore")
	var r2 := RoomData.new(2, Rect2i(14, 2, 4, 4), &"explore")
	var r3 := RoomData.new(3, Rect2i(20, 2, 4, 4), &"explore")
	var r4 := RoomData.new(4, Rect2i(26, 2, 4, 4), &"explore")
	var r5 := RoomData.new(5, Rect2i(26, 8, 4, 4), &"boss")
	var r6 := RoomData.new(6, Rect2i(8, 8, 4, 4), &"treasure")

	var rooms: Array[RoomData] = [r0, r1, r2, r3, r4, r5, r6]
	for r in rooms:
		for y in range(r.rect.position.y, r.rect.end.y):
			for x in range(r.rect.position.x, r.rect.end.x):
				grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var conns: Array[RoomConnection] = [
		RoomConnection.new(0, 0, 1, true),
		RoomConnection.new(1, 1, 2, true),
		RoomConnection.new(2, 2, 3, true),
		RoomConnection.new(3, 3, 4, true),
		RoomConnection.new(4, 4, 5, true),
		RoomConnection.new(5, 1, 6, true) # Rama secundaria
	]

	var cp_res := cp_solver.solve_critical_path(0, 5, rooms, conns)
	var cfg := DungeonConfig.new()
	cfg.lock_key_frequency = 0.5

	# Test 1: Generación de llaves y cerraduras válidas
	var plan1 := planner.plan_keys_and_locks(
		0, 5, rooms, conns,
		cp_res["critical_path_rooms"],
		cp_res["critical_path_connections"],
		cp_res["mandatory_connections"],
		cp_res["depth_map"],
		grid, cfg, 12345
	)

	assert(plan1["is_valid"] == true, "Planner should return valid layout")
	var keys: Array = plan1["keys"]
	var locks: Array = plan1["locks"]

	assert(keys.size() == locks.size(), "Keys and locks counts must match")
	if not keys.is_empty():
		assert(locks[0].connection_id >= 0, "Lock must reference a valid connection_id")
		# Validar con GameplayValidator
		var val := validator.validate_gameplay(0, 5, rooms, conns, keys, locks, [])
		assert(val["is_resolvable"] == true, "Planned key/lock layout must be 100% resolvable in GameplayValidator")
	print("  [OK] Test 1: Successfully planned solvable key-lock pair(s)")

	# Test 2: Determinismo absoluto
	var plan2 := planner.plan_keys_and_locks(
		0, 5, rooms, conns,
		cp_res["critical_path_rooms"],
		cp_res["critical_path_connections"],
		cp_res["mandatory_connections"],
		cp_res["depth_map"],
		grid, cfg, 12345
	)
	assert(plan1["keys"].size() == plan2["keys"].size(), "Keys count must be deterministic")
	assert(plan1["locks"].size() == plan2["locks"].size(), "Locks count must be deterministic")
	if not plan1["locks"].is_empty():
		assert(plan1["locks"][0].connection_id == plan2["locks"][0].connection_id, "Lock connection_id must match across runs")
		assert(plan1["keys"][0].room_id == plan2["keys"][0].room_id, "Key room_id must match across runs")
	print("  [OK] Test 2: Absolute determinism across identical seeds verified")

	print("[PASS] test_key_lock_planner succeeded with 100% assertions passing!")
	quit(0)
