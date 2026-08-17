class_name TestGameplayValidator
extends SceneTree

const _GameplayValidatorScript = preload("res://src/dungeon_generator/core/semantic/gameplay_validator.gd")
const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")
const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")

func _init() -> void:
	print("--- Running test_gameplay_validator ---")

	var validator = _GameplayValidatorScript.new()

	var r0 := RoomData.new(0, Rect2i(0, 0, 4, 4), &"start")
	var r1 := RoomData.new(1, Rect2i(5, 0, 4, 4), &"explore")
	var r2 := RoomData.new(2, Rect2i(10, 0, 4, 4), &"boss")
	var r3 := RoomData.new(3, Rect2i(0, 5, 4, 4), &"treasure")

	var rooms: Array[RoomData] = [r0, r1, r2, r3]
	var conns: Array[RoomConnection] = [
		RoomConnection.new(0, 0, 1, true),
		RoomConnection.new(1, 1, 2, true),
		RoomConnection.new(2, 0, 3, true)
	]

	# Test 1: Camino resoluble normal con llave en r1 y cerradura en conexión (1-2)
	var keys1: Array = [_KeyDataScript.new(100, &"iron_key", 1, Vector2i(6, 1))] # Arbitrary non-zero ID
	var locks1: Array = [_LockDataScript.new(1, 1, 1, 2, 100)] # Conn 1 (1 <-> 2) locked with key 100
	var objs1: Array = [
		_ObjectiveDataScript.new(1, _ObjectiveDataScript.ObjectiveType.SPAWN, 0, Vector2i(1, 1), true),
		_ObjectiveDataScript.new(2, _ObjectiveDataScript.ObjectiveType.BOSS, 2, Vector2i(11, 1), true)
	]

	var res1: Dictionary = validator.validate_gameplay(0, 2, rooms, conns, keys1, locks1, objs1)
	assert(res1["is_resolvable"] == true, "Dungeon should be resolvable when key is accessible before lock")
	assert(res1["solution_trace"].size() >= 2, "Solution trace should contain traversal steps to boss")
	print("  [OK] Test 1: Solvable dungeon with key accessible before lock")

	# Test 2: Deadlock / Soft-lock (La llave está detrás de la propia cerradura)
	# Lock en Conn 0 (0 <-> 1) requiere llave 100, pero la llave 100 está en r1
	var locks2: Array = [_LockDataScript.new(1, 0, 0, 1, 100)]
	var res2: Dictionary = validator.validate_gameplay(0, 2, rooms, conns, keys1, locks2, objs1)
	assert(res2["is_resolvable"] == false, "Deadlock must be detected when key is behind its own lock")
	assert(res2["unreachable_rooms"].has(2), "Boss room 2 must be unreachable")
	print("  [OK] Test 2: Deadlock detected when key is located behind its own lock")

	# Test 3: Distinción entre Objetivos Obligatorios vs Opcionales
	# Bloqueamos Conn 2 (0 <-> 3) con una llave inexistente (999)
	var locks3: Array = [
		_LockDataScript.new(1, 1, 1, 2, 100), # Conn 1 -> OK con llave en r1
		_LockDataScript.new(2, 2, 0, 3, 999)  # Conn 2 (0 <-> 3) -> Inalcanzable
	]

	# Caso 3A: Objetivo opcional (TESORO) en r3 -> dungeon sigue siendo RESOLUBLE
	var objs3_opt: Array = [
		_ObjectiveDataScript.new(1, _ObjectiveDataScript.ObjectiveType.SPAWN, 0, Vector2i(1, 1), true),
		_ObjectiveDataScript.new(2, _ObjectiveDataScript.ObjectiveType.BOSS, 2, Vector2i(11, 1), true),
		_ObjectiveDataScript.new(3, _ObjectiveDataScript.ObjectiveType.TREASURE, 3, Vector2i(1, 6), false) # Optional!
	]
	var res3_opt: Dictionary = validator.validate_gameplay(0, 2, rooms, conns, keys1, locks3, objs3_opt)
	assert(res3_opt["is_resolvable"] == true, "Dungeon must remain resolvable if unreachable objective is optional")
	assert(res3_opt["unreachable_optional_objectives"].size() == 1, "Optional treasure should be flagged in diagnostics")
	print("  [OK] Test 3A: Unreachable optional objective does not invalidate dungeon")

	# Caso 3B: Objetivo obligatorio (MAIN QUEST) en r3 -> dungeon queda INVÁLIDA
	var objs3_mand: Array = [
		_ObjectiveDataScript.new(1, _ObjectiveDataScript.ObjectiveType.SPAWN, 0, Vector2i(1, 1), true),
		_ObjectiveDataScript.new(2, _ObjectiveDataScript.ObjectiveType.BOSS, 2, Vector2i(11, 1), true),
		_ObjectiveDataScript.new(3, _ObjectiveDataScript.ObjectiveType.QUEST_ITEM, 3, Vector2i(1, 6), true) # Mandatory!
	]
	var res3_mand: Dictionary = validator.validate_gameplay(0, 2, rooms, conns, keys1, locks3, objs3_mand)
	assert(res3_mand["is_resolvable"] == false, "Dungeon must be INVALID if mandatory objective is unreachable")
	assert(res3_mand["unreachable_mandatory_objectives"].size() == 1, "Mandatory quest item flagged as unreachable")
	print("  [OK] Test 3B: Unreachable mandatory objective properly invalidates dungeon")

	print("[PASS] test_gameplay_validator succeeded with 100% assertions passing!")
	quit(0)
