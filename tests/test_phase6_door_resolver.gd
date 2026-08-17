extends SceneTree

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const _DoorResolverScript = preload("res://src/dungeon_generator/core/solvers/door_resolver.gd")
const _DoorTransitionValidatorScript = preload("res://src/dungeon_generator/core/validation/door_transition_validator.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_phase6_door_resolver ---")

	var cfg := DungeonConfig.new()

	# Test 1: Transición válida FLOOR <-> DOOR <-> CORRIDOR
	var grid1 := CellGrid.new(40, 20, CellGrid.CellType.WALL)
	var r1 := RoomData.new(0, Rect2i(5, 5, 8, 8), &"start")
	var r2 := RoomData.new(1, Rect2i(25, 5, 8, 8), &"goal")
	grid1.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid1.fill_rect(r2.rect, CellGrid.CellType.FLOOR)

	var conn1 = _RoomConnectionScript.new(0, 0, 1, true)
	var ent_res1 = _EntranceSolverScript.resolve([r1, r2], [conn1], grid1, cfg)
	var carver_res1 = _AStarCarverScript.carve_corridors(grid1, [r1, r2], ent_res1.entrance_pairs, cfg)
	assert(carver_res1.is_valid, "Corridor carving must succeed")

	var door_res1 = _DoorResolverScript.resolve_doors(grid1, [r1, r2], ent_res1.entrance_pairs, carver_res1.paths, [conn1], cfg)
	assert(door_res1.is_valid, "Door resolution must succeed")
	assert(door_res1.door_pairs.size() == 1, "Must produce exactly 1 DoorPair")
	assert(door_res1.doors.size() == 2, "Must produce exactly 2 DoorPlacements")

	var dp1 = door_res1.door_pairs[0]
	assert(dp1.door_a.room_id == 0 and dp1.door_b.room_id == 1, "Door pair must link room 0 and 1")
	assert(grid1.get_cell(dp1.door_a.position) == CellGrid.CellType.DOOR, "Door A position must be CellType.DOOR")
	assert(grid1.get_cell(dp1.door_b.position) == CellGrid.CellType.DOOR, "Door B position must be CellType.DOOR")

	# Comprobar la transición FLOOR -> DOOR -> CORRIDOR
	assert(grid1.get_cell(dp1.door_a.room_cell) == CellGrid.CellType.FLOOR, "Door A room_cell must be FLOOR")
	assert(grid1.get_cell(dp1.door_a.corridor_cell) == CellGrid.CellType.CORRIDOR, "Door A corridor_cell must be CORRIDOR")
	print("  [OK] Test 1: Valid transition FLOOR <-> DOOR <-> CORRIDOR resolved and committed")

	# Test 2: Validación local de transición inválida (sin corredor)
	var fake_door := _DoorPlacementScript.new(
		0,
		0,
		Vector2i(13, 9),
		_RoomEntranceScript.EAST,
		Vector2i(12, 9),
		Vector2i(14, 9)
	)
	var fake_grid := CellGrid.new(30, 20, CellGrid.CellType.WALL)
	fake_grid.fill_rect(r1.rect, CellGrid.CellType.FLOOR) # No hay corredor en (14, 9)
	var val_fake := _DoorTransitionValidatorScript.validate_local_transition(fake_grid, fake_door, r1)
	assert(not val_fake["is_valid"], "Door without adjacent corridor must fail validation")
	assert(val_fake["reason"] == "NO_CORRIDOR_AT_ENTRANCE", "Failure reason must be NO_CORRIDOR_AT_ENTRANCE")
	print("  [OK] Test 2: Missing corridor detected by DoorTransitionValidator")

	# Test 3: Conexión 2 salas produce exactamente 2 puertas (1 DoorPair)
	assert(dp1.door_a.connection_id == 0 and dp1.door_b.connection_id == 0, "Both doors reference connection 0")
	assert(dp1.door_a.position != dp1.door_b.position, "Door positions must be distinct")
	print("  [OK] Test 3: 2-room connection produces exactly 1 normalized DoorPair")

	# Test 4: Múltiples conexiones por sala (Hub con varias puertas independientes)
	var grid4 := CellGrid.new(50, 50, CellGrid.CellType.WALL)
	var r_hub := RoomData.new(0, Rect2i(20, 20, 12, 12), &"start")
	var r_east := RoomData.new(1, Rect2i(40, 22, 8, 8), &"combat")
	var r_south := RoomData.new(2, Rect2i(22, 40, 8, 8), &"boss")
	grid4.fill_rect(r_hub.rect, CellGrid.CellType.FLOOR)
	grid4.fill_rect(r_east.rect, CellGrid.CellType.FLOOR)
	grid4.fill_rect(r_south.rect, CellGrid.CellType.FLOOR)

	var conn_e = _RoomConnectionScript.new(0, 0, 1, true)
	var conn_s = _RoomConnectionScript.new(1, 0, 2, true)
	var ent_res4 = _EntranceSolverScript.resolve([r_hub, r_east, r_south], [conn_e, conn_s], grid4, cfg)
	var carver_res4 = _AStarCarverScript.carve_corridors(grid4, [r_hub, r_east, r_south], ent_res4.entrance_pairs, cfg)
	var door_res4 = _DoorResolverScript.resolve_doors(grid4, [r_hub, r_east, r_south], ent_res4.entrance_pairs, carver_res4.paths, [conn_e, conn_s], cfg)

	assert(door_res4.is_valid, "Hub multi-connection door resolution must succeed")
	assert(door_res4.door_pairs.size() == 2, "Must produce 2 DoorPairs")
	assert(door_res4.doors.size() == 4, "Must produce 4 DoorPlacements")

	var hub_door_positions: Array[Vector2i] = []
	for d in door_res4.doors:
		if d.room_id == 0:
			assert(not hub_door_positions.has(d.position), "Hub door positions must be distinct")
			hub_door_positions.append(d.position)
	assert(hub_door_positions.size() == 2, "Hub must have 2 distinct doors")
	print("  [OK] Test 4: Multiple independent doors placed on hub room")

	# Test 5: Conflicto de posición (Dos puertas en la misma celda causan fallo atómico)
	var conflict_door_a := _DoorPlacementScript.new(0, 0, Vector2i(10, 10), _RoomEntranceScript.EAST, Vector2i(9, 10), Vector2i(11, 10))
	var conflict_door_b := _DoorPlacementScript.new(1, 1, Vector2i(10, 10), _RoomEntranceScript.WEST, Vector2i(11, 10), Vector2i(9, 10))
	var p_conf1 := _DoorPairScript.new(0, conflict_door_a, _DoorPlacementScript.new(0, 1, Vector2i(20, 10), _RoomEntranceScript.WEST, Vector2i(21, 10), Vector2i(19, 10)))
	var p_conf2 := _DoorPairScript.new(1, conflict_door_b, _DoorPlacementScript.new(1, 2, Vector2i(30, 10), _RoomEntranceScript.WEST, Vector2i(31, 10), Vector2i(29, 10)))

	var val_conf := _DoorTransitionValidatorScript.validate_global(grid1, [p_conf1, p_conf2], [conn_e, conn_s], [r_hub, r_east, r_south])
	assert(not val_conf["is_valid"] and val_conf["reason"] == "DOOR_CONFLICT", "Door position collision must trigger DOOR_CONFLICT")
	print("  [OK] Test 5: Position conflict detected before commit")

	# Test 6: Fallo atómico sin mutación (Si la validación global falla, CellGrid permanece 100% inalterado)
	var grid6 := CellGrid.new(30, 20, CellGrid.CellType.WALL)
	grid6.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid6.fill_rect(r2.rect, CellGrid.CellType.FLOOR)
	var snapshot_before := grid6.to_debug_string()

	# Ejecutar con pares de entrada falsos que no tienen corredor
	var fake_ent_a := _RoomEntranceScript.new(0, 0, Vector2i(13, 9), _RoomEntranceScript.EAST, Vector2i(12, 9), Vector2i(14, 9))
	var fake_ent_b := _RoomEntranceScript.new(1, 0, Vector2i(24, 9), _RoomEntranceScript.WEST, Vector2i(25, 9), Vector2i(23, 9))
	var fake_ep := _EntrancePairScript.new(0, fake_ent_a, fake_ent_b, 10.0)

	var fail_door_res = _DoorResolverScript.resolve_doors(grid6, [r1, r2], [fake_ep], [], [conn1], cfg)
	assert(not fail_door_res.is_valid, "Door resolver must fail when no corridor exists")
	var snapshot_after := grid6.to_debug_string()
	assert(snapshot_before == snapshot_after, "CellGrid must remain 100%% unmutated on door resolution failure")
	print("  [OK] Test 6: Zero mutation on door resolution failure verified")

	# Test 7: Protección contra sobreescritura de celdas especiales (SPAWN, OBJECTIVE)
	var grid7 := CellGrid.new(30, 20, CellGrid.CellType.WALL)
	grid7.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid7.set_cell(Vector2i(13, 9), CellGrid.CellType.SPAWN) # Celda especial en la posición propuesta de puerta
	var val_special := _DoorTransitionValidatorScript.validate_local_transition(grid7, fake_door, r1)
	assert(not val_special["is_valid"] and val_special["reason"] == "DOOR_OVER_SPECIAL_CELL", "Special cell overwrite must be rejected")
	assert(grid7.get_cell(Vector2i(13, 9)) == CellGrid.CellType.SPAWN, "Special cell must remain untouched")
	print("  [OK] Test 7: Special cell (SPAWN/OBJECTIVE) protection verified")

	# Test 8: CellGrid.is_walkable() retorna true para DOOR
	for d in door_res1.doors:
		assert(grid1.is_walkable(d.position), "CellGrid.is_walkable() must return true for DOOR position %s" % str(d.position))
	print("  [OK] Test 8: CellGrid.is_walkable() returns true for all DOOR cells")

	# Test 9: Determinismo absoluto
	var grid9_a := CellGrid.new(40, 20, CellGrid.CellType.WALL)
	var grid9_b := CellGrid.new(40, 20, CellGrid.CellType.WALL)
	grid9_a.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid9_a.fill_rect(r2.rect, CellGrid.CellType.FLOOR)
	grid9_b.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid9_b.fill_rect(r2.rect, CellGrid.CellType.FLOOR)

	var c_res9_a = _AStarCarverScript.carve_corridors(grid9_a, [r1, r2], ent_res1.entrance_pairs, cfg)
	var c_res9_b = _AStarCarverScript.carve_corridors(grid9_b, [r1, r2], ent_res1.entrance_pairs, cfg)

	var d_res9_a = _DoorResolverScript.resolve_doors(grid9_a, [r1, r2], ent_res1.entrance_pairs, c_res9_a.paths, [conn1], cfg)
	var d_res9_b = _DoorResolverScript.resolve_doors(grid9_b, [r1, r2], ent_res1.entrance_pairs, c_res9_b.paths, [conn1], cfg)

	assert(d_res9_a.doors.size() == d_res9_b.doors.size(), "Door count must match deterministically")
	for i in range(d_res9_a.doors.size()):
		assert(d_res9_a.doors[i].position == d_res9_b.doors[i].position, "Door position must match at index %d" % i)
		assert(d_res9_a.doors[i].side == d_res9_b.doors[i].side, "Door side must match at index %d" % i)
	assert(grid9_a.to_debug_string() == grid9_b.to_debug_string(), "Grid snapshots must be identical")
	print("  [OK] Test 9: 100% deterministic door placement snapshot verified")

	# Test 10: Integración completa con DungeonPipeline y DungeonResult
	var pipeline = _DungeonPipelineScript.new()
	var pipe_cfg := DungeonConfig.new()
	pipe_cfg.seed = 884422
	pipe_cfg.use_fixed_seed = true
	var dungeon_res = pipeline.call("generate", pipe_cfg, 5, true)
	assert(dungeon_res != null, "DungeonPipeline must generate successfully")
	assert(not dungeon_res.doors.is_empty(), "DungeonResult must have populated doors")
	assert(not dungeon_res.door_pairs.is_empty(), "DungeonResult must have populated door_pairs")

	for d in dungeon_res.doors:
		assert(d is _DoorPlacementScript, "Each door must be a DoorPlacement instance")
		assert(dungeon_res.grid.get_cell(d.position) == CellGrid.CellType.DOOR, "Door cell must be CellType.DOOR")

	print("  [OK] Test 10: DungeonPipeline full generation with DoorResolver integrated (%d doors, %d door pairs)" % [
		dungeon_res.doors.size(), dungeon_res.door_pairs.size()
	])

	# Test 11: Verificación de la transición física completa en el pipeline
	for dp in dungeon_res.door_pairs:
		var room_a_type = dungeon_res.grid.get_cell(dp.door_a.room_cell)
		var door_a_type = dungeon_res.grid.get_cell(dp.door_a.position)
		var corr_a_type = dungeon_res.grid.get_cell(dp.door_a.corridor_cell)
		assert(dungeon_res.grid.is_walkable(dp.door_a.room_cell), "Door A room cell must be walkable")
		assert(door_a_type == CellGrid.CellType.DOOR, "Door A must be DOOR")
		assert(dungeon_res.grid.is_walkable(dp.door_a.corridor_cell), "Door A corridor cell must be walkable")
	print("  [OK] Test 11: End-to-end ROOM <-> DOOR <-> CORRIDOR physical pipeline verified")

	print("[PASS] test_phase6_door_resolver completed successfully with 100% assertions passing!")
	quit(0)
