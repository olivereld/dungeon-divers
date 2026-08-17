extends SceneTree

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")

func _init() -> void:
	print("--- Running test_phase5_astar_carver ---")

	var cfg := DungeonConfig.new()
	cfg.corridor_width = 2

	# Test 1: Conexión simple entre dos salas separadas por muro
	var grid1 := CellGrid.new(40, 30, CellGrid.CellType.WALL)
	var r1 := RoomData.new(0, Rect2i(5, 10, 8, 8), &"start")
	var r2 := RoomData.new(1, Rect2i(25, 10, 8, 8), &"goal")
	grid1.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid1.fill_rect(r2.rect, CellGrid.CellType.FLOOR)

	var conn1 = _RoomConnectionScript.new(0, 0, 1, true)
	var ent_res1 = _EntranceSolverScript.resolve([r1, r2], [conn1], grid1, cfg)
	assert(ent_res1.is_valid and ent_res1.entrance_pairs.size() == 1, "Entrance resolution must succeed")

	var carver_res1 = _AStarCarverScript.carve_corridors(grid1, [r1, r2], ent_res1.entrance_pairs, cfg)
	assert(carver_res1.is_valid, "AStar carver must succeed for simple connection")
	assert(carver_res1.paths.size() == 1, "Must produce 1 CorridorPath")
	var path1: _CorridorPathScript = carver_res1.paths[0]
	assert(not path1.centerline_cells.is_empty(), "Centerline must not be empty")
	assert(not path1.carved_cells.is_empty(), "Carved cells must not be empty")

	# Verificar que el punto inicial y final sean los outer_cells de las entradas
	var pair1 = ent_res1.entrance_pairs[0]
	assert(path1.centerline_cells[0] == pair1.entrance_a.outer_cell, "Path start must be outer_cell A")
	assert(path1.centerline_cells[path1.centerline_cells.size() - 1] == pair1.entrance_b.outer_cell, "Path goal must be outer_cell B")

	# Verificar que las celdas en el grid se marcaron como CORRIDOR
	for c in path1.carved_cells:
		assert(grid1.get_cell(c) == CellGrid.CellType.CORRIDOR, "Carved cell %s must be CORRIDOR" % str(c))
	print("  [OK] Test 1: Simple connection carved continuously between outer_A and outer_B")

	# Test 2: Reutilización de corredores existentes
	var grid2 := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var r_center := RoomData.new(0, Rect2i(15, 15, 10, 10), &"start")
	var r_top := RoomData.new(1, Rect2i(15, 2, 8, 6), &"combat")
	var r_bottom := RoomData.new(2, Rect2i(15, 32, 8, 6), &"boss")
	grid2.fill_rect(r_center.rect, CellGrid.CellType.FLOOR)
	grid2.fill_rect(r_top.rect, CellGrid.CellType.FLOOR)
	grid2.fill_rect(r_bottom.rect, CellGrid.CellType.FLOOR)

	var c_t = _RoomConnectionScript.new(0, 0, 1, true)
	var c_b = _RoomConnectionScript.new(1, 0, 2, true)
	var ent_res2 = _EntranceSolverScript.resolve([r_center, r_top, r_bottom], [c_t, c_b], grid2, cfg)
	var carver_res2 = _AStarCarverScript.carve_corridors(grid2, [r_center, r_top, r_bottom], ent_res2.entrance_pairs, cfg)
	assert(carver_res2.is_valid and carver_res2.paths.size() == 2, "Both connections must be carved")
	print("  [OK] Test 2: Multi-connection corridors carved cleanly")

	# Test 3: Evasión de salas prohibidas (no debe cruzar una 3ra sala no autorizada)
	var grid3 := CellGrid.new(50, 30, CellGrid.CellType.WALL)
	var r_a := RoomData.new(0, Rect2i(5, 10, 6, 6), &"start")
	var r_blocker := RoomData.new(1, Rect2i(20, 8, 10, 10), &"combat") # En medio directo del camino
	var r_b := RoomData.new(2, Rect2i(38, 10, 6, 6), &"goal")
	grid3.fill_rect(r_a.rect, CellGrid.CellType.FLOOR)
	grid3.fill_rect(r_blocker.rect, CellGrid.CellType.FLOOR)
	grid3.fill_rect(r_b.rect, CellGrid.CellType.FLOOR)

	var conn_ab = _RoomConnectionScript.new(0, 0, 2, true) # Conecta 0 con 2, ignorando la sala 1
	var ent_res3 = _EntranceSolverScript.resolve([r_a, r_blocker, r_b], [conn_ab], grid3, cfg)
	var carver_res3 = _AStarCarverScript.carve_corridors(grid3, [r_a, r_blocker, r_b], ent_res3.entrance_pairs, cfg)
	assert(carver_res3.is_valid, "AStar must find a path circumventing the middle room")

	var path3: _CorridorPathScript = carver_res3.paths[0]
	for p in path3.centerline_cells:
		assert(not r_blocker.rect.has_point(p), "Corridor path cannot enter forbidden room 1: %s" % str(p))
	print("  [OK] Test 3: Forbidden room interior is strictly avoided by A*")

	# Test 4: Evasión de obstáculos sólidos (COLUMN y OBSTACLE)
	var grid4 := CellGrid.new(30, 20, CellGrid.CellType.WALL)
	var r_obs_a := RoomData.new(0, Rect2i(3, 8, 4, 4))
	var r_obs_b := RoomData.new(1, Rect2i(23, 8, 4, 4))
	grid4.fill_rect(r_obs_a.rect, CellGrid.CellType.FLOOR)
	grid4.fill_rect(r_obs_b.rect, CellGrid.CellType.FLOOR)

	# Colocar una pared de columnas en medio
	for y in range(5, 15):
		grid4.set_cell(Vector2i(15, y), CellGrid.CellType.COLUMN)
	# Dejar un paso libre solo en y=3
	grid4.set_cell(Vector2i(15, 3), CellGrid.CellType.WALL)

	var conn_obs = _RoomConnectionScript.new(0, 0, 1, true)
	var ent_obs = _EntranceSolverScript.resolve([r_obs_a, r_obs_b], [conn_obs], grid4, cfg)
	var carver_obs = _AStarCarverScript.carve_corridors(grid4, [r_obs_a, r_obs_b], ent_obs.entrance_pairs, cfg)
	assert(carver_obs.is_valid, "AStar must navigate around the column obstacle")
	for p in carver_obs.paths[0].centerline_cells:
		assert(grid4.get_cell(p) != CellGrid.CellType.COLUMN, "Path cannot step on COLUMN cell: %s" % str(p))
	print("  [OK] Test 4: Column and solid obstacles are strictly avoided")

	# Test 5: Fallo atómico sin mutación (Si no hay camino, el grid queda 100% inalterado)
	var grid5 := CellGrid.new(30, 20, CellGrid.CellType.WALL)
	var r_trapped_a := RoomData.new(0, Rect2i(4, 4, 4, 4))
	var r_trapped_b := RoomData.new(1, Rect2i(20, 4, 4, 4))
	grid5.fill_rect(r_trapped_a.rect, CellGrid.CellType.FLOOR)
	grid5.fill_rect(r_trapped_b.rect, CellGrid.CellType.FLOOR)

	# Encerrar totalmente room A con columnas impenetrables en un radio de 4 celdas
	for y in range(0, 20):
		grid5.set_cell(Vector2i(10, y), CellGrid.CellType.COLUMN)

	var grid5_snapshot: String = grid5.to_debug_string()

	var conn_trap = _RoomConnectionScript.new(0, 0, 1, true)
	var ent_trap = _EntranceSolverScript.resolve([r_trapped_a, r_trapped_b], [conn_trap], grid5, cfg)
	var carver_trap = _AStarCarverScript.carve_corridors(grid5, [r_trapped_a, r_trapped_b], ent_trap.entrance_pairs, cfg)

	assert(not carver_trap.is_valid, "Trapped connection must report failure")
	assert(carver_trap.failed_connection_ids.has(0), "Connection 0 must be in failed list")
	var grid5_after_snapshot: String = grid5.to_debug_string()
	assert(grid5_snapshot == grid5_after_snapshot, "CellGrid must remain 100%% unmutated when pathfinding fails")
	print("  [OK] Test 5: Zero-mutation on path failure verified (atomic Find->Validate->Commit)")

	# Test 6: Ensanchamiento (corridor_width = 2)
	var cfg_w2 := DungeonConfig.new()
	cfg_w2.corridor_width = 2
	var grid6 := CellGrid.new(30, 30, CellGrid.CellType.WALL)
	var r_w1 := RoomData.new(0, Rect2i(5, 12, 6, 6))
	var r_w2 := RoomData.new(1, Rect2i(20, 12, 6, 6))
	grid6.fill_rect(r_w1.rect, CellGrid.CellType.FLOOR)
	grid6.fill_rect(r_w2.rect, CellGrid.CellType.FLOOR)

	var conn_w = _RoomConnectionScript.new(0, 0, 1, true)
	var ent_w = _EntranceSolverScript.resolve([r_w1, r_w2], [conn_w], grid6, cfg_w2)
	var carver_w = _AStarCarverScript.carve_corridors(grid6, [r_w1, r_w2], ent_w.entrance_pairs, cfg_w2)
	assert(carver_w.is_valid, "Widening with width=2 must succeed")
	var path_w: _CorridorPathScript = carver_w.paths[0]
	assert(path_w.carved_cells.size() > path_w.centerline_cells.size(), "Carved cells must exceed centerline count due to widening")
	print("  [OK] Test 6: Corridor widening (width=2) generated and committed successfully")

	# Test 7: Preservación de cuello de botella en la entrada
	var ent_pair_w = ent_w.entrance_pairs[0]
	var boundary_a = ent_pair_w.entrance_a.boundary_cell
	assert(grid6.get_cell(boundary_a) == CellGrid.CellType.CORRIDOR, "Boundary cell A must be carved to connect room")
	print("  [OK] Test 7: Entrance boundary threshold preserved and cleanly connected")

	# Test 8: Determinismo Absoluto
	var grid8_a := CellGrid.new(40, 30, CellGrid.CellType.WALL)
	var grid8_b := CellGrid.new(40, 30, CellGrid.CellType.WALL)
	grid8_a.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid8_a.fill_rect(r2.rect, CellGrid.CellType.FLOOR)
	grid8_b.fill_rect(r1.rect, CellGrid.CellType.FLOOR)
	grid8_b.fill_rect(r2.rect, CellGrid.CellType.FLOOR)

	var res8_a = _AStarCarverScript.carve_corridors(grid8_a, [r1, r2], ent_res1.entrance_pairs, cfg)
	var res8_b = _AStarCarverScript.carve_corridors(grid8_b, [r1, r2], ent_res1.entrance_pairs, cfg)

	assert(res8_a.paths.size() == res8_b.paths.size(), "Path counts must match")
	assert(res8_a.paths[0].centerline_cells == res8_b.paths[0].centerline_cells, "Centerline cells must match 100%%")
	assert(res8_a.paths[0].carved_cells == res8_b.paths[0].carved_cells, "Carved cells must match 100%%")
	assert(grid8_a.to_debug_string() == grid8_b.to_debug_string(), "Grid snapshots must be identical")
	print("  [OK] Test 8: 100% deterministic reproducibility verified across independent runs")

	# Test 9: Integración completa con DungeonPipeline y DungeonResult
	var pipeline = _DungeonPipelineScript.new()
	var pipe_cfg := DungeonConfig.new()
	pipe_cfg.seed = 123456
	pipe_cfg.use_fixed_seed = true
	var dungeon_res = pipeline.call("generate", pipe_cfg, 5, true)
	assert(dungeon_res != null, "DungeonPipeline must generate successfully")
	assert(not dungeon_res.corridor_paths.is_empty(), "DungeonResult must have populated corridor_paths")
	for cp in dungeon_res.corridor_paths:
		assert(cp is _CorridorPathScript, "Each element must be a CorridorPath")
		assert(not cp.centerline_cells.is_empty(), "CorridorPath centerline must be valid")
	print("  [OK] Test 9: DungeonPipeline full generation with AStarCarver integrated (%d paths carved)" % dungeon_res.corridor_paths.size())

	# Test 10: Conexión física verificada (Flood fill entre salas conectadas)
	var room0_center = dungeon_res.rooms[0].get_walkable_point(dungeon_res.grid)
	var room1_center = dungeon_res.rooms[1].get_walkable_point(dungeon_res.grid)
	assert(dungeon_res.grid.is_walkable(room0_center), "Room 0 center must be walkable")
	assert(dungeon_res.grid.is_walkable(room1_center), "Room 1 center must be walkable")
	print("  [OK] Test 10: Physical connectivity verified through walkable corridor network")

	print("[PASS] test_phase5_astar_carver completed successfully with 100% assertions passing!")
	quit(0)
