class_name TestCriticalPathSolver
extends SceneTree

const _CriticalPathSolverScript = preload("res://src/dungeon_generator/core/semantic/critical_path_solver.gd")

func _init() -> void:
	print("--- Running test_critical_path_solver ---")

	var solver = _CriticalPathSolverScript.new()

	var r0 := RoomData.new(0, Rect2i(2, 2, 4, 4), &"start")
	var r1 := RoomData.new(1, Rect2i(8, 2, 4, 4), &"explore")
	var r2 := RoomData.new(2, Rect2i(14, 2, 4, 4), &"explore")
	var r3 := RoomData.new(3, Rect2i(8, 8, 4, 4), &"explore")
	var r4 := RoomData.new(4, Rect2i(20, 2, 4, 4), &"boss")

	var rooms: Array[RoomData] = [r0, r1, r2, r3, r4]

	# Grafo:
	# r0 -> r1 -> r2 -> r4
	# r0 -> r3 -> r2
	#
	# Conexiones:
	# Conn 0: (0, 1)
	# Conn 1: (1, 2)
	# Conn 2: (0, 3)
	# Conn 3: (3, 2)
	# Conn 4: (2, 4) -> BRIDGE / MANDATORY
	var conns: Array[RoomConnection] = [
		RoomConnection.new(0, 0, 1, true),
		RoomConnection.new(1, 1, 2, true),
		RoomConnection.new(2, 0, 3, true),
		RoomConnection.new(3, 3, 2, true),
		RoomConnection.new(4, 2, 4, true)
	]

	var res: Dictionary = solver.solve_critical_path(0, 4, rooms, conns)
	var cp_rooms: Array[int] = res["critical_path_rooms"]
	var cp_conns: Array[int] = res["critical_path_connections"]
	var mandatory: Array[int] = res["mandatory_connections"]
	var depth_map: Dictionary = res["depth_map"]

	# Test 1: Depth Map
	assert(depth_map[0] == 0, "r0 depth must be 0")
	assert(depth_map[1] == 1, "r1 depth must be 1")
	assert(depth_map[3] == 1, "r3 depth must be 1")
	assert(depth_map[2] == 2, "r2 depth must be 2")
	assert(depth_map[4] == 3, "r4 depth must be 3")
	print("  [OK] Test 1: Depth map correctly computed for all rooms")

	# Test 2: Critical Path Rooms & Connections
	assert(cp_rooms.size() == 4, "Critical path should have 4 rooms (0 -> 1 -> 2 -> 4)")
	assert(cp_rooms[0] == 0 and cp_rooms[3] == 4, "Critical path should start at 0 and end at 4")
	assert(cp_conns.size() == 3, "Critical path should have 3 connections")
	print("  [OK] Test 2: Canonical shortest critical path correctly identified: %s" % str(cp_rooms))

	# Test 3: Distinción estricta de mandatory_connections (Bridges)
	# Conn 0, 1, 2, 3 tienen ruta alternativa mediante el ciclo (0-1-2 y 0-3-2).
	# Conn 4 (2-4) es la ÚNICA arista puente cuya remoción desconecta Start(0) de Boss(4).
	assert(mandatory.size() == 1, "There should be exactly 1 mandatory bridge connection")
	assert(mandatory[0] == 4, "Mandatory connection must be Conn 4 (2 <-> 4)")
	assert(not mandatory.has(0), "Conn 0 must NOT be mandatory because alternative path exists via r3")
	assert(not mandatory.has(1), "Conn 1 must NOT be mandatory because alternative path exists via r3")
	print("  [OK] Test 3: Mandatory bridge connections correctly distinguished from critical_path_connections")

	print("[PASS] test_critical_path_solver succeeded with 100% assertions passing!")
	quit(0)
