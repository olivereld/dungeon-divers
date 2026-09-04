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
const _OrthogonalPlannerScript = preload("res://src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd")

## Ejecuta el tallado para todas las peticiones CorridorRequest planificadas y vinculadas.
static func carve_corridors(
	grid: CellGrid,
	rooms: Array[RoomData],
	corridor_requests: Array,
	connections: Array = [],
	config: DungeonConfig = null
) -> CorridorCarveResult:
	var result = _CorridorCarveResultScript.new()

	if corridor_requests.is_empty() or rooms.size() < 2:
		result.is_valid = true
		return result

	var cfg := config
	if cfg == null:
		cfg = DungeonConfig.new()

	var width: int = grid.width
	var height: int = grid.height

	# 1. Grafo base AStar2D (construido lazy únicamente si se requiere fallback clásico)
	var astar: AStar2D = null

	# 2. Filtrar peticiones CorridorRequest y ordenar por prioridad
	var requests: Array[CorridorRequest] = []
	for item in corridor_requests:
		if item is _CorridorRequestScript:
			requests.append(item)

	# Ordenar peticiones: mandatory primero, luego por rol semántico (MAIN_PATH > SIDE_PATH > OPTIONAL), luego por distancia e ID
	requests.sort_custom(func(a: CorridorRequest, b: CorridorRequest):
		if a.is_required != b.is_required:
			return a.is_required
		var role_rank := func(r: StringName) -> int:
			match r:
				CorridorRequest.ROLE_MAIN_PATH:
					return 3
				CorridorRequest.ROLE_SIDE_PATH:
					return 2
				CorridorRequest.ROLE_OPTIONAL:
					return 1
				CorridorRequest.ROLE_SHORTCUT:
					# SHORTCUT and OPTIONAL are both non-critical auxiliary corridors.
					return 1
				_:
					return 0
		var r_a: int = role_rank.call(a.corridor_role)
		var r_b: int = role_rank.call(b.corridor_role)
		if r_a != r_b:
			return r_a > r_b
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

		var diag: Dictionary = {
			"connection_id": req.connection_id,
			"room_a_id": req.room_a_id,
			"room_b_id": req.room_b_id,
			"role": req.corridor_role,
			"routing_preference": req.routing_preference,
			"preferred_length": req.preferred_length,
			"actual_length": 0,
			"turn_count": 0,
			"strategy": res.get("strategy", "Unknown"),
			"expanded_states": res.get("expanded_states", 0),
			"elapsed_ms": res.get("elapsed_ms", 0.0),
			"termination_reason": res.get("termination_reason", res.get("reason", "UNKNOWN")),
			"repair_attempted": false,
			"repair_success": false
		}

		if res["success"]:
			var path: CorridorPath = res["path"]
			diag["actual_length"] = path.centerline_cells.size()
			diag["turn_count"] = path.turn_count
			diag["cost"] = path.cost
			diag["carved_cells"] = path.carved_cells.size()
			diag["reused_cells"] = path.reused_cells_count
			diag["status"] = "SUCCESS"
			result.add_path(path, diag)
		else:
			var reason: String = res.get("reason", "NO_PATH")
			diag["status"] = "FAILED" if req.is_required else "REJECTED"
			diag["reason"] = reason
			if req.is_required:
				result.add_failure(req.connection_id, reason, diag)
			else:
				result.add_rejection(req.connection_id, reason, diag)

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
		return {
			"success": false,
			"reason": "START_OUT_OF_BOUNDS",
			"expanded_states": 0,
			"elapsed_ms": 0.0,
			"termination_reason": "START_OUT_OF_BOUNDS",
			"strategy": "None"
		}
	if not grid.is_in_bounds(goal_pos):
		return {
			"success": false,
			"reason": "GOAL_OUT_OF_BOUNDS",
			"expanded_states": 0,
			"elapsed_ms": 0.0,
			"termination_reason": "GOAL_OUT_OF_BOUNDS",
			"strategy": "None"
		}

	var centerline: Array[Vector2i] = []
	var routing_strategy: String = "Unknown"
	var expanded_states: int = 0
	var elapsed_ms: float = 0.0
	var termination_reason: String = "NO_PATH"
	var failure_reason: String = "NO_PATH"

	# --- PASO 1: FIND (Jerarquía controlada por req.routing_preference) ---
	var try_orthogonal: bool = config.prefer_orthogonal_routes
	if req.routing_preference == CorridorRequest.ROUTING_AVOID_ROOMS:
		# En modo AVOID_ROOMS evitamos el planificador ortogonal rígido para priorizar A* con evasión de salas
		try_orthogonal = false

	if try_orthogonal:
		var ortho_res: Dictionary = _OrthogonalPlannerScript.plan_route(grid, rooms, req.room_a_id, req.room_b_id, start_pos, goal_pos, config)
		if ortho_res.get("success", false):
			centerline = ortho_res["centerline"]
			routing_strategy = ortho_res.get("strategy", "Orthogonal")
			termination_reason = "SUCCESS"
			failure_reason = "SUCCESS"

	# Fallback a A* direccional si el planificador ortogonal no encontró ruta o no está activado
	if centerline.is_empty() and config.allow_astar_fallback:
		var astar_res: Dictionary = _find_direction_aware_path(grid, rooms, room_map, req, config, grid_width, grid_height)
		expanded_states = astar_res.get("expanded_states", 0)
		elapsed_ms = astar_res.get("elapsed_ms", 0.0)
		termination_reason = astar_res.get("termination_reason", "NO_PATH")
		failure_reason = astar_res.get("reason", "NO_PATH")

		if astar_res.get("success", false):
			centerline = astar_res["centerline"]
			routing_strategy = "AStar_TurnAware"
		else:
			# NO SILENT CLASSIC FALLBACK: Failures surface explicitly as SEARCH_BUDGET_EXCEEDED or NO_PATH.
			return {
				"success": false,
				"reason": failure_reason,
				"expanded_states": expanded_states,
				"elapsed_ms": elapsed_ms,
				"termination_reason": termination_reason,
				"strategy": "AStar_TurnAware"
			}

	if centerline.is_empty():
		return {
			"success": false,
			"reason": failure_reason,
			"expanded_states": expanded_states,
			"elapsed_ms": elapsed_ms,
			"termination_reason": termination_reason,
			"strategy": routing_strategy
		}

	# --- PASO 2: VALIDATE (Validación del camino central) ---
	var val_error: String = _validate_centerline(centerline, start_pos, goal_pos, grid, rooms, req.room_a_id, req.room_b_id)
	if not val_error.is_empty():
		return {
			"success": false,
			"reason": val_error,
			"expanded_states": expanded_states,
			"elapsed_ms": elapsed_ms,
			"termination_reason": val_error,
			"strategy": routing_strategy
		}

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
			return {
				"success": false,
				"reason": "WIDENING_OUT_OF_BOUNDS",
				"expanded_states": expanded_states,
				"elapsed_ms": elapsed_ms,
				"termination_reason": "WIDENING_OUT_OF_BOUNDS",
				"strategy": routing_strategy
			}
		var cell_type := grid.get_cell(cell)
		if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
			return {
				"success": false,
				"reason": "BLOCKED_CELL_IN_REGION",
				"expanded_states": expanded_states,
				"elapsed_ms": elapsed_ms,
				"termination_reason": "BLOCKED_CELL_IN_REGION",
				"strategy": routing_strategy
			}
		if cell != req.start_boundary and cell != req.goal_boundary:
			var c_owner: int = grid.get_room_owner(cell)
			if c_owner == -1:
				c_owner = _get_room_id_at(cell, rooms)
			if c_owner != -1 and c_owner != req.room_a_id and c_owner != req.room_b_id:
				return {
					"success": false,
					"reason": "FORBIDDEN_ROOM_INVADED",
					"expanded_states": expanded_states,
					"elapsed_ms": elapsed_ms,
					"termination_reason": "FORBIDDEN_ROOM_INVADED",
					"strategy": routing_strategy
				}

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

	# Costo suave de longitud (Fase 5.5: preferred_length no rechaza, modula suavemente el coste)
	var length_weight: float = config.corridor_length_weight if ("corridor_length_weight" in config) else 0.5
	var actual_len: float = float(centerline.size())
	if req.preferred_length > 0.0:
		total_cost += absf(actual_len - req.preferred_length) * length_weight

	# Criterios de calidad suave para min_length / max_length (Fase 5.6)
	if req.max_length > 0 and actual_len > float(req.max_length):
		total_cost += (actual_len - float(req.max_length)) * (length_weight * 2.0)
	elif req.min_length > 0 and actual_len < float(req.min_length):
		total_cost += (float(req.min_length) - actual_len) * (length_weight * 2.0)

	# Asegurar que los interiores de entrada (inner_cell) sean transitable FLOOR y se conecten al interior de la sala
	var room_a: RoomData = room_map.get(req.room_a_id, null)
	var room_b: RoomData = room_map.get(req.room_b_id, null)

	var inner_a: Vector2i = req.start_inner if req.start_inner != Vector2i.ZERO else (req.start_boundary - req.start_direction)
	var inner_b: Vector2i = req.goal_inner if req.goal_inner != Vector2i.ZERO else (req.goal_boundary - req.goal_direction)
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
	path.expanded_states = expanded_states
	path.elapsed_ms = elapsed_ms
	path.termination_reason = "SUCCESS"

	return {
		"success": true,
		"path": path,
		"expanded_states": expanded_states,
		"elapsed_ms": elapsed_ms,
		"termination_reason": "SUCCESS",
		"strategy": routing_strategy
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

class _HeapNode extends RefCounted:
	var pos: Vector2i
	var dir: Vector2i
	var g: float
	var f: float
	var dev: float
	var key: int
	var steps: int

	func _init(p_pos: Vector2i, p_dir: Vector2i, p_g: float, p_f: float, p_dev: float, p_key: int, p_steps: int) -> void:
		pos = p_pos
		dir = p_dir
		g = p_g
		f = p_f
		dev = p_dev
		key = p_key
		steps = p_steps

class _SearchMinHeap extends RefCounted:
	var _data: Array[_HeapNode] = []
	var _pref_len: float = 0.0

	func _init(pref_len: float = 0.0) -> void:
		_pref_len = pref_len

	func is_empty() -> bool:
		return _data.is_empty()

	func size() -> int:
		return _data.size()

	func _is_higher_priority(a: _HeapNode, b: _HeapNode) -> bool:
		var diff: float = a.f - b.f
		if diff < -0.0001:
			return true
		if diff > 0.0001:
			return false
		if _pref_len > 0.0:
			var dev_diff: float = a.dev - b.dev
			if dev_diff < -0.0001:
				return true
			if dev_diff > 0.0001:
				return false
		if a.steps != b.steps:
			return a.steps < b.steps
		if a.pos.x != b.pos.x:
			return a.pos.x < b.pos.x
		if a.pos.y != b.pos.y:
			return a.pos.y < b.pos.y
		if a.dir.x != b.dir.x:
			return a.dir.x < b.dir.x
		return a.dir.y < b.dir.y

	func push(item: _HeapNode) -> void:
		_data.append(item)
		var i: int = _data.size() - 1
		while i > 0:
			var parent: int = (i - 1) >> 1
			if _is_higher_priority(_data[i], _data[parent]):
				var tmp: _HeapNode = _data[i]
				_data[i] = _data[parent]
				_data[parent] = tmp
				i = parent
			else:
				break

	func pop() -> _HeapNode:
		var top: _HeapNode = _data[0]
		var last: _HeapNode = _data.pop_back()
		if not _data.is_empty():
			_data[0] = last
			var i: int = 0
			var n: int = _data.size()
			while true:
				var left: int = (i << 1) + 1
				var right: int = left + 1
				var best: int = i
				if left < n and _is_higher_priority(_data[left], _data[best]):
					best = left
				if right < n and _is_higher_priority(_data[right], _data[best]):
					best = right
				if best != i:
					var tmp: _HeapNode = _data[i]
					_data[i] = _data[best]
					_data[best] = tmp
					i = best
				else:
					break
		return top

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

	# Modulación de costes según la preferencia de ruteo de la petición (Fase 5)
	match req.routing_preference:
		CorridorRequest.ROUTING_DIRECT:
			turn_penalty *= 1.6
		CorridorRequest.ROUTING_AVOID_ROOMS:
			other_room_cost *= 2.5
			cost_floor *= 2.0
		CorridorRequest.ROUTING_MANHATTAN:
			turn_penalty *= 1.2

	var directions: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	# Precalcular rectángulos de salas ajenas y sus buffers para evitar allocs en el bucle caliente
	var foreign_rects: Array[Rect2i] = []
	var foreign_grown_rects: Array[Rect2i] = []
	for r in rooms:
		if r != null and r.id != req.room_a_id and r.id != req.room_b_id:
			foreign_rects.append(r.rect)
			foreign_grown_rects.append(r.rect.grow(1))

	# Precalcular jambas protegidas de puertas de inicio y fin
	var jamb_cells: Dictionary = {}
	if req.start_direction.y != 0:
		jamb_cells[req.start_boundary + Vector2i(-1, 0)] = true
		jamb_cells[req.start_boundary + Vector2i(1, 0)] = true
	elif req.start_direction.x != 0:
		jamb_cells[req.start_boundary + Vector2i(0, -1)] = true
		jamb_cells[req.start_boundary + Vector2i(0, 1)] = true

	if req.goal_direction.y != 0:
		jamb_cells[req.goal_boundary + Vector2i(-1, 0)] = true
		jamb_cells[req.goal_boundary + Vector2i(1, 0)] = true
	elif req.goal_direction.x != 0:
		jamb_cells[req.goal_boundary + Vector2i(0, -1)] = true
		jamb_cells[req.goal_boundary + Vector2i(0, 1)] = true

	# Cola de prioridad binaria (MinHeap) ordenada por f_score y desempates lexicográficos
	var open_set := _SearchMinHeap.new(req.preferred_length)
	var g_score: Dictionary = {}
	var came_from: Dictionary = {}

	var start_dir := req.start_direction
	var start_dir_code: int = (start_dir.x + 1) * 3 + (start_dir.y + 1)
	var start_pos_id: int = start_pos.y * grid_width + start_pos.x
	var start_key: int = (start_pos_id << 8) | (start_dir_code << 4)
	g_score[start_key] = 0.0

	var h_start: float = _heuristic_turn_aware(start_pos, start_dir, goal_pos, turn_penalty)
	var est_start_len: float = float(absi(goal_pos.x - start_pos.x) + absi(goal_pos.y - start_pos.y))
	var start_dev: float = absf(est_start_len - req.preferred_length) if req.preferred_length > 0.0 else 0.0

	open_set.push(_HeapNode.new(start_pos, start_dir, 0.0, h_start, start_dev, start_key, 0))

	var max_states: int = config.corridor_max_search_states if ("corridor_max_search_states" in config) else 12000
	var max_ms: float = config.corridor_max_search_ms if ("corridor_max_search_ms" in config) else 250.0
	var t_start: int = Time.get_ticks_msec()
	var expanded_states: int = 0
	var termination_reason: String = "NO_PATH"

	var best_goal_state: int = -1
	var min_goal_cost: float = INF

	while not open_set.is_empty():
		expanded_states += 1

		# Límites estrictos de presupuesto de búsqueda
		if expanded_states > max_states:
			termination_reason = "SEARCH_BUDGET_EXCEEDED"
			break
		if (expanded_states & 63) == 0:
			var elapsed_ms: float = float(Time.get_ticks_msec() - t_start)
			if elapsed_ms >= max_ms:
				termination_reason = "SEARCH_BUDGET_EXCEEDED"
				break

		var current: _HeapNode = open_set.pop()

		var curr_pos: Vector2i = current.pos
		var curr_dir: Vector2i = current.dir
		var curr_key: int = current.key
		var curr_g: float = current.g
		var curr_steps: int = current.steps

		if curr_g > g_score.get(curr_key, INF):
			continue

		if curr_pos == goal_pos:
			if curr_g < min_goal_cost:
				min_goal_cost = curr_g
				best_goal_state = curr_key
				termination_reason = "SUCCESS"
				break

		# Explorar vecinos cardinales
		var b_dist: int = config.corridor_bottleneck_distance if ("corridor_bottleneck_distance" in config) else 1
		for d in directions:
			var next_pos: Vector2i = curr_pos + d

			if not grid.is_in_bounds(next_pos):
				continue

			# Widen-aware validation en tiempo de búsqueda
			var is_endpoint: bool = (next_pos == goal_pos or next_pos == start_pos)
			var dist_start: int = absi(next_pos.x - start_pos.x) + absi(next_pos.y - start_pos.y)
			var dist_goal: int = absi(goal_pos.x - next_pos.x) + absi(goal_pos.y - next_pos.y)
			var eff_w: int = 1 if (is_endpoint or dist_start <= b_dist or dist_goal <= b_dist) else config.corridor_width

			if not _is_corridor_footprint_valid(grid, next_pos, d, eff_w, room_map, req.room_a_id, req.room_b_id, foreign_rects, foreign_grown_rects):
				continue

			var ctype: int = grid.get_cell(next_pos)

			# Coste de terreno
			var step_cost: float = cost_wall
			if ctype == CellGrid.CellType.CORRIDOR:
				step_cost = cost_corridor
			elif ctype == CellGrid.CellType.FLOOR or ctype == CellGrid.CellType.DOOR:
				step_cost = cost_floor

			# Proteger jambas laterales de las puertas del inicio y final de la conexión
			if jamb_cells.has(next_pos):
				step_cost += 50.0

			# Penalización de giro si cambia de dirección respecto a curr_dir
			var turn_cost: float = 0.0
			if curr_dir != Vector2i.ZERO and d != curr_dir:
				turn_cost = turn_penalty

			var tentative_g: float = curr_g + step_cost + turn_cost
			var next_steps: int = curr_steps + 1
			# Control de espacio de estados: bucket acotado de longitud
			var bucket: int = clampi(int(next_steps / 4), 0, 8) if req.preferred_length > 0.0 else 0
			var next_dir_code: int = (d.x + 1) * 3 + (d.y + 1)
			var next_pos_id: int = next_pos.y * grid_width + next_pos.x
			var next_key: int = (next_pos_id << 8) | (next_dir_code << 4) | bucket

			if tentative_g < g_score.get(next_key, INF):
				g_score[next_key] = tentative_g
				came_from[next_key] = curr_key
				var h: float = _heuristic_turn_aware(next_pos, d, goal_pos, turn_penalty)
				var dev: float = 0.0
				var len_bias: float = 0.0
				var est_total_len: float = float(next_steps) + float(absi(goal_pos.x - next_pos.x) + absi(goal_pos.y - next_pos.y))
				if req.preferred_length > 0.0:
					dev = absf(est_total_len - req.preferred_length)
					len_bias += dev * 1.5
				if req.max_length > 0 and est_total_len > float(req.max_length):
					len_bias += (est_total_len - float(req.max_length)) * 1.5
				elif req.min_length > 0 and est_total_len < float(req.min_length):
					len_bias += (float(req.min_length) - est_total_len) * 1.5

				open_set.push(_HeapNode.new(next_pos, d, tentative_g, tentative_g + h + len_bias, dev, next_key, next_steps))

	var total_elapsed_ms: float = float(Time.get_ticks_msec() - t_start)
	if best_goal_state == -1:
		return {
			"success": false,
			"centerline": [] as Array[Vector2i],
			"expanded_states": expanded_states,
			"elapsed_ms": total_elapsed_ms,
			"termination_reason": termination_reason,
			"reason": termination_reason
		}

	# Reconstruir camino hacia atrás
	var path_reversed: Array[Vector2i] = []
	var curr_trace: int = best_goal_state

	while came_from.has(curr_trace):
		var pos_id: int = curr_trace >> 8
		path_reversed.append(Vector2i(pos_id % grid_width, pos_id / grid_width))
		curr_trace = came_from[curr_trace]

	# Añadir punto inicial
	var final_pos_id: int = curr_trace >> 8
	path_reversed.append(Vector2i(final_pos_id % grid_width, final_pos_id / grid_width))
	path_reversed.reverse()

	return {
		"success": true,
		"centerline": path_reversed,
		"expanded_states": expanded_states,
		"elapsed_ms": total_elapsed_ms,
		"termination_reason": "SUCCESS",
		"reason": "SUCCESS"
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

## Verifica si una celda y su huella lateral según corridor_width y direction son válidas para el corredor.
static func _is_corridor_footprint_valid(
	grid: CellGrid,
	center_cell: Vector2i,
	direction: Vector2i,
	corridor_width: int,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	foreign_rects: Array[Rect2i] = [],
	foreign_grown_rects: Array[Rect2i] = []
) -> bool:
	if not grid.is_in_bounds(center_cell):
		return false

	var ctype: int = grid.get_cell(center_cell)
	if ctype == CellGrid.CellType.VOID or ctype == CellGrid.CellType.COLUMN or ctype == CellGrid.CellType.OBSTACLE:
		return false

	var center_owner: int = grid.get_room_owner(center_cell)
	if center_owner != -1 and center_owner != room_a_id and center_owner != room_b_id:
		return false

	if not foreign_rects.is_empty():
		if center_owner == -1:
			for fr in foreign_rects:
				if fr.has_point(center_cell):
					return false
		if ctype != CellGrid.CellType.CORRIDOR:
			for fgr in foreign_grown_rects:
				if fgr.has_point(center_cell):
					return false
	else:
		var rooms_list: Array = room_map.values()
		if center_owner == -1:
			center_owner = _get_room_id_at(center_cell, rooms_list)
		if center_owner != -1 and center_owner != room_a_id and center_owner != room_b_id:
			return false
		if ctype != CellGrid.CellType.CORRIDOR:
			for r in rooms_list:
				if r != null and r.id != room_a_id and r.id != room_b_id and r.rect.grow(1).has_point(center_cell):
					return false

	if corridor_width <= 1 or direction == Vector2i.ZERO:
		return true

	# Validar desplazamiento lateral según ancho del corredor
	var perp := Vector2i(-direction.y, direction.x)
	for offset in range(1, corridor_width):
		var side_cell: Vector2i = center_cell + perp * offset
		if not grid.is_in_bounds(side_cell):
			return false
		var side_type: int = grid.get_cell(side_cell)
		if side_type == CellGrid.CellType.VOID or side_type == CellGrid.CellType.COLUMN or side_type == CellGrid.CellType.OBSTACLE:
			return false
		var side_owner: int = grid.get_room_owner(side_cell)
		if side_owner != -1 and side_owner != room_a_id and side_owner != room_b_id:
			return false

		if not foreign_rects.is_empty():
			if side_owner == -1:
				for fr in foreign_rects:
					if fr.has_point(side_cell):
						return false
			if side_type != CellGrid.CellType.CORRIDOR:
				for fgr in foreign_grown_rects:
					if fgr.has_point(side_cell):
						return false
		else:
			var rooms_list: Array = room_map.values()
			if side_owner == -1:
				side_owner = _get_room_id_at(side_cell, rooms_list)
			if side_owner != -1 and side_owner != room_a_id and side_owner != room_b_id:
				return false
			if side_type != CellGrid.CellType.CORRIDOR:
				for r in rooms_list:
					if r != null and r.id != room_a_id and r.id != room_b_id and r.rect.grow(1).has_point(side_cell):
						return false

	return true

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

static func _get_room_id_at(pos: Vector2i, rooms: Array) -> int:
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
