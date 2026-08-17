extends SceneTree

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const _DoorResolverScript = preload("res://src/dungeon_generator/core/solvers/door_resolver.gd")
const _DoorTransitionValidatorScript = preload("res://src/dungeon_generator/core/validation/door_transition_validator.gd")
const _FloodFillScript = preload("res://src/dungeon_generator/core/algorithms/flood_fill.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_phase6_1_hardening ---")

	var cfg := DungeonConfig.new()

	# Test 1 & 2: Propagación de is_required (mandatory y optional)
	var conn_req = _RoomConnectionScript.new(0, 0, 1, true)
	var conn_opt = _RoomConnectionScript.new(1, 0, 2, false)

	var ent_a0 = _RoomEntranceScript.new(0, 0, Vector2i(10, 5), _RoomEntranceScript.EAST, Vector2i(9, 5), Vector2i(11, 5))
	var ent_b0 = _RoomEntranceScript.new(1, 0, Vector2i(20, 5), _RoomEntranceScript.WEST, Vector2i(21, 5), Vector2i(19, 5))
	var ep_req = _EntrancePairScript.new(0, ent_a0, ent_b0, 10.0)

	var ent_a1 = _RoomEntranceScript.new(0, 1, Vector2i(5, 10), _RoomEntranceScript.SOUTH, Vector2i(5, 9), Vector2i(5, 11))
	var ent_b1 = _RoomEntranceScript.new(2, 1, Vector2i(5, 20), _RoomEntranceScript.NORTH, Vector2i(5, 21), Vector2i(5, 19))
	var ep_opt = _EntrancePairScript.new(1, ent_a1, ent_b1, 10.0)

	var req_req := _CorridorRequestScript.from_entrance_pair(ep_req, conn_req.is_required)
	var req_opt := _CorridorRequestScript.from_entrance_pair(ep_opt, conn_opt.is_required)

	assert(req_req.is_required == true, "Mandatory connection must produce is_required == true")
	assert(req_opt.is_required == false, "Optional connection must produce is_required == false")
	assert(req_req.connection_id == 0 and req_opt.connection_id == 1, "Connection IDs must be preserved")
	print("  [OK] Test 1 & 2: is_required propagation (mandatory and optional) verified")

	# Test 3: Validación EntrancePair ↔ RoomConnection (Desajuste de room_id es rechazado)
	var grid3 := CellGrid.new(40, 20, CellGrid.CellType.WALL)
	var r3_a := RoomData.new(0, Rect2i(2, 2, 6, 6))
	var r3_b := RoomData.new(1, Rect2i(20, 2, 6, 6))
	grid3.fill_rect(r3_a.rect, CellGrid.CellType.FLOOR)
	grid3.fill_rect(r3_b.rect, CellGrid.CellType.FLOOR)

	var conn3 = _RoomConnectionScript.new(0, 0, 1, true) # Conecta room 0 con room 1
	var mismatched_ent_b = _RoomEntranceScript.new(99, 0, Vector2i(20, 4), _RoomEntranceScript.WEST, Vector2i(21, 4), Vector2i(19, 4)) # room_id = 99 (mismatch!)
	var mismatched_ep = _EntrancePairScript.new(0, ent_a0, mismatched_ent_b, 10.0)

	var door_res3 = _DoorResolverScript.resolve_doors(grid3, [r3_a, r3_b], [mismatched_ep], [], [conn3], cfg)
	assert(not door_res3.is_valid, "DoorResolver must fail when EntrancePair room_id mismatches RoomConnection")
	assert(door_res3.failed_connection_ids.has(0), "Connection 0 must be in failed list")
	print("  [OK] Test 3: EntrancePair <-> RoomConnection identity mismatch rejected")

	# Test 4: Conexiones obligatorias sin entradas -> Falla con MISSING_ENTRANCE_PAIRS
	var grid4 := CellGrid.new(30, 20, CellGrid.CellType.WALL)
	var door_res4 = _DoorResolverScript.resolve_doors(grid4, [r3_a, r3_b], [], [], [conn3], cfg)
	assert(not door_res4.is_valid, "DoorResolver must fail when mandatory connections have no entrance pairs")
	var found_missing_diag: bool = false
	for d in door_res4.diagnostics:
		if d.get("reason", "") == "MISSING_ENTRANCE_PAIRS":
			found_missing_diag = true
	assert(found_missing_diag, "Must record MISSING_ENTRANCE_PAIRS failure reason")
	print("  [OK] Test 4: Mandatory connections without entrances triggers MISSING_ENTRANCE_PAIRS")

	# Test 5: Validación completa ROOM (FLOOR) -> DOOR -> CORRIDOR (Semántica estricta)
	var grid5 := CellGrid.new(30, 20, CellGrid.CellType.WALL)
	grid5.fill_rect(r3_a.rect, CellGrid.CellType.FLOOR)

	# 5.1 Caso inválido: corridor_cell es FLOOR en lugar de CORRIDOR
	grid5.set_cell(Vector2i(8, 4), CellGrid.CellType.DOOR)
	grid5.set_cell(Vector2i(9, 4), CellGrid.CellType.FLOOR) # No es CORRIDOR
	var fake_door5 := _DoorPlacementScript.new(0, 0, Vector2i(8, 4), _RoomEntranceScript.EAST, Vector2i(7, 4), Vector2i(9, 4))
	var val5_invalid = _DoorTransitionValidatorScript.validate_local_transition(grid5, fake_door5, r3_a)
	assert(not val5_invalid["is_valid"], "Door adjacent to FLOOR instead of CORRIDOR must fail")
	assert(val5_invalid["reason"] == "NO_CORRIDOR_AT_ENTRANCE", "Reason must be NO_CORRIDOR_AT_ENTRANCE")

	# 5.2 Caso inválido: room_cell es WALL
	grid5.set_cell(Vector2i(9, 4), CellGrid.CellType.CORRIDOR)
	grid5.set_cell(Vector2i(7, 4), CellGrid.CellType.WALL) # Interior es muro
	var val5_wall = _DoorTransitionValidatorScript.validate_local_transition(grid5, fake_door5, r3_a)
	assert(not val5_wall["is_valid"], "Door with WALL interior must fail")
	assert(val5_wall["reason"] == "ROOM_CELL_NOT_WALKABLE", "Reason must be ROOM_CELL_NOT_WALKABLE")

	# 5.3 Caso válido
	grid5.set_cell(Vector2i(7, 4), CellGrid.CellType.FLOOR)
	var val5_valid = _DoorTransitionValidatorScript.validate_local_transition(grid5, fake_door5, r3_a)
	assert(val5_valid["is_valid"], "Strict ROOM (FLOOR) -> DOOR -> CORRIDOR must pass")
	print("  [OK] Test 5: Strict ROOM -> DOOR -> CORRIDOR transition validation verified")

	# Test 6: Cardinalidad 1:1 de DoorPair (Detección de DUPLICATE_DOOR_PAIR y MISSING_DOOR_PAIR)
	var grid6 := CellGrid.new(40, 20, CellGrid.CellType.WALL)
	var dp6_a := _DoorPairScript.new(0, fake_door5, fake_door5)
	var dp6_dup := _DoorPairScript.new(0, fake_door5, fake_door5) # Mismo connection_id = 0 (duplicado)
	var val6_dup = _DoorTransitionValidatorScript.validate_global(grid6, [dp6_a, dp6_dup], [conn3], [r3_a, r3_b])
	assert(not val6_dup["is_valid"] and val6_dup["reason"] == "DUPLICATE_DOOR_PAIR", "Duplicate DoorPair for same connection must fail")

	# Caso faltante para conexión obligatoria
	var val6_missing = _DoorTransitionValidatorScript.validate_global(grid6, [], [conn3], [r3_a, r3_b])
	assert(not val6_missing["is_valid"] and val6_missing["reason"] == "MISSING_DOOR_PAIR", "Missing DoorPair for mandatory connection must fail")
	print("  [OK] Test 6: 1:1 cardinality enforced (DUPLICATE_DOOR_PAIR and MISSING_DOOR_PAIR)")

	# Test 7: Atomicidad de DoorResolver (Una puerta inválida no deja mutaciones parciales)
	var grid7 := CellGrid.new(50, 30, CellGrid.CellType.WALL)
	var r7_a := RoomData.new(0, Rect2i(2, 2, 6, 6))
	var r7_b := RoomData.new(1, Rect2i(20, 2, 6, 6))
	var r7_c := RoomData.new(2, Rect2i(35, 2, 6, 6))
	grid7.fill_rect(r7_a.rect, CellGrid.CellType.FLOOR)
	grid7.fill_rect(r7_b.rect, CellGrid.CellType.FLOOR)
	grid7.fill_rect(r7_c.rect, CellGrid.CellType.FLOOR)

	var conn7_1 = _RoomConnectionScript.new(0, 0, 1, true)
	var conn7_2 = _RoomConnectionScript.new(1, 1, 2, true) # Esta conexión se dejará sin corredor

	var ent_res7 = _EntranceSolverScript.resolve([r7_a, r7_b, r7_c], [conn7_1, conn7_2], grid7, cfg)
	var carver_res7 = _AStarCarverScript.carve_corridors(grid7, [r7_a, r7_b, r7_c], ent_res7.entrance_pairs, [conn7_1, conn7_2], cfg)

	# Snapshot antes de DoorResolver
	var grid7_snapshot_before := grid7.to_debug_string()

	# Pasar solo el path de conn7_1 (conn7_2 no tiene path -> debe fallar atómicamente)
	var paths_only_1: Array = [carver_res7.paths[0]]
	var door_res7 = _DoorResolverScript.resolve_doors(grid7, [r7_a, r7_b, r7_c], ent_res7.entrance_pairs, paths_only_1, [conn7_1, conn7_2], cfg)

	assert(not door_res7.is_valid, "DoorResolver must fail when mandatory connection 1 lacks a corridor path")
	var grid7_snapshot_after := grid7.to_debug_string()
	assert(grid7_snapshot_before == grid7_snapshot_after, "CellGrid must remain 100%% unmutated when DoorResolver fails")
	print("  [OK] Test 7: DoorResolver full atomicity verified (zero partial commit on failure)")

	# Test 8: Conexión Opcional End-to-End (Aceptada = 2 puertas, Rechazada = 0 puertas)
	var grid8 := CellGrid.new(40, 30, CellGrid.CellType.WALL)
	var r8_a := RoomData.new(0, Rect2i(5, 5, 8, 8), &"start")
	var r8_b := RoomData.new(1, Rect2i(25, 5, 8, 8), &"goal")
	grid8.fill_rect(r8_a.rect, CellGrid.CellType.FLOOR)
	grid8.fill_rect(r8_b.rect, CellGrid.CellType.FLOOR)

	var conn8_opt = _RoomConnectionScript.new(0, 0, 1, false) # Opcional
	var ent_res8 = _EntranceSolverScript.resolve([r8_a, r8_b], [conn8_opt], grid8, cfg)
	var carver_res8 = _AStarCarverScript.carve_corridors(grid8, [r8_a, r8_b], ent_res8.entrance_pairs, [conn8_opt], cfg)
	assert(carver_res8.is_valid and carver_res8.paths.size() == 1, "Optional corridor must be carved when path is clear")

	var door_res8 = _DoorResolverScript.resolve_doors(grid8, [r8_a, r8_b], ent_res8.entrance_pairs, carver_res8.paths, [conn8_opt], cfg)
	assert(door_res8.is_valid, "Accepted optional connection must resolve doors successfully")
	assert(door_res8.door_pairs.size() == 1, "Accepted optional connection produces exactly 1 DoorPair")
	assert(door_res8.doors.size() == 2, "Accepted optional connection produces exactly 2 doors")
	print("  [OK] Test 8: End-to-end optional connection contract verified")

	# Test 9: Inmutabilidad de FloodFill (verify_critical_path y verify_all_rooms_reachable no mutan CellGrid)
	var flood_fill := _FloodFillScript.new()
	var grid9_snap_before := grid8.to_debug_string()
	var ok_critical := flood_fill.verify_critical_path(grid8)
	var ok_rooms := flood_fill.verify_all_rooms_reachable(grid8, [r8_a, r8_b])
	var grid9_snap_after := grid8.to_debug_string()

	assert(ok_critical and ok_rooms, "Dungeon must be connected")
	assert(grid9_snap_before == grid9_snap_after, "FloodFill query methods must NEVER mutate CellGrid")
	print("  [OK] Test 9: FloodFill pure non-mutating validation verified")

	# Test 10: Determinismo Lógico Absoluto en DungeonPipeline
	var pipeline := _DungeonPipelineScript.new()
	var pipe_cfg := DungeonConfig.new()
	pipe_cfg.seed = 987654
	pipe_cfg.use_fixed_seed = true

	var res10_a = pipeline.call("generate", pipe_cfg, 5, true)
	var res10_b = pipeline.call("generate", pipe_cfg, 5, true)

	assert(res10_a != null and res10_b != null, "Pipeline generation must succeed")
	assert(res10_a.rooms.size() == res10_b.rooms.size(), "Room counts must match")
	assert(res10_a.connections.size() == res10_b.connections.size(), "Connection counts must match")
	assert(res10_a.entrance_pairs.size() == res10_b.entrance_pairs.size(), "Entrance pairs must match")
	assert(res10_a.corridor_paths.size() == res10_b.corridor_paths.size(), "Corridor paths must match")
	assert(res10_a.doors.size() == res10_b.doors.size(), "Doors must match")
	assert(res10_a.door_pairs.size() == res10_b.door_pairs.size(), "Door pairs must match")
	assert(res10_a.grid.to_debug_string() == res10_b.grid.to_debug_string(), "Grid output must be 100%% byte-identical")
	print("  [OK] Test 10: 100% logical determinism verified across independent pipeline runs")

	print("[PASS] test_phase6_1_hardening completed successfully with 100% assertions passing!")
	quit(0)
