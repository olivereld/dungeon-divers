class_name DungeonPipeline
extends RefCounted

## Orquestador del pipeline completo de generación procedural de mazmorras.
## Cero dependencias de nodos de escena — lógica pura testeable en headless.

signal generation_started
signal phase_completed(phase_name: String, elapsed_ms: float)
signal generation_completed(result: DungeonResult)
signal generation_failed(error: String)

class DungeonResult extends RefCounted:
	var grid: CellGrid
	var mission_graph: DungeonGraph
	var rooms: Array[RoomData] = []
	var validation: WinnabilitySolver.ValidationResult
	var fitness_score: float = 0.0
	var seed_used: int = 0
	var floor_number: int = 1
	var generation_time_ms: float = 0.0

const _DoorPlacementSolverScript = preload("res://src/dungeon_generator/core/solvers/door_placement_solver.gd")
const _DelaunayTriangulatorScript = preload("res://src/dungeon_generator/core/algorithms/delaunay_triangulator.gd")
const _MSTSolverScript = preload("res://src/dungeon_generator/core/algorithms/mst_solver.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")

var _seed_registry: DungeonSeedRegistry = DungeonSeedRegistry.new()
var _mission_grammar := MissionGrammar.new()
var _space_grammar := SpaceGrammar.new()
var _winnability_solver := WinnabilitySolver.new()
var _cellular_automata := CellularAutomata.new()
var _bsp_partitioner := BSPPartitioner.new()
var _corridor_carver := CorridorCarver.new()
var _door_placement_solver: RefCounted = _DoorPlacementSolverScript.new()
var _flood_fill := FloodFill.new()
var _fitness_evaluator := FitnessEvaluator.new()

func get_seed_registry() -> DungeonSeedRegistry:
	return _seed_registry

func generate(config: DungeonConfig = null, max_retries: int = 8, force_new_seed: bool = false) -> DungeonResult:
	if config == null:
		config = DungeonConfig.new()

	if force_new_seed:
		_seed_registry.clear_dungeon(config.dungeon_id)

	var start_time: int = Time.get_ticks_msec()
	generation_started.emit()

	for attempt in range(max_retries):
		var attempt_seed: int = _resolve_seed(config, attempt)
		var rng := RandomNumberGenerator.new()
		rng.seed = attempt_seed

		# FASE 1: Gramática de Misiones
		var p_start: int = Time.get_ticks_msec()
		var mission_graph: DungeonGraph = _mission_grammar.generate(config, attempt_seed)
		phase_completed.emit("mission_grammar", float(Time.get_ticks_msec() - p_start))

		# FASE 2: Validación de Resolubilidad
		p_start = Time.get_ticks_msec()
		var validation: WinnabilitySolver.ValidationResult = _winnability_solver.validate(mission_graph)
		phase_completed.emit("winnability_check", float(Time.get_ticks_msec() - p_start))

		if not validation.is_winnable:
			continue # Reintentar con otra semilla

		# FASE 3: Gramática Espacial (Layout de Habitaciones)
		p_start = Time.get_ticks_msec()
		var rooms: Array[RoomData] = _space_grammar.generate(mission_graph, config, attempt_seed)
		phase_completed.emit("space_grammar", float(Time.get_ticks_msec() - p_start))

		# FASE 4: Construcción del CellGrid
		p_start = Time.get_ticks_msec()
		var grid := CellGrid.new(config.grid_width, config.grid_height, CellGrid.CellType.WALL)
		_build_rooms(grid, rooms, config, rng)
		phase_completed.emit("room_construction", float(Time.get_ticks_msec() - p_start))

		# FASE 5: Tallado de Corredores (Delaunay + MST + A* Carver) y Puertas Inteligentes
		p_start = Time.get_ticks_msec()
		_carve_room_connections(grid, rooms, config, rng)
		_door_placement_solver.place_doors(grid, rooms)
		_ensure_room_access(grid, rooms, rng)
		phase_completed.emit("corridor_carving", float(Time.get_ticks_msec() - p_start))

		# FASE 6: Colocación de Marcadores Especiales (Spawn, Objetivo, Llaves, Puertas Bloqueadas)
		_place_special_markers(grid, rooms, mission_graph)

		# FASE 7: Garantía de Conectividad mediante Flood Fill y Validación de Salas
		p_start = Time.get_ticks_msec()
		_flood_fill.ensure_connectivity(grid, _corridor_carver, rng)
		var path_ok: bool = _flood_fill.verify_critical_path(grid) and _flood_fill.verify_all_rooms_reachable(grid, rooms)
		phase_completed.emit("flood_fill_connectivity", float(Time.get_ticks_msec() - p_start))

		if not path_ok:
			continue # Reintentar si alguna sala quedó aislada o falla el camino crítico

		# FASE 8: Evaluación de Calidad (Fitness)
		var fitness: float = _fitness_evaluator.evaluate(grid, rooms, config)

		# Empaquetar resultado final
		var result := DungeonResult.new()
		result.grid = grid
		result.mission_graph = mission_graph
		result.rooms = rooms
		result.validation = validation
		result.fitness_score = fitness
		result.seed_used = attempt_seed
		result.floor_number = config.floor_number
		result.generation_time_ms = float(Time.get_ticks_msec() - start_time)

		generation_completed.emit(result)
		return result

	generation_failed.emit("Failed to generate a valid dungeon within max retries.")
	return null

func _resolve_seed(config: DungeonConfig, attempt_offset: int) -> int:
	if config.use_fixed_seed:
		return config.seed + attempt_offset
	var base_seed: int = config.seed if config.seed != 0 else randi()
	return _seed_registry.get_or_create_seed(config.dungeon_id, config.floor_number, base_seed + attempt_offset)

func _build_rooms(grid: CellGrid, rooms: Array[RoomData], config: DungeonConfig, rng: RandomNumberGenerator) -> void:
	for room in rooms:
		match config.algorithm:
			"CellularAutomata":
				_cellular_automata.apply(grid, room.rect, rng)
				grid.set_cell(room.get_center(), CellGrid.CellType.FLOOR)
			"BSP":
				grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)
			"Hybrid":
				if room.room_type == &"start" or room.room_type == &"goal" or room.room_type == &"boss":
					grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)
				else:
					if rng.randf() > 0.4:
						grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)
					else:
						_cellular_automata.apply(grid, room.rect, rng)
						grid.set_cell(room.get_center(), CellGrid.CellType.FLOOR)
			_:
				grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)

func _carve_room_connections(grid: CellGrid, rooms: Array[RoomData], config: DungeonConfig, rng: RandomNumberGenerator) -> void:
	if config.use_astar_carver or config.corridor_style == "AStar":
		# Pipeline Topológico v3: Delaunay + MST + A* Carver Ponderado
		var delaunay_edges: Array = _DelaunayTriangulatorScript.triangulate(rooms)
		var mst_connections: Array[Vector2i] = _MSTSolverScript.solve(
			rooms.size(),
			delaunay_edges,
			config.extra_loop_chance,
			rng
		)
		_AStarCarverScript.carve_connections(grid, rooms, mst_connections, config, rng)
	else:
		# Fallback a trazador básico configurable
		_corridor_carver.width = config.corridor_width
		match config.corridor_style:
			"Straight":
				_corridor_carver.style = CorridorCarver.Style.STRAIGHT
			"Organic":
				_corridor_carver.style = CorridorCarver.Style.ORGANIC
			_:
				_corridor_carver.style = CorridorCarver.Style.L_SHAPED

		var processed_pairs: Dictionary = {}
		for room in rooms:
			for target_id in room.connected_room_ids:
				if target_id >= 0 and target_id < rooms.size():
					var target_room: RoomData = rooms[target_id]
					var pair_key := "%d-%d" % [mini(room.id, target_room.id), maxi(room.id, target_room.id)]
					if not processed_pairs.has(pair_key):
						processed_pairs[pair_key] = true
						var start_pt: Vector2i = room.get_nearest_edge_point(target_room.get_center())
						var end_pt: Vector2i = target_room.get_nearest_edge_point(room.get_center())
						_corridor_carver.carve(grid, start_pt, end_pt, rng)
						room.connections.append(start_pt)
						target_room.connections.append(end_pt)

func _place_special_markers(grid: CellGrid, rooms: Array[RoomData], mission_graph: DungeonGraph) -> void:
	for room in rooms:
		var center := room.get_center()
		if not grid.is_in_bounds(center):
			continue

		if room.room_type == &"start":
			grid.set_cell(center, CellGrid.CellType.SPAWN)
		elif room.room_type == &"goal":
			grid.set_cell(center, CellGrid.CellType.OBJECTIVE)
		elif room.room_type == &"treasure":
			if room.mission_node_id != -1 and mission_graph.has_node(room.mission_node_id):
				var m_data := mission_graph.get_node_data(room.mission_node_id)
				var m_node := MissionNode.from_dictionary(m_data)
				if not m_node.grants_items.is_empty():
					grid.set_metadata(center, "granted_item", m_node.grants_items[0])
		elif room.room_type == &"puzzle":
			if room.mission_node_id != -1 and mission_graph.has_node(room.mission_node_id):
				var m_data := mission_graph.get_node_data(room.mission_node_id)
				var m_node := MissionNode.from_dictionary(m_data)
				if not m_node.required_items.is_empty():
					_door_placement_solver.place_locked_door(grid, room, m_node.required_items[0])

func _ensure_room_access(grid: CellGrid, rooms: Array[RoomData], rng: RandomNumberGenerator) -> void:
	if rooms.size() <= 1:
		return

	var first_pt: Vector2i = rooms[0].get_walkable_point(grid)
	for i in range(rooms.size()):
		var room: RoomData = rooms[i]
		var room_pt: Vector2i = room.get_walkable_point(grid)
		var target_pt: Vector2i = first_pt if i > 0 else rooms[1].get_walkable_point(grid)

		if not _flood_fill.are_connected(grid, room_pt, target_pt):
			# Buscar la habitación más cercana y forzar tallado de conexión directa
			var closest_room: RoomData = null
			var min_dist: float = 999999.0
			for j in range(rooms.size()):
				if j == i:
					continue
				var other: RoomData = rooms[j]
				var d: float = Vector2(room.get_center()).distance_to(Vector2(other.get_center()))
				if d < min_dist:
					min_dist = d
					closest_room = other

			if closest_room != null:
				var start_pt: Vector2i = room.get_nearest_edge_point(closest_room.get_center())
				var end_pt: Vector2i = closest_room.get_nearest_edge_point(room.get_center())
				_corridor_carver.carve(grid, start_pt, end_pt, rng)
				if grid.is_in_bounds(start_pt):
					grid.set_cell(start_pt, CellGrid.CellType.CORRIDOR)
				if grid.is_in_bounds(end_pt):
					grid.set_cell(end_pt, CellGrid.CellType.CORRIDOR)
				if not room.connections.has(start_pt):
					room.connections.append(start_pt)
				if not closest_room.connections.has(end_pt):
					closest_room.connections.append(end_pt)
