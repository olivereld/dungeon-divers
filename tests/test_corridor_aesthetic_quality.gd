extends SceneTree

## Test de métricas de calidad estética y configuración de corredores y puertas (Fase Refined).

const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")

func _init() -> void:
	print("--- Running test_corridor_aesthetic_quality ---")
	var cfg := DungeonConfig.new()

	# 1. Validar parámetros de calidad de corredores en DungeonConfig
	assert("corridor_turn_penalty" in cfg, "Config must have corridor_turn_penalty")
	assert("corridor_proximity_penalty" in cfg, "Config must have corridor_proximity_penalty")
	assert("corridor_max_preferred_turns" in cfg, "Config must have corridor_max_preferred_turns")
	assert("prefer_orthogonal_routes" in cfg, "Config must have prefer_orthogonal_routes")
	assert("allow_astar_fallback" in cfg, "Config must have allow_astar_fallback")

	# 2. Validar parámetros de calidad de puertas en DungeonConfig
	assert("minimum_corridor_door_spacing" in cfg, "Config must have minimum_corridor_door_spacing")
	assert("same_side_door_penalty" in cfg, "Config must have same_side_door_penalty")
	assert("corridor_door_proximity_penalty" in cfg, "Config must have corridor_door_proximity_penalty")
	assert("distribute_room_doors_across_sides" in cfg, "Config must have distribute_room_doors_across_sides")

	# 3. Validar valores por defecto razonables
	assert(cfg.corridor_turn_penalty >= 5.0, "Turn penalty should be >= 5.0")
	assert(cfg.corridor_max_preferred_turns >= 2, "Preferred turns should be >= 2")
	assert(cfg.minimum_corridor_door_spacing >= 3, "Corridor door spacing should be >= 3")
	assert(cfg.prefer_orthogonal_routes == true, "prefer_orthogonal_routes default must be true")

	# 4. Validar campos y constructor de CorridorPath
	var cl: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var path = _CorridorPathScript.new(1, 0, 1, cl, cl, 3.0, 0)
	assert("turn_count" in path, "CorridorPath must track turn_count")
	assert("straight_run_count" in path, "CorridorPath must track straight_run_count")
	assert("longest_straight_run" in path, "CorridorPath must track longest_straight_run")
	assert("routing_strategy" in path, "CorridorPath must track routing_strategy")

	path.turn_count = 1
	path.straight_run_count = 2
	path.longest_straight_run = 8
	path.routing_strategy = "L_HV"

	var dbg: String = path.to_debug_string()
	assert("L_HV" in dbg or "Turns" in dbg or "Cost" in dbg, "to_debug_string must format properly")

	print("  [OK] Task 1 assertions passed successfully!")

	# -------------------------------------------------------------
	# Task 4 Test 1: Eliminación del patrón en escalera (anti-staircase)
	# Conexión diagonal entre dos salas separadas espacialmente
	# -------------------------------------------------------------
	var grid_diag := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var rd1 := RoomData.new(0, Rect2i(5, 5, 6, 6), &"r1")
	var rd2 := RoomData.new(1, Rect2i(25, 25, 6, 6), &"r2")
	grid_diag.fill_rect(rd1.rect, CellGrid.CellType.FLOOR)
	grid_diag.fill_rect(rd2.rect, CellGrid.CellType.FLOOR)

	var ent_a1 = _RoomEntranceScript.new(0, 0, Vector2i(10, 8), _RoomEntranceScript.Side.EAST, Vector2i(9, 8), Vector2i(11, 8))
	var ent_b1 = _RoomEntranceScript.new(1, 0, Vector2i(25, 27), _RoomEntranceScript.Side.WEST, Vector2i(26, 27), Vector2i(24, 27))
	var p_pair = _EntrancePairScript.new(0, ent_a1, ent_b1, 0.0)
	var c_diag = _RoomConnectionScript.new(0, 0, 1, true)
	var req_diag := _CorridorRequestScript.new(0, 0, 1)
	req_diag.bind_physical_entrances(p_pair)
	var carve_res = _AStarCarverScript.carve_corridors(grid_diag, [rd1, rd2], [req_diag], [c_diag], cfg)

	assert(carve_res.is_valid and carve_res.paths.size() == 1, "Must carve corridor")
	var path_diag: _CorridorPathScript = carve_res.paths[0]
	assert(path_diag.turn_count <= 2, "Diagonal connection must use <= 2 turns (clean L or Z), got %d turns" % path_diag.turn_count)
	assert(path_diag.routing_strategy in ["Straight", "L_HV", "L_VH", "Z_HVH", "Z_VHV", "U_HVH", "U_VHV", "AStar_TurnAware"], "Strategy must be recognized")
	assert(path_diag.longest_straight_run >= 5, "Longest straight run must be >= 5 cells, got %d" % path_diag.longest_straight_run)
	print("  [OK] Task 4 Test 1: Anti-staircase verified (turn_count=%d, strategy=%s)" % [path_diag.turn_count, path_diag.routing_strategy])

	# -------------------------------------------------------------
	# Task 4 Test 2: Fallback A* Turn-Aware en laberinto irregular
	# Cuando la geometría ortogonal simple está completamente bloqueada
	# -------------------------------------------------------------
	var grid_maze := CellGrid.new(40, 40, CellGrid.CellType.WALL)
	var rm1 := RoomData.new(0, Rect2i(2, 2, 6, 6), &"rm1")
	var rm2 := RoomData.new(1, Rect2i(30, 30, 6, 6), &"rm2")
	grid_maze.fill_rect(rm1.rect, CellGrid.CellType.FLOOR)
	grid_maze.fill_rect(rm2.rect, CellGrid.CellType.FLOOR)

	# Bloquear con obstáculos en damero irregular que impiden L y Z simples
	for ox in range(10, 28, 4):
		grid_maze.fill_rect(Rect2i(ox, 5, 2, 25), CellGrid.CellType.COLUMN)

	var ent_ma = _RoomEntranceScript.new(0, 1, Vector2i(7, 4), _RoomEntranceScript.Side.EAST, Vector2i(6, 4), Vector2i(8, 4))
	var ent_mb = _RoomEntranceScript.new(1, 1, Vector2i(30, 32), _RoomEntranceScript.Side.WEST, Vector2i(31, 32), Vector2i(29, 32))
	var p_maze = _EntrancePairScript.new(1, ent_ma, ent_mb, 0.0)
	var c_maze = _RoomConnectionScript.new(1, 0, 1, true)

	var cfg_fallback := DungeonConfig.new()
	cfg_fallback.prefer_orthogonal_routes = false
	cfg_fallback.allow_astar_fallback = true
	var req_maze := _CorridorRequestScript.new(1, 0, 1)
	req_maze.bind_physical_entrances(p_maze)
	var carve_maze = _AStarCarverScript.carve_corridors(grid_maze, [rm1, rm2], [req_maze], [c_maze], cfg_fallback)

	assert(carve_maze.is_valid and carve_maze.paths.size() == 1, "Must carve corridor through maze using fallback")
	var path_maze: _CorridorPathScript = carve_maze.paths[0]
	assert(path_maze.routing_strategy == "AStar_TurnAware", "Strategy must be AStar_TurnAware fallback, got %s" % path_maze.routing_strategy)
	print("  [OK] Task 4 Test 2: Turn-aware A* fallback verified (turns=%d, strategy=%s)" % [path_maze.turn_count, path_maze.routing_strategy])

	# Task 9: Pipeline End-to-End Aesthetic Metrics Verification
	var pipeline = load("res://src/dungeon_generator/core/dungeon_pipeline.gd").new()
	var pipe_cfg := DungeonConfig.new()
	pipe_cfg.seed = 445566
	pipe_cfg.use_fixed_seed = true
	var d_res = pipeline.generate(pipe_cfg, 5, true)
	assert(d_res != null, "Pipeline generation must succeed")
	assert(d_res.metadata.has("aesthetic_metrics"), "DungeonResult must contain aesthetic_metrics in metadata")
	var m: Dictionary = d_res.metadata["aesthetic_metrics"]
	assert(m.has("average_turns_per_corridor"), "Must have average_turns_per_corridor")
	assert(m.has("percent_zero_turn"), "Must have percent_zero_turn")
	assert(m.has("percent_one_turn"), "Must have percent_one_turn")
	assert(m.has("door_count"), "Must have door_count")
	assert(m.has("staircase_corridors") and m["staircase_corridors"] == 0, "Staircase corridors must be 0")
	assert(m["average_turns_per_corridor"] <= 2.0, "Average turns per corridor must be <= 2.0 (got %.2f)" % m["average_turns_per_corridor"])
	print("  [OK] Task 9: Pipeline aesthetic metrics verified (avg_turns=%.2f, zero_turns=%.1f%%, one_turn=%.1f%%, doors=%d)" % [
		m["average_turns_per_corridor"], m["percent_zero_turn"], m["percent_one_turn"], m["door_count"]
	])

	print("[PASS] test_corridor_aesthetic_quality completed successfully!")
	quit(0)
