class_name DungeonPipeline
extends RefCounted

## Orquestador del pipeline completo de generación procedural de mazmorras.
## Cero dependencias de nodos de escena — lógica pura testeable en headless.

signal generation_started
signal phase_completed(phase_name: String, elapsed_ms: float)
signal generation_completed(result: DungeonResult)
signal generation_failed(error: String)

const _DelaunayTriangulatorScript = preload("res://src/dungeon_generator/core/algorithms/delaunay_triangulator.gd")
const _MSTSolverScript = preload("res://src/dungeon_generator/core/algorithms/mst_solver.gd")
const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _DungeonResultScript = preload("res://src/dungeon_generator/core/data/dungeon_result.gd")
const _RoomGraphBuilderScript = preload("res://src/dungeon_generator/core/topology/room_graph_builder.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _DoorResolverScript = preload("res://src/dungeon_generator/core/solvers/door_resolver.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")
const _RoomConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/room_connectivity_repair.gd")
const _CorridorConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/corridor_connectivity_repair.gd")

var _seed_registry: DungeonSeedRegistry = DungeonSeedRegistry.new()
var _mission_grammar := MissionGrammar.new()
var _space_grammar := SpaceGrammar.new()
var _winnability_solver := WinnabilitySolver.new()
var _cellular_automata := CellularAutomata.new()
var _bsp_partitioner := BSPPartitioner.new()
var _corridor_carver := CorridorCarver.new()
var _flood_fill := FloodFill.new()
var _fitness_evaluator := FitnessEvaluator.new()

func get_seed_registry() -> DungeonSeedRegistry:
	return _seed_registry

const MAX_ATTEMPTS: int = 5

func generate(config: DungeonConfig = null, max_retries: int = MAX_ATTEMPTS, force_new_seed: bool = false) -> DungeonResult:
	if config == null:
		config = DungeonConfig.new()

	if force_new_seed:
		_seed_registry.clear_dungeon(config.dungeon_id)

	var start_time: int = Time.get_ticks_msec()
	generation_started.emit()

	var base_seed: int = _resolve_seed(config, 0)

	for attempt in range(max_retries):
		var attempt_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"attempt")
		var repair_seed_chain: Array[Dictionary] = []
		var attempt_failed: bool = false

		# Derivar semillas deterministas para cada etapa
		var mission_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"mission")
		var layout_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"layout")
		var topology_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"topology")
		var corridor_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"corridor")
		var variation_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"variation")
		var connectivity_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"connectivity")

		var rng_variation := RandomNumberGenerator.new()
		rng_variation.seed = variation_seed

		var rng_topology := RandomNumberGenerator.new()
		rng_topology.seed = topology_seed

		var rng_corridor := RandomNumberGenerator.new()
		rng_corridor.seed = corridor_seed

		var rng_connectivity := RandomNumberGenerator.new()
		rng_connectivity.seed = connectivity_seed

		# FASE 1: Gramática de Misiones
		var p_start: int = Time.get_ticks_msec()
		var mission_graph: DungeonGraph = _mission_grammar.generate(config, mission_seed)
		phase_completed.emit("mission_grammar", float(Time.get_ticks_msec() - p_start))

		# FASE 2: Validación de Resolubilidad
		p_start = Time.get_ticks_msec()
		var validation: WinnabilitySolver.ValidationResult = _winnability_solver.validate(mission_graph)
		phase_completed.emit("winnability_check", float(Time.get_ticks_msec() - p_start))

		if not validation.is_winnable:
			continue # Reintentar con el siguiente attempt determinista

		# FASE 3: Gramática Espacial (Layout de Habitaciones)
		p_start = Time.get_ticks_msec()
		var rooms: Array[RoomData] = _space_grammar.generate(mission_graph, config, layout_seed)
		phase_completed.emit("space_grammar", float(Time.get_ticks_msec() - p_start))

		# FASE 4: Construcción del CellGrid
		p_start = Time.get_ticks_msec()
		var grid := CellGrid.new(config.grid_width, config.grid_height, CellGrid.CellType.WALL)
		_build_rooms(grid, rooms, config, rng_variation)
		phase_completed.emit("room_construction", float(Time.get_ticks_msec() - p_start))

		# FASE 4.2 & 4.3: Validación y Reparación de Conectividad Interna por Habitación
		for r in rooms:
			var r_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, r)
			if not r_val["is_valid"]:
				var room_repair_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"repair_room_%d" % r.id)
				var rep_res = _RoomConnectivityRepairScript.repair_room_internal_connectivity(
					grid, r, r_val, room_repair_seed
				)

				repair_seed_chain.append({
					"stage": "room_repair",
					"attempt": attempt,
					"room_id": r.id,
					"seed": room_repair_seed,
					"success": rep_res.success,
					"repairs_applied": rep_res.get("repairs_applied", [])
				})

				if not rep_res.success:
					push_warning("[DungeonPipeline] Attempt %d: Room %d internal connectivity failed and could not be repaired. Retrying..." % [
						attempt, r.id
					])
					attempt_failed = true
					break

				var post_val = _StructuralValidatorScript.validate_room_internal_connectivity(grid, r)
				if not post_val["is_valid"]:
					push_warning("[DungeonPipeline] Attempt %d: Room %d failed post-repair validation. Retrying..." % [
						attempt, r.id
					])
					attempt_failed = true
					break

		if attempt_failed:
			continue

		# FASE 4.5: Construcción de Topología (Delaunay + MST + Ciclos)
		p_start = Time.get_ticks_msec()
		var topology_res = _RoomGraphBuilderScript.build_topology(rooms, topology_seed, config.extra_loop_chance)
		phase_completed.emit("topology_builder", float(Time.get_ticks_msec() - p_start))

		# FASE 4.8: Resolución de Entradas (Room Entrance Solver)
		p_start = Time.get_ticks_msec()
		var entrance_res = _EntranceSolverScript.resolve(rooms, topology_res.connections, grid, config)
		phase_completed.emit("entrance_solver", float(Time.get_ticks_msec() - p_start))

		if not entrance_res.is_valid:
			push_warning("[DungeonPipeline] Attempt %d: EntranceSolver failed to resolve mandatory connections. Retrying..." % attempt)
			continue

		# FASE 5 & 5.3: Tallado y Reparación de Corredores (A* Carver + CorridorRepair)
		p_start = Time.get_ticks_msec()
		var corridor_res = _AStarCarverScript.carve_corridors(
			grid,
			rooms,
			entrance_res.entrance_pairs,
			topology_res.connections,
			config
		)
		phase_completed.emit("corridor_carving", float(Time.get_ticks_msec() - p_start))

		if not corridor_res.is_valid:
			var corridor_repair_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"repair_corridors")
			var c_rep_res = _CorridorConnectivityRepairScript.repair_missing_corridors(
				grid, rooms, entrance_res.entrance_pairs, topology_res.connections, corridor_res, corridor_repair_seed, config
			)

			repair_seed_chain.append({
				"stage": "corridor_repair",
				"attempt": attempt,
				"seed": corridor_repair_seed,
				"success": c_rep_res.success,
				"repairs_applied": c_rep_res.get("repairs_applied", [])
			})

			if not c_rep_res.success:
				push_warning("[DungeonPipeline] Attempt %d: AStarCarver failed to carve required corridors and repair failed. Retrying..." % attempt)
				continue
			corridor_res = c_rep_res.corridor_res

		# 5.4 Re-asegurar contigüidad interna de todas las habitaciones tras el tallado de corredores
		for r in rooms:
			var r_check = _StructuralValidatorScript.validate_room_internal_connectivity(grid, r)
			if not r_check["is_valid"]:
				var post_repair_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, attempt, &"post_corridor_repair_room_%d" % r.id)
				var post_rep = _RoomConnectivityRepairScript.repair_room_internal_connectivity(
					grid, r, r_check, post_repair_seed
				)
				if post_rep.get("success", false):
					repair_seed_chain.append({
						"stage": "post_corridor_room_repair",
						"attempt": attempt,
						"room_id": r.id,
						"seed": post_repair_seed
					})

		# FASE 6: Resolución de Puertas y Umbrales (Door Resolver)
		p_start = Time.get_ticks_msec()
		var door_res = _DoorResolverScript.resolve_doors(
			grid,
			rooms,
			entrance_res.entrance_pairs,
			corridor_res.paths,
			topology_res.connections,
			config
		)
		phase_completed.emit("door_resolver", float(Time.get_ticks_msec() - p_start))

		if not door_res.is_valid:
			push_warning("[DungeonPipeline] Attempt %d: DoorResolver failed to resolve doors. Retrying..." % attempt)
			continue

		# FASE 6.5: Colocación de Marcadores Especiales (Spawn, Objetivo, Llaves, Puertas Bloqueadas)
		_place_special_markers(grid, rooms, mission_graph)

		# FASE 7: Garantía de Conectividad mediante Flood Fill y Validación de Salas
		p_start = Time.get_ticks_msec()
		var path_ok: bool = _flood_fill.verify_critical_path(grid) and _flood_fill.verify_100_percent_walkable_connected(grid)
		phase_completed.emit("flood_fill_connectivity", float(Time.get_ticks_msec() - p_start))

		if not path_ok:
			var diag := _flood_fill.get_connectivity_diagnostics(grid, rooms)
			push_warning("[DungeonPipeline] Attempt %d: FloodFill 100%% connectivity check failed (Found %d regions, %d isolated islands: %s). Retrying..." % [
				attempt,
				diag.get("region_count", 0),
				diag.get("isolated_regions_count", 0),
				str(diag.get("isolated_regions", []))
			])
			continue

		# FASE 8: Evaluación de Calidad (Fitness)
		var fitness: float = _fitness_evaluator.evaluate(grid, rooms, config)

		# Empaquetar resultado final
		var result := _DungeonResultScript.new()
		result.grid = grid
		result.mission_graph = mission_graph
		result.rooms = rooms
		result.connections = topology_res.connections
		result.entrance_pairs = entrance_res.entrance_pairs
		result.corridor_paths = corridor_res.paths
		result.doors = door_res.doors
		result.door_pairs = door_res.door_pairs
		result.validation = validation
		result.fitness_score = fitness
		result.seed_used = base_seed
		result.seed_trace = {
			"base_seed": base_seed,
			"attempt": attempt,
			"attempt_seed": attempt_seed,
			"repair_seed_chain": repair_seed_chain
		}
		result.floor_number = config.floor_number
		result.generation_time_ms = float(Time.get_ticks_msec() - start_time)
		result.metadata["aesthetic_metrics"] = _compute_aesthetic_metrics(corridor_res.paths, door_res.doors)

		generation_completed.emit(result)
		return result

	generation_failed.emit("Failed to generate a valid dungeon within max retries.")
	return null

func _compute_aesthetic_metrics(corridors: Array, doors: Array) -> Dictionary:
	var total_turns: int = 0
	var zero_turns: int = 0
	var one_turns: int = 0
	var two_turns: int = 0
	var multi_turns: int = 0
	var strategy_counts: Dictionary = {}

	for p in corridors:
		if p != null:
			var t: int = p.turn_count if ("turn_count" in p) else 0
			total_turns += t
			match t:
				0:
					zero_turns += 1
				1:
					one_turns += 1
				2:
					two_turns += 1
				_:
					multi_turns += 1

			var strat: String = str(p.routing_strategy) if ("routing_strategy" in p) else "Unknown"
			strategy_counts[strat] = strategy_counts.get(strat, 0) + 1

	var c_count: int = corridors.size()
	var avg_turns: float = float(total_turns) / float(c_count) if c_count > 0 else 0.0

	var min_door_dist: int = 999
	for i in range(doors.size()):
		for j in range(i + 1, doors.size()):
			var da = doors[i]
			var db = doors[j]
			if da != null and db != null:
				var m_dist: int = absi(da.position.x - db.position.x) + absi(da.position.y - db.position.y)
				if m_dist < min_door_dist:
					min_door_dist = m_dist

	if min_door_dist == 999:
		min_door_dist = 0

	return {
		"corridor_count": c_count,
		"total_turns": total_turns,
		"average_turns_per_corridor": avg_turns,
		"percent_zero_turn": (float(zero_turns) / float(c_count) * 100.0) if c_count > 0 else 0.0,
		"percent_one_turn": (float(one_turns) / float(c_count) * 100.0) if c_count > 0 else 0.0,
		"percent_two_turn": (float(two_turns) / float(c_count) * 100.0) if c_count > 0 else 0.0,
		"percent_multi_turn": (float(multi_turns) / float(c_count) * 100.0) if c_count > 0 else 0.0,
		"routing_strategies": strategy_counts,
		"door_count": doors.size(),
		"min_door_distance": min_door_dist,
		"staircase_corridors": 0
	}

func _build_room_connections(rooms: Array[RoomData]) -> Array:
	var conns: Array = []
	var seen_pairs: Dictionary = {}
	var conn_id: int = 0
	for room in rooms:
		for target_id in room.connected_room_ids:
			if target_id < 0 or target_id >= rooms.size() or target_id == room.id:
				continue
			var pair_key := "%d-%d" % [mini(room.id, target_id), maxi(room.id, target_id)]
			if not seen_pairs.has(pair_key):
				seen_pairs[pair_key] = true
				var c := _RoomConnectionScript.new(conn_id, mini(room.id, target_id), maxi(room.id, target_id), true)
				conns.append(c)
				conn_id += 1
	return conns

func _resolve_seed(config: DungeonConfig, attempt_offset: int) -> int:
	if config.use_fixed_seed:
		return config.seed + attempt_offset
	var base: int = config.seed
	if base == 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		base = rng.randi_range(100000, 999999999)
	return _seed_registry.get_or_create_seed(config.dungeon_id, config.floor_number, base + attempt_offset)

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
					grid.set_metadata(center, "required_item", m_node.required_items[0])
