extends SceneTree

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _EntranceValidatorScript = preload("res://src/dungeon_generator/core/validation/entrance_validator.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_phase4_entrance_solver ---")

	var grid := CellGrid.new(100, 100, CellGrid.CellType.WALL)
	var cfg := DungeonConfig.new()

	# Test 1: Casos 0 y 1 Habitación
	var res_0 = _EntranceSolverScript.resolve([], [], grid, cfg)
	assert(res_0.is_valid, "0 rooms must be valid")
	assert(res_0.entrance_pairs.is_empty(), "0 rooms must produce 0 pairs")
	print("  [OK] Test 1.1: 0 rooms handled cleanly")

	var r0 := RoomData.new(0, Rect2i(10, 10, 8, 8), &"start")
	var res_1 = _EntranceSolverScript.resolve([r0], [], grid, cfg)
	assert(res_1.is_valid, "1 room must be valid")
	assert(res_1.entrance_pairs.is_empty(), "1 room must produce 0 pairs")
	print("  [OK] Test 1.2: 1 room handled cleanly")

	# Test 2: Conexión Horizontal (A izquierda, B derecha -> A=EAST, B=WEST)
	var r_left := RoomData.new(0, Rect2i(10, 20, 8, 8), &"start")
	var r_right := RoomData.new(1, Rect2i(40, 20, 8, 8), &"combat")
	var conn_h = _RoomConnectionScript.new(0, 0, 1, true)
	var res_h = _EntranceSolverScript.resolve([r_left, r_right], [conn_h], grid, cfg)

	assert(res_h.is_valid, "Horizontal pair must be valid")
	assert(res_h.entrance_pairs.size() == 1, "Must produce exactly 1 pair")
	var pair_h = res_h.entrance_pairs[0]
	assert(pair_h.entrance_a.side == _RoomEntranceScript.EAST, "Room A must choose EAST")
	assert(pair_h.entrance_b.side == _RoomEntranceScript.WEST, "Room B must choose WEST")
	assert(pair_h.entrance_a.position.x == r_left.rect.end.x, "Entrance A x must be right wall")
	assert(pair_h.entrance_b.position.x == r_right.rect.position.x - 1, "Entrance B x must be left wall")
	print("  [OK] Test 2: Horizontal alignment resolves to EAST / WEST")

	# Test 3: Conexión Vertical (A arriba, B abajo -> A=SOUTH, B=NORTH)
	var r_top := RoomData.new(0, Rect2i(20, 10, 8, 8), &"start")
	var r_bottom := RoomData.new(1, Rect2i(20, 40, 8, 8), &"goal")
	var conn_v = _RoomConnectionScript.new(0, 0, 1, true)
	var res_v = _EntranceSolverScript.resolve([r_top, r_bottom], [conn_v], grid, cfg)

	assert(res_v.is_valid, "Vertical pair must be valid")
	assert(res_v.entrance_pairs.size() == 1, "Must produce exactly 1 pair")
	var pair_v = res_v.entrance_pairs[0]
	assert(pair_v.entrance_a.side == _RoomEntranceScript.SOUTH, "Room A must choose SOUTH")
	assert(pair_v.entrance_b.side == _RoomEntranceScript.NORTH, "Room B must choose NORTH")
	assert(pair_v.entrance_a.position.y == r_top.rect.end.y, "Entrance A y must be bottom wall")
	assert(pair_v.entrance_b.position.y == r_bottom.rect.position.y - 1, "Entrance B y must be top wall")
	print("  [OK] Test 3: Vertical alignment resolves to SOUTH / NORTH")

	# Test 4: Conexión Diagonal (A arriba-izq, B abajo-der -> Lados cardinales válidos)
	var r_diag_a := RoomData.new(0, Rect2i(10, 10, 8, 8), &"start")
	var r_diag_b := RoomData.new(1, Rect2i(35, 35, 8, 8), &"combat")
	var conn_diag = _RoomConnectionScript.new(0, 0, 1, true)
	var res_diag = _EntranceSolverScript.resolve([r_diag_a, r_diag_b], [conn_diag], grid, cfg)

	assert(res_diag.is_valid, "Diagonal pair must be valid")
	assert(res_diag.entrance_pairs.size() == 1, "Must produce exactly 1 pair")
	var pair_diag = res_diag.entrance_pairs[0]
	assert(pair_diag.entrance_a.side in [_RoomEntranceScript.EAST, _RoomEntranceScript.SOUTH], "Entrance A must be EAST or SOUTH")
	assert(pair_diag.entrance_b.side in [_RoomEntranceScript.WEST, _RoomEntranceScript.NORTH], "Entrance B must be WEST or NORTH")
	print("  [OK] Test 4: Diagonal rooms resolve to coherent cardinal sides")

	# Test 5: Salas Pequeñas (3x3, 4x4, 5x5)
	var r_small3 := RoomData.new(0, Rect2i(10, 10, 3, 3), &"explore")
	var r_small4 := RoomData.new(1, Rect2i(25, 10, 4, 4), &"explore")
	var conn_small = _RoomConnectionScript.new(0, 0, 1, true)
	var res_small = _EntranceSolverScript.resolve([r_small3, r_small4], [conn_small], grid, cfg)
	assert(res_small.is_valid, "Small rooms must resolve valid entrance pairs")
	assert(res_small.entrance_pairs.size() == 1, "Must produce pair for small rooms")
	print("  [OK] Test 5: Small rooms (3x3, 4x4) resolve valid entrances without crash")

	# Test 6: Múltiples conexiones por sala con reservas y espaciado mínimo
	var r_hub := RoomData.new(0, Rect2i(20, 20, 12, 12), &"start")
	var r_e1 := RoomData.new(1, Rect2i(45, 15, 8, 8), &"combat")
	var r_e2 := RoomData.new(2, Rect2i(45, 30, 8, 8), &"treasure")
	var r_s := RoomData.new(3, Rect2i(20, 45, 8, 8), &"boss")

	var conn1 = _RoomConnectionScript.new(0, 0, 1, true)
	var conn2 = _RoomConnectionScript.new(1, 0, 2, true)
	var conn3 = _RoomConnectionScript.new(2, 0, 3, true)

	var res_multi = _EntranceSolverScript.resolve([r_hub, r_e1, r_e2, r_s], [conn1, conn2, conn3], grid, cfg)
	assert(res_multi.is_valid, "Multi-connection hub must be valid")
	assert(res_multi.entrance_pairs.size() == 3, "All 3 connections must be resolved")

	# Verificar que ninguna entrada en la sala hub comparta la misma celda
	var hub_positions: Array[Vector2i] = []
	for p in res_multi.entrance_pairs:
		if p.entrance_a.room_id == 0:
			assert(not hub_positions.has(p.entrance_a.position), "Hub entrance positions must be distinct")
			hub_positions.append(p.entrance_a.position)

	# Verificar espaciado mínimo entre entradas en la misma sala
	for i in range(hub_positions.size()):
		for j in range(i + 1, hub_positions.size()):
			var d: int = absi(hub_positions[i].x - hub_positions[j].x) + absi(hub_positions[i].y - hub_positions[j].y)
			assert(d >= cfg.minimum_entrance_spacing, "Entrance spacing in hub must be >= min_spacing (%d >= %d)" % [d, cfg.minimum_entrance_spacing])
	print("  [OK] Test 6: Multi-connection hub allocates distinct, spaced entrances")

	# Test 7: Conflictos y Prioridad (Mandatory gana, Optional se reubica o se rechaza deterministamente)
	var r_c1 := RoomData.new(0, Rect2i(10, 10, 6, 6))
	var r_c2 := RoomData.new(1, Rect2i(25, 10, 6, 6))
	var r_c3 := RoomData.new(2, Rect2i(25, 12, 6, 6)) # Muy cerca, compiten por la misma pared Este de r_c1

	var conn_mand = _RoomConnectionScript.new(0, 0, 1, true)
	var conn_opt = _RoomConnectionScript.new(1, 0, 2, false)

	var res_conflict = _EntranceSolverScript.resolve([r_c1, r_c2, r_c3], [conn_mand, conn_opt], grid, cfg)
	assert(res_conflict.is_valid, "Conflict scenario with mandatory and optional must be valid overall")
	var found_mand := false
	for p in res_conflict.entrance_pairs:
		if p.connection_id == 0:
			found_mand = true
	assert(found_mand, "Mandatory connection must be resolved")
	print("  [OK] Test 7: Conflict resolution favors mandatory connections")

	# Test 8: Corner Margin (Ninguna entrada en esquina cuando corner_margin = 1)
	var r_corner_test := RoomData.new(0, Rect2i(10, 10, 10, 10))
	var cands = _EntranceSolverScript.generate_candidates(r_corner_test, grid, 1)
	for c in cands:
		# Comprobar que no sea una de las 4 esquinas exactas del muro exterior
		var is_nw_corner: bool = (c.position == Vector2i(9, 9))
		var is_ne_corner: bool = (c.position == Vector2i(20, 9))
		var is_sw_corner: bool = (c.position == Vector2i(9, 20))
		var is_se_corner: bool = (c.position == Vector2i(20, 20))
		assert(not (is_nw_corner or is_ne_corner or is_sw_corner or is_se_corner), "Candidate cannot be on an exact corner vertex")
	print("  [OK] Test 8: Corner margin suppresses corner vertices from candidate pool")

	# Test 9: Semántica de 3 Niveles (inner, boundary, outer)
	for p in res_h.entrance_pairs:
		var ent: RoomEntrance = p.entrance_a
		assert(r_left.rect.has_point(ent.inner_cell), "inner_cell must be inside room interior")
		assert(not r_left.rect.has_point(ent.boundary_cell), "boundary_cell must NOT be inside room interior")
		assert(r_left.expanded(1).has_point(ent.boundary_cell), "boundary_cell must be in wall ring")
		assert(not r_left.rect.has_point(ent.outer_cell), "outer_cell must be outside room interior")
		assert(ent.outer_cell - ent.boundary_cell == ent.get_outward_direction(), "outer delta must match outward direction")
		assert(ent.boundary_cell - ent.inner_cell == ent.get_outward_direction(), "inner delta must match outward direction")
	print("  [OK] Test 9: 3-tier semantic cells (inner, boundary, outer) verified")

	# Test 10: Determinismo Absoluto (Misma entrada -> Mismo resultado exacto)
	var run1 = _EntranceSolverScript.resolve([r_hub, r_e1, r_e2, r_s], [conn1, conn2, conn3], grid, cfg)
	var run2 = _EntranceSolverScript.resolve([r_hub, r_e1, r_e2, r_s], [conn1, conn2, conn3], grid, cfg)
	assert(run1.entrance_pairs.size() == run2.entrance_pairs.size(), "Deterministic run must match pair count")
	for i in range(run1.entrance_pairs.size()):
		var p1 = run1.entrance_pairs[i]
		var p2 = run2.entrance_pairs[i]
		assert(p1.entrance_a.position == p2.entrance_a.position, "Entrance A position must match deterministically")
		assert(p1.entrance_a.side == p2.entrance_a.side, "Entrance A side must match deterministically")
		assert(p1.entrance_b.position == p2.entrance_b.position, "Entrance B position must match deterministically")
		assert(p1.entrance_b.side == p2.entrance_b.side, "Entrance B side must match deterministically")
		assert(is_equal_approx(p1.score, p2.score), "Pair scores must match deterministically")
	print("  [OK] Test 10: 100% deterministic reproducibility verified")

	# Test 11: EntranceValidator Invariants
	var val_report = _EntranceValidatorScript.validate(res_multi, [r_hub, r_e1, r_e2, r_s], [conn1, conn2, conn3], grid)
	assert(val_report.is_valid, "EntranceValidator must approve valid resolution: %s" % str(val_report.errors))
	print("  [OK] Test 11: EntranceValidator passes clean resolution report")

	# Test 12: Invariante de No Mutación (El solver NO modifica CellGrid ni crea puertas ni corredores)
	var test_grid := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var test_r1 := RoomData.new(0, Rect2i(5, 5, 8, 8))
	var test_r2 := RoomData.new(1, Rect2i(25, 5, 8, 8))
	test_grid.fill_rect(test_r1.rect, CellGrid.CellType.FLOOR)
	test_grid.fill_rect(test_r2.rect, CellGrid.CellType.FLOOR)

	var before_doors = test_grid.find_cells_of_type(CellGrid.CellType.DOOR).size()
	var before_corridors = test_grid.find_cells_of_type(CellGrid.CellType.CORRIDOR).size()

	var _solver_res = _EntranceSolverScript.resolve([test_r1, test_r2], [_RoomConnectionScript.new(0, 0, 1, true)], test_grid, cfg)

	var after_doors = test_grid.find_cells_of_type(CellGrid.CellType.DOOR).size()
	var after_corridors = test_grid.find_cells_of_type(CellGrid.CellType.CORRIDOR).size()

	assert(before_doors == after_doors and after_doors == 0, "EntranceSolver must NOT create DOOR cells")
	assert(before_corridors == after_corridors and after_corridors == 0, "EntranceSolver must NOT carve CORRIDOR cells")
	print("  [OK] Test 12: Zero CellGrid mutation invariant verified (no DOOR, no CORRIDOR created by solver)")

	# Test 13: Integración con DungeonPipeline y DungeonResult
	var pipeline = _DungeonPipelineScript.new()
	var pipe_cfg := DungeonConfig.new()
	pipe_cfg.seed = 998877
	pipe_cfg.use_fixed_seed = true
	var dungeon_res = pipeline.call("generate", pipe_cfg, 5, true)
	assert(dungeon_res != null, "DungeonPipeline generate must succeed")
	assert(not dungeon_res.entrance_pairs.is_empty(), "DungeonResult must have populated entrance_pairs")
	for pair in dungeon_res.entrance_pairs:
		assert(pair is _EntrancePairScript, "Each element must be an EntrancePair")
		assert(pair.entrance_a != null and pair.entrance_b != null, "Entrance pair must have valid endpoints")
	# Test 14: Estimación de calidad de aproximación del corredor (Fase 4 Refined)
	# Salas con solapamiento en Y deben seleccionar entradas colineales (mismo Y) para permitir línea recta (0 giros)
	var r_overlap_a := RoomData.new(0, Rect2i(10, 10, 10, 10), &"overA")
	var r_overlap_b := RoomData.new(1, Rect2i(35, 12, 10, 10), &"overB")
	var grid_over := CellGrid.new(60, 60, CellGrid.CellType.WALL)
	grid_over.fill_rect(r_overlap_a.rect, CellGrid.CellType.FLOOR)
	grid_over.fill_rect(r_overlap_b.rect, CellGrid.CellType.FLOOR)

	var conn_over = _RoomConnectionScript.new(0, 0, 1, true)
	var res_over = _EntranceSolverScript.resolve([r_overlap_a, r_overlap_b], [conn_over], grid_over, cfg)
	assert(res_over.is_valid and res_over.entrance_pairs.size() == 1, "Must resolve pair")
	var pair_over = res_over.entrance_pairs[0]
	assert(pair_over.entrance_a.position.y == pair_over.entrance_b.position.y, "Overlapping rooms must choose collinear entrances with identical Y for 0-turn straight corridor (A.y=%d, B.y=%d)" % [pair_over.entrance_a.position.y, pair_over.entrance_b.position.y])
	print("  [OK] Test 14: Collinear approach quality prioritization verified (Y=%d)" % pair_over.entrance_a.position.y)

	print("[PASS] test_phase4_entrance_solver completed successfully with 100% assertions passing!")
	quit(0)
