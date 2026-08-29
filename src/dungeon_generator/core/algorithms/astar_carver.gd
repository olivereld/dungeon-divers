class_name AStarCarver
extends RefCounted

## Tallador determinista de corredores mediante Planificador Ortogonal y A* Direccional (Fase 5 Refined).
## Jerarquía de tallado:
## 1. OrthogonalCorridorPlanner (Nivel 0 Recta, Nivel 1 L Limpia, Nivel 2 Multi-giro ortogonal)
## 2. Direction-Aware A* Fallback (Penalización por giros en espacio de estados [celda, dirección])
## Implementa el flujo estricto Find -> Validate -> Commit sin fallbacks destructivos.

const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _CorridorCarveResultScript = preload("res://src/dungeon_generator/core/data/corridor_carve_result.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _OrthogonalPlannerScript = preload("res://src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd")

## Método de compatibilidad para llamadas con conexiones basadas en Vector2i.
static func carve_connections(
	grid: CellGrid,
	rooms: Array[RoomData],
	connections: Array[Vector2i],
	config: DungeonConfig = null,
	_rng: RandomNumberGenerator = null
) -> void:
	if connections.is_empty() or rooms.size() < 2:
		return

	var room_conns: Array = []
	var cid: int = 0
	for pair in connections:
		room_conns.append(_RoomConnectionScript.new(cid, pair.x, pair.y, true))
		cid += 1

	var ent_res = _EntranceSolverScript.resolve(rooms, room_conns, grid, config)
	if ent_res.is_valid:
		carve_corridors(grid, rooms, ent_res.entrance_pairs, room_conns, config)

## Ejecuta el tallado para todos los pares de entrada proporcionados por Fase 4.
static func carve_corridors(
	grid: CellGrid,
	rooms: Array[RoomData],
	entrance_pairs: Array,
	connections: Array = [],
	config: DungeonConfig = null
) -> CorridorCarveResult:
	var result = _CorridorCarveResultScript.new()

	if entrance_pairs.is_empty() or rooms.size() < 2:
		result.is_valid = true
		return result

	var cfg := config
	if cfg == null:
		cfg = DungeonConfig.new()

	var width: int = grid.width
	var height: int = grid.height

	# Mapear conexiones para extraer atributos topológicos (is_required)
	var conn_map: Dictionary = {}
	for conn in connections:
		if conn != null:
			conn_map[conn.id] = conn

	# 1. Grafo base AStar2D (construido lazy únicamente si se requiere fallback clásico)
	var astar: AStar2D = null

	# 2. Convertir EntrancePairs o CorridorRequests y ordenar por prioridad
	var requests: Array[CorridorRequest] = []
	for pair in entrance_pairs:
		if pair is CorridorRequest:
			requests.append(pair)
		elif pair != null and "entrance_a" in pair and pair.entrance_a != null and pair.entrance_b != null:
			var conn = conn_map.get(pair.connection_id, null)
			var is_req: bool = conn.is_required if (conn != null and "is_required" in conn) else true
			var req := CorridorRequest.from_entrance_pair(pair, is_req)
			if req != null:
				requests.append(req)

	# Ordenar peticiones: mandatory primero, luego por ID estable
	requests.sort_custom(func(a: CorridorRequest, b: CorridorRequest):
		if a.is_required != b.is_required:
			return a.is_required
		var dist_a: int = absi(a.goal.x - a.start.x) + absi(a.goal.y - a.start.y)
		var dist_b: int = absi(b.goal.x - b.start.x) + absi(b.goal.y - b.start.y)
		if dist_a != dist_b:
			return dist_a < dist_b
		return a.connection_id < b.connection_id
	)

	# 3. Mapear salas para comprobación rápida de ownership
	var room_map: Dictionary = {}
	for r in rooms:
		if r != null:
			room_map[r.id] = r

	# 4. Procesar cada petición atómicamente
	for req in requests:
		var res: Dictionary = _carve_single_request(grid, rooms, room_map, req, cfg, astar, width, height)

		if res["success"]:
			var path: CorridorPath = res["path"]
			result.add_path(path, {
				"connection_id": req.connection_id,
				"room_a": req.room_a_id,
				"room_b": req.room_b_id,
				"start": str(req.start),
				"goal": str(req.goal),
				"cost": path.cost,
				"carved_cells": path.carved_cells.size(),
				"reused_cells": path.reused_cells_count,
				"turns": path.turn_count,
				"strategy": path.routing_strategy,
				"status": "SUCCESS"
			})
		else:
			var reason: String = res.get("reason", "NO_PATH")
			if req.is_required:
				result.add_failure(req.connection_id, reason, {
					"connection_id": req.connection_id,
					"room_a": req.room_a_id,
					"room_b": req.room_b_id,
					"start": str(req.start),
					"goal": str(req.goal)
				})
			else:
				result.add_rejection(req.connection_id, reason, {
					"connection_id": req.connection_id,
					"room_a": req.room_a_id,
					"room_b": req.room_b_id,
					"start": str(req.start),
					"goal": str(req.goal)
				})

	return result

## Procesa una petición individual con el flujo Find -> Validate -> Commit.
static func _carve_single_request(
	grid: CellGrid,
	rooms: Array[RoomData],
	room_map: Dictionary,
	req: CorridorRequest,
	config: DungeonConfig,
	astar: AStar2D,
	grid_width: int,
	grid_height: int
) -> Dictionary:
	var start_pos := req.start
	var goal_pos := req.goal

	# Validación básica de bounds
	if not grid.is_in_bounds(start_pos):
		return {"success": false, "reason": "START_OUT_OF_BOUNDS"}
	if not grid.is_in_bounds(goal_pos):
		return {"success": false, "reason": "GOAL_OUT_OF_BOUNDS"}

	var centerline: Array[Vector2i] = []
	var routing_strategy: String = "Unknown"

	# --- PASO 1: FIND (Jerarquía: 1. OrthogonalPlanner -> 2. Direction-Aware A*) ---
	if config.prefer_orthogonal_routes:
		var ortho_res: Dictionary = _OrthogonalPlannerScript.plan_route(grid, rooms, req.room_a_id, req.room_b_id, start_pos, goal_pos, config)
		if ortho_res.get("success", false):
			centerline = ortho_res["centerline"]
			routing_strategy = ortho_res.get("strategy", "Orthogonal")

	# Fallback a A* direccional si el planificador ortogonal no encontró ruta o no está activado
	if centerline.is_empty() and config.allow_astar_fallback:
		var astar_res: Dictionary = _find_direction_aware_path(grid, rooms, room_map, req, config, grid_width, grid_height)
		if astar_res.get("success", false):
			centerline = astar_res["centerline"]
			routing_strategy = "AStar_TurnAware"
		else:
			# Fallback clásico mediante AStar2D si el direccional estricto fallara
			if astar == null:
				astar = _build_base_astar_graph(grid, config)
			var classic_path := _find_classic_astar_path(astar, rooms, req, config, grid_width)
			if not classic_path.is_empty():
				centerline = classic_path
				routing_strategy = "AStar_Classic"

	if centerline.is_empty():
		return {"success": false, "reason": "NO_PATH"}

	# --- PASO 2: VALIDATE (Validación del camino central) ---
	var val_error: String = _validate_centerline(centerline, start_pos, goal_pos, grid, rooms, req.room_a_id, req.room_b_id)
	if not val_error.is_empty():
		return {"success": false, "reason": val_error}

	# --- PASO 3: WIDEN (Cálculo y validación de la región ensanchada con preservación de esquinas y cuello de botella) ---
	var c_width: int = config.corridor_width if ("corridor_width" in config) else 2
	var bottleneck_dist: int = config.corridor_bottleneck_distance if ("corridor_bottleneck_distance" in config) else 1

	var boundary_cells: Array[Vector2i] = [req.start_boundary, req.goal_boundary]
	var candidate_carved_cells: Array[Vector2i] = _compute_widened_corridor_cells(
		centerline,
		boundary_cells,
		c_width,
		bottleneck_dist,
		grid,
		rooms,
		req.room_a_id,
		req.room_b_id
	)

	# Validar que toda la región a tallar no viole restricciones y no invada salas (Fase 8)
	for cell in candidate_carved_cells:
		if not grid.is_in_bounds(cell):
			return {"success": false, "reason": "WIDENING_OUT_OF_BOUNDS"}
		var cell_type := grid.get_cell(cell)
		if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
			return {"success": false, "reason": "BLOCKED_CELL_IN_REGION"}
		if cell != req.start_boundary and cell != req.goal_boundary:
			var c_owner: int = grid.get_room_owner(cell)
			if c_owner == -1:
				c_owner = _get_room_id_at(cell, rooms)
			if c_owner != -1 and c_owner != req.room_a_id and c_owner != req.room_b_id:
				return {"success": false, "reason": "FORBIDDEN_ROOM_INVADED"}

	# --- PASO 4: COMMIT (Commit atómico al CellGrid) ---
	var reused_count: int = 0
	var total_cost: float = 0.0

	for cell in candidate_carved_cells:
		var current_type := grid.get_cell(cell)
		if current_type == CellGrid.CellType.CORRIDOR:
			reused_count += 1
		else:
			# Tallar como CORRIDOR en el grid
			grid.set_cell(cell, CellGrid.CellType.CORRIDOR)
			if astar != null:
				var cid: int = _get_cell_id(cell, grid_width)
				var w_corridor: float = config.corridor_cost_corridor if ("corridor_cost_corridor" in config) else 1.0
				astar.set_point_weight_scale(cid, w_corridor)

		total_cost += 1.0

	# Asegurar que los interiores de entrada (inner_cell) sean transitable FLOOR y se conecten al interior de la sala
	var room_a: RoomData = room_map.get(req.room_a_id, null)
	var room_b: RoomData = room_map.get(req.room_b_id, null)

	var inner_a: Vector2i = req.start_boundary - req.start_direction
	var inner_b: Vector2i = req.goal_boundary - req.goal_direction
	_connect_inner_to_room_floor(grid, room_a, inner_a)
	_connect_inner_to_room_floor(grid, room_b, inner_b)

	# Calcular métricas de calidad estética del camino
	var metrics: Dictionary = compute_path_metrics(centerline)

	var path = _CorridorPathScript.new(
		req.connection_id,
		req.room_a_id,
		req.room_b_id,
		centerline,
		candidate_carved_cells,
		total_cost,
		reused_count,
		metrics["turn_count"],
		metrics["longest_straight_run"],
		routing_strategy
	)
	path.straight_run_count = metrics["straight_run_count"]

	return {
		"success": true,
		"path": path
	}

## Calcula métricas geométricas y estéticas sobre un centerline.
static func compute_path_metrics(path: Array[Vector2i]) -> Dictionary:
	if path.size() < 2:
		return {
			"turn_count": 0,
			"straight_run_count": 1 if not path.is_empty() else 0,
			"longest_straight_run": path.size()
		}

	var turns: int = 0
	var runs: Array[int] = []
	var current_run: int = 1
	var current_dir: Vector2i = path[1] - path[0]

	for i in range(1, path.size() - 1):
		var next_dir: Vector2i = path[i + 1] - path[i]
		if next_dir != current_dir:
			turns += 1
			runs.append(current_run)
			current_run = 1
			current_dir = next_dir
		else:
			current_run += 1

	runs.append(current_run)

	var longest: int = 0
	for r in runs:
		if r > longest:
			longest = r

	return {
		"turn_count": turns,
		"straight_run_count": runs.size(),
		"longest_straight_run": longest
	}

## Búsqueda A* Direccional (Turn-Aware): explora en el espacio (posición, dirección_entrada)
## penalizando severamente cada cambio de dirección para eliminar el patrón de escalera.
static func _find_direction_aware_path(
	grid: CellGrid,
	rooms: Array[RoomData],
	room_map: Dictionary,
	req: CorridorRequest,
	config: DungeonConfig,
	grid_width: int,
	grid_height: int
) -> Dictionary:
	var start_pos := req.start
	var goal_pos := req.goal
	var turn_penalty: float = config.corridor_turn_penalty
	var cost_corridor: float = config.corridor_cost_corridor
	var cost_wall: float = config.corridor_cost_wall
	var cost_floor: float = config.corridor_cost_room_floor
	var other_room_cost: float = config.corridor_cost_other_room

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	# Cola de prioridad simulada (ordenada por f_score)
	# Estado: String clave "x,y,dx,dy"
	var open_set: Array[Dictionary] = []
	var g_score: Dictionary = {}
	var came_from: Dictionary = {}

	var start_dir := req.start_direction
	var start_key := "%d,%d,%d,%d" % [start_pos.x, start_pos.y, start_dir.x, start_dir.y]
	g_score[start_key] = 0.0

	var h_start: float = _heuristic_turn_aware(start_pos, start_dir, goal_pos, turn_penalty)
	open_set.append({
		"pos": start_pos,
		"dir": start_dir,
		"g": 0.0,
		"f": h_start,
		"key": start_key
	})

	var best_goal_state: String = ""
	var min_goal_cost: float = INF
	var iterations: int = 0
	var max_iterations: int = grid_width * grid_height * 8

	while not open_set.is_empty() and iterations < max_iterations:
		iterations += 1

		# Extraer nodo con menor f_score
		var best_idx: int = 0
		var best_f: float = open_set[0]["f"]
		for i in range(1, open_set.size()):
			if open_set[i]["f"] < best_f:
				best_f = open_set[i]["f"]
				best_idx = i

		var current: Dictionary = open_set[best_idx]
		open_set.remove_at(best_idx)

		var curr_pos: Vector2i = current["pos"]
		var curr_dir: Vector2i = current["dir"]
		var curr_key: String = current["key"]
		var curr_g: float = current["g"]

		if curr_g > g_score.get(curr_key, INF):
			continue

		if curr_pos == goal_pos:
			if curr_g < min_goal_cost:
				min_goal_cost = curr_g
				best_goal_state = curr_key
				break

		# Explorar vecinos cardinales
		for d in directions:
			var next_pos: Vector2i = curr_pos + d

			if not grid.is_in_bounds(next_pos):
				continue

			var ctype: int = grid.get_cell(next_pos)
			if ctype == CellGrid.CellType.VOID or ctype == CellGrid.CellType.COLUMN or ctype == CellGrid.CellType.OBSTACLE:
				continue

			# Coste de terreno
			var step_cost: float = cost_wall
			if ctype == CellGrid.CellType.CORRIDOR:
				step_cost = cost_corridor
			elif ctype == CellGrid.CellType.FLOOR or ctype == CellGrid.CellType.DOOR:
				step_cost = cost_floor

			# Prohibición de invasión de salas y perímetro prohibido de distancia 1
			if next_pos != goal_pos and next_pos != start_pos:
				var owner_id: int = grid.get_room_owner(next_pos)
				if owner_id == -1:
					owner_id = _get_room_id_at(next_pos, rooms)
				if owner_id != -1 and owner_id != req.room_a_id and owner_id != req.room_b_id:
					continue

				# Si no es corredor previo, no puede penetrar en el perímetro de 1 de distancia de salas ajenas
				if ctype != CellGrid.CellType.CORRIDOR:
					var in_buffer := false
					for r in rooms:
						if r != null and r.id != req.room_a_id and r.id != req.room_b_id and r.rect.grow(1).has_point(next_pos):
							in_buffer = true
							break
					if in_buffer:
						continue

				# 1. Proteger jambas laterales de las puertas del inicio y final de la conexión
				var is_jamb := false
				if req.start_direction.y != 0:
					if next_pos == req.start_boundary + Vector2i(-1, 0) or next_pos == req.start_boundary + Vector2i(1, 0):
						is_jamb = true
				elif req.start_direction.x != 0:
					if next_pos == req.start_boundary + Vector2i(0, -1) or next_pos == req.start_boundary + Vector2i(0, 1):
						is_jamb = true

				if req.goal_direction.y != 0:
					if next_pos == req.goal_boundary + Vector2i(-1, 0) or next_pos == req.goal_boundary + Vector2i(1, 0):
						is_jamb = true
				elif req.goal_direction.x != 0:
					if next_pos == req.goal_boundary + Vector2i(0, -1) or next_pos == req.goal_boundary + Vector2i(0, 1):
						is_jamb = true

				if is_jamb:
					step_cost += 50.0

			# Penalización de giro si cambia de dirección respecto a curr_dir
			var turn_cost: float = 0.0
			if curr_dir != Vector2i.ZERO and d != curr_dir:
				turn_cost = turn_penalty

			var tentative_g: float = curr_g + step_cost + turn_cost
			var next_key := "%d,%d,%d,%d" % [next_pos.x, next_pos.y, d.x, d.y]

			if tentative_g < g_score.get(next_key, INF):
				g_score[next_key] = tentative_g
				came_from[next_key] = curr_key
				var h: float = _heuristic_turn_aware(next_pos, d, goal_pos, turn_penalty)
				open_set.append({
					"pos": next_pos,
					"dir": d,
					"g": tentative_g,
					"f": tentative_g + h,
					"key": next_key
				})

	if best_goal_state.is_empty():
		return {"success": false, "centerline": [] as Array[Vector2i]}

	# Reconstruir camino hacia atrás
	var path_reversed: Array[Vector2i] = []
	var curr_trace: String = best_goal_state

	while came_from.has(curr_trace):
		var parts := curr_trace.split(",")
		path_reversed.append(Vector2i(int(parts[0]), int(parts[1])))
		curr_trace = came_from[curr_trace]

	# Añadir punto inicial
	var start_parts := curr_trace.split(",")
	path_reversed.append(Vector2i(int(start_parts[0]), int(start_parts[1])))
	path_reversed.reverse()

	return {
		"success": true,
		"centerline": path_reversed
	}

static func _heuristic_turn_aware(pos: Vector2i, dir: Vector2i, goal: Vector2i, turn_penalty: float) -> float:
	var manhattan: float = float(absi(goal.x - pos.x) + absi(goal.y - pos.y))
	var extra_turns: float = 0.0

	if pos.x != goal.x and pos.y != goal.y:
		extra_turns = turn_penalty
	elif (pos.x != goal.x and dir.y != 0) or (pos.y != goal.y and dir.x != 0):
		extra_turns = turn_penalty

	return manhattan + extra_turns

static func _find_classic_astar_path(
	astar: AStar2D,
	rooms: Array[RoomData],
	req: CorridorRequest,
	config: DungeonConfig,
	grid_width: int
) -> Array[Vector2i]:
	var start_id: int = _get_cell_id(req.start, grid_width)
	var goal_id: int = _get_cell_id(req.goal, grid_width)

	var modified_nodes: Dictionary = {}
	_apply_room_isolation_weights(astar, rooms, req.room_a_id, req.room_b_id, config, grid_width, modified_nodes)

	var orig_start: float = astar.get_point_weight_scale(start_id)
	var orig_goal: float = astar.get_point_weight_scale(goal_id)
	astar.set_point_weight_scale(start_id, 1.0)
	astar.set_point_weight_scale(goal_id, 1.0)

	var point_path: PackedVector2Array = astar.get_point_path(start_id, goal_id)

	astar.set_point_weight_scale(start_id, orig_start)
	astar.set_point_weight_scale(goal_id, orig_goal)
	_restore_modified_weights(astar, modified_nodes)

	var res: Array[Vector2i] = []
	for p in point_path:
		res.append(Vector2i(int(p.x), int(p.y)))
	return res

static func _validate_centerline(
	path: Array[Vector2i],
	expected_start: Vector2i,
	expected_goal: Vector2i,
	grid: CellGrid,
	rooms: Array[RoomData],
	room_a_id: int,
	room_b_id: int
) -> String:
	if path.is_empty():
		return "EMPTY_PATH"

	if path[0] != expected_start:
		return "START_MISMATCH"

	if path[path.size() - 1] != expected_goal:
		return "GOAL_MISMATCH"

	for i in range(path.size()):
		var p: Vector2i = path[i]

		if not grid.is_in_bounds(p):
			return "CELL_OUT_OF_BOUNDS"

		var t: CellGrid.CellType = grid.get_cell(p)
		if t == CellGrid.CellType.COLUMN or t == CellGrid.CellType.OBSTACLE or t == CellGrid.CellType.VOID:
			return "BLOCKED_CELL"

		# Comprobar continuidad cardinal estricta
		if i > 0:
			var prev: Vector2i = path[i - 1]
			var manhattan: int = absi(p.x - prev.x) + absi(p.y - prev.y)
			if manhattan != 1:
				return "NON_CARDINAL_STEP"

		# Comprobar que no atraviese el interior ni el perímetro prohibido de ninguna habitación ajena
		if p != expected_start and p != expected_goal:
			var owner_id: int = grid.get_room_owner(p)
			if owner_id == -1:
				owner_id = _get_room_id_at(p, rooms)
			if owner_id != -1 and owner_id != room_a_id and owner_id != room_b_id:
				return "FORBIDDEN_ROOM"

			# Comprobar que no penetre en el perímetro prohibido (distancia 1) de salas ajenas
			if grid.get_cell(p) != CellGrid.CellType.CORRIDOR:
				for r in rooms:
					if r != null and r.id != room_a_id and r.id != room_b_id and r.rect.grow(1).has_point(p):
						return "FORBIDDEN_ROOM_BUFFER"

	return ""

static func _compute_widened_corridor_cells(
	centerline: Array[Vector2i],
	boundary_cells: Array[Vector2i],
	c_width: int,
	bottleneck_dist: int,
	grid: CellGrid,
	rooms: Array[RoomData],
	room_a_id: int,
	room_b_id: int
) -> Array[Vector2i]:
	var candidate_carved_cells: Array[Vector2i] = []
	var seen_cells: Dictionary = {}

	# 1. Incluir los umbrales de frontera (boundary cells)
	for bc in boundary_cells:
		if grid.is_in_bounds(bc) and not seen_cells.has(bc):
			candidate_carved_cells.append(bc)
			seen_cells[bc] = true

	# 2. Incluir todo el centerline
	for p in centerline:
		if not seen_cells.has(p):
			candidate_carved_cells.append(p)
			seen_cells[p] = true

	if c_width <= 1 or centerline.size() < 2:
		return candidate_carved_cells

	# 3. Ensanchamiento estructurado por segmentos
	var start_idx: int = bottleneck_dist
	var end_idx: int = centerline.size() - 1 - bottleneck_dist

	for i in range(start_idx, end_idx + 1):
		if i < 0 or i >= centerline.size():
			continue

		var curr: Vector2i = centerline[i]

		# Determinar direcciones entrante y saliente
		var dir_in: Vector2i = curr - centerline[i - 1] if i > 0 else (centerline[1] - curr)
		var dir_out: Vector2i = centerline[i + 1] - curr if i < centerline.size() - 1 else dir_in

		var perp_in := Vector2i(-dir_in.y, dir_in.x)
		var perp_out := Vector2i(-dir_out.y, dir_out.x)

		# Segmento recto
		if dir_in == dir_out or perp_in == perp_out:
			for offset in range(1, c_width):
				var side_pt: Vector2i = curr + perp_in * offset
				if not seen_cells.has(side_pt) and _is_safe_widening_cell(side_pt, grid, rooms, room_a_id, room_b_id):
					candidate_carved_cells.append(side_pt)
					seen_cells[side_pt] = true
		else:
			# Esquina / giro 90°: Llenar el bloque 2x2/3x3 en la unión
			for o1 in range(0, c_width):
				for o2 in range(0, c_width):
					var corner_pt: Vector2i = curr + perp_in * o1 + perp_out * o2
					if not seen_cells.has(corner_pt) and _is_safe_widening_cell(corner_pt, grid, rooms, room_a_id, room_b_id):
						candidate_carved_cells.append(corner_pt)
						seen_cells[corner_pt] = true

	return candidate_carved_cells

static func _is_safe_widening_cell(
	pos: Vector2i,
	grid: CellGrid,
	rooms: Array[RoomData],
	_room_a_id: int,
	_room_b_id: int
) -> bool:
	if not grid.is_in_bounds(pos):
		return false

	var cell_type := grid.get_cell(pos)
	if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
		return false

	if cell_type == CellGrid.CellType.CORRIDOR:
		return true

	# No ensanchar dentro del perímetro prohibido de distancia 1 de ninguna habitación
	for r in rooms:
		if r != null and r.rect.grow(1).has_point(pos):
			return false

	return true

static func _get_room_id_at(pos: Vector2i, rooms: Array[RoomData]) -> int:
	for r in rooms:
		if r != null and r.rect.has_point(pos):
			return r.id
	return -1

static func _build_base_astar_graph(grid: CellGrid, config: DungeonConfig) -> AStar2D:
	var astar := AStar2D.new()
	var width: int = grid.width
	var height: int = grid.height

	var cost_corridor: float = config.corridor_cost_corridor if ("corridor_cost_corridor" in config) else 1.0
	var cost_wall: float = config.corridor_cost_wall if ("corridor_cost_wall" in config) else 15.0
	var cost_floor: float = config.corridor_cost_floor if ("corridor_cost_floor" in config) else 30.0

	# 1. Agregar nodos
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var id: int = _get_cell_id(pos, width)
			var ctype: int = grid.get_cell(pos)

			astar.add_point(id, Vector2(pos.x, pos.y))

			if ctype == CellGrid.CellType.VOID or ctype == CellGrid.CellType.COLUMN or ctype == CellGrid.CellType.OBSTACLE:
				astar.set_point_disabled(id, true)
			elif ctype == CellGrid.CellType.CORRIDOR:
				astar.set_point_weight_scale(id, cost_corridor)
			elif ctype == CellGrid.CellType.FLOOR or ctype == CellGrid.CellType.DOOR:
				astar.set_point_weight_scale(id, cost_floor)
			else:
				astar.set_point_weight_scale(id, cost_wall)

	# 2. Conectar vecinos cardinales (4 direcciones)
	for y in range(height):
		for x in range(width):
			var id: int = _get_cell_id(Vector2i(x, y), width)
			if x + 1 < width:
				astar.connect_points(id, _get_cell_id(Vector2i(x + 1, y), width))
			if y + 1 < height:
				astar.connect_points(id, _get_cell_id(Vector2i(x, y + 1), width))

	return astar

static func _apply_room_isolation_weights(
	astar: AStar2D,
	rooms: Array[RoomData],
	room_a_id: int,
	room_b_id: int,
	_config: DungeonConfig,
	grid_width: int,
	modified_nodes: Dictionary
) -> void:
	for r in rooms:
		if r == null or r.id == room_a_id or r.id == room_b_id:
			continue

		var grown: Rect2i = r.rect.grow(1)
		for y in range(grown.position.y, grown.end.y):
			for x in range(grown.position.x, grown.end.x):
				var cid: int = _get_cell_id(Vector2i(x, y), grid_width)
				if astar.has_point(cid):
					if not modified_nodes.has(cid):
						modified_nodes[cid] = astar.is_point_disabled(cid)
					astar.set_point_disabled(cid, true)

static func _restore_modified_weights(astar: AStar2D, modified_nodes: Dictionary) -> void:
	for cid in modified_nodes.keys():
		if astar.has_point(cid):
			astar.set_point_disabled(cid, modified_nodes[cid])
	modified_nodes.clear()

static func _get_cell_id(pos: Vector2i, grid_width: int) -> int:
	return pos.y * grid_width + pos.x

static func _connect_inner_to_room_floor(grid: CellGrid, room: RoomData, inner_pos: Vector2i, journal: RefCounted = null) -> void:
	if room == null or grid == null or not grid.is_in_bounds(inner_pos):
		return
	if not room.rect.has_point(inner_pos):
		return

	if grid.get_cell(inner_pos) != CellGrid.CellType.CORRIDOR:
		if journal != null and journal.has_method("record_cell"):
			journal.record_cell(grid, inner_pos)
		grid.set_cell(inner_pos, CellGrid.CellType.FLOOR)

	# Obtener la componente de suelo principal del interior de la habitación
	var main_floor_cells := _get_room_main_floor_cells(grid, room)
	if main_floor_cells.has(inner_pos) or main_floor_cells.is_empty():
		return # Ya está conectado a la componente principal de la sala

	# Buscar la celda de la componente principal más cercana a inner_pos
	var target_floor := Vector2i.ZERO
	var min_dist: int = 999999
	for p: Vector2i in main_floor_cells.keys():
		var d: int = absi(p.x - inner_pos.x) + absi(p.y - inner_pos.y)
		if d < min_dist:
			min_dist = d
			target_floor = p

	if min_dist < 999999:
		var path := _find_local_path_in_room(grid, room.rect, inner_pos, target_floor)
		for pt in path:
			if grid.is_in_bounds(pt) and not grid.is_walkable(pt):
				if journal != null and journal.has_method("record_cell"):
					journal.record_cell(grid, pt)
				grid.set_cell(pt, CellGrid.CellType.FLOOR)

static func _get_room_main_floor_cells(grid: CellGrid, room: RoomData) -> Dictionary:
	var result: Dictionary = {}
	var center := room.get_center()
	var start_seed := center

	if not grid.is_walkable(start_seed):
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				var p := Vector2i(x, y)
				if grid.get_cell(p) == CellGrid.CellType.FLOOR:
					start_seed = p
					break
			if start_seed != center:
				break

	if not grid.is_walkable(start_seed):
		return result

	var queue: Array[Vector2i] = [start_seed]
	result[start_seed] = true

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_back()
		var n4 := [
			curr + Vector2i(1, 0),
			curr + Vector2i(-1, 0),
			curr + Vector2i(0, 1),
			curr + Vector2i(0, -1)
		]
		for n in n4:
			if room.rect.has_point(n) and not result.has(n):
				var t := grid.get_cell(n)
				if t == CellGrid.CellType.FLOOR or t == CellGrid.CellType.SPAWN or t == CellGrid.CellType.OBJECTIVE:
					result[n] = true
					queue.append(n)

	return result

static func _find_local_path_in_room(
	grid: CellGrid,
	rect: Rect2i,
	start_pos: Vector2i,
	goal_pos: Vector2i
) -> Array[Vector2i]:
	if start_pos == goal_pos:
		return [start_pos]

	var astar := AStar2D.new()
	var width: int = rect.size.x
	var height: int = rect.size.y

	for dy in range(height):
		for dx in range(width):
			var pos := Vector2i(rect.position.x + dx, rect.position.y + dy)
			var id: int = dy * width + dx
			astar.add_point(id, Vector2(pos.x, pos.y))

			var cell_type := grid.get_cell(pos)
			if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
				astar.set_point_disabled(id, true)
			elif grid.is_walkable(pos):
				astar.set_point_weight_scale(id, 1.0)
			else:
				astar.set_point_weight_scale(id, 5.0)

	for dy in range(height):
		for dx in range(width):
			var id: int = dy * width + dx
			if dx + 1 < width:
				var right_id: int = dy * width + (dx + 1)
				astar.connect_points(id, right_id)
			if dy + 1 < height:
				var down_id: int = (dy + 1) * width + dx
				astar.connect_points(id, down_id)

	var start_id: int = (start_pos.y - rect.position.y) * width + (start_pos.x - rect.position.x)
	var goal_id: int = (goal_pos.y - rect.position.y) * width + (goal_pos.x - rect.position.x)

	if not astar.has_point(start_id) or not astar.has_point(goal_id):
		return []

	var point_path: PackedVector2Array = astar.get_point_path(start_id, goal_id)
	var result: Array[Vector2i] = []
	for p in point_path:
		result.append(Vector2i(int(p.x), int(p.y)))

	return result
