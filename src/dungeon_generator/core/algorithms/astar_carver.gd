class_name AStarCarver
extends RefCounted

## Tallador determinista de corredores mediante AStar2D (Fase 5).
## Implementa el flujo estricto Find -> Validate -> Commit sin fallbacks destructivos.
## Respeta las entradas de Fase 4, penaliza salas ajenas, evita obstáculos y promueve la reutilización.

const _CorridorRequestScript = preload("res://src/dungeon_generator/core/data/corridor_request.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _CorridorCarveResultScript = preload("res://src/dungeon_generator/core/data/corridor_carve_result.gd")
const _RoomConnectionScript = preload("res://src/dungeon_generator/core/data/room_connection.gd")
const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")

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
		carve_corridors(grid, rooms, ent_res.entrance_pairs, config)

## Ejecuta el tallado para todos los pares de entrada proporcionados por Fase 4.
static func carve_corridors(
	grid: CellGrid,
	rooms: Array[RoomData],
	entrance_pairs: Array,
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

	# 1. Crear el grafo base AStar2D con topología y pesos deterministas
	var astar := _build_base_astar_graph(grid, cfg)

	# 2. Convertir EntrancePairs a CorridorRequests y ordenar por prioridad
	var requests: Array[CorridorRequest] = []
	for pair in entrance_pairs:
		if pair != null and pair.entrance_a != null and pair.entrance_b != null:
			var is_req: bool = true
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

	var start_id: int = _get_cell_id(start_pos, grid_width)
	var goal_id: int = _get_cell_id(goal_pos, grid_width)

	# 1. Configurar pesos específicos de esta conexión (aislar salas ajenas)
	var modified_nodes: Dictionary = {}
	_apply_room_isolation_weights(astar, rooms, req.room_a_id, req.room_b_id, config, grid_width, modified_nodes)

	# Habilitar coste preferencial en start y goal
	var orig_start_weight: float = astar.get_point_weight_scale(start_id)
	var orig_goal_weight: float = astar.get_point_weight_scale(goal_id)
	astar.set_point_weight_scale(start_id, 1.0)
	astar.set_point_weight_scale(goal_id, 1.0)

	# --- PASO 1: FIND (Búsqueda A*) ---
	var point_path: PackedVector2Array = astar.get_point_path(start_id, goal_id)

	# Restaurar pesos temporales de start, goal y salas ajenas
	astar.set_point_weight_scale(start_id, orig_start_weight)
	astar.set_point_weight_scale(goal_id, orig_goal_weight)
	_restore_modified_weights(astar, modified_nodes)

	if point_path.is_empty():
		return {"success": false, "reason": "NO_PATH"}

	var centerline: Array[Vector2i] = []
	for p_vec in point_path:
		centerline.append(Vector2i(int(p_vec.x), int(p_vec.y)))

	# --- PASO 2: VALIDATE (Validación del camino central) ---
	var val_error: String = _validate_centerline(centerline, start_pos, goal_pos, grid, rooms, req.room_a_id, req.room_b_id)
	if not val_error.is_empty():
		return {"success": false, "reason": val_error}

	# --- PASO 3: WIDEN (Cálculo y validación de la región ensanchada) ---
	var c_width: int = config.corridor_width if ("corridor_width" in config) else 2
	var bottleneck_dist: int = config.corridor_bottleneck_distance if ("corridor_bottleneck_distance" in config) else 1

	var candidate_carved_cells: Array[Vector2i] = []
	var seen_cells: Dictionary = {}

	# Incluir los umbrales de frontera (boundary cells) y los outer cells
	var boundary_cells := [req.start_boundary, req.goal_boundary]
	for bc in boundary_cells:
		if grid.is_in_bounds(bc) and not seen_cells.has(bc):
			candidate_carved_cells.append(bc)
			seen_cells[bc] = true

	for p in centerline:
		if not seen_cells.has(p):
			candidate_carved_cells.append(p)
			seen_cells[p] = true

	# Ensanchamiento lateral si width >= 2
	if c_width >= 2 and centerline.size() >= 2:
		for i in range(centerline.size() - 1):
			# Preservar el cuello de botella de 1 celda cerca de las entradas
			if i < bottleneck_dist or i >= centerline.size() - 1 - bottleneck_dist:
				continue

			var curr: Vector2i = centerline[i]
			var next: Vector2i = centerline[i + 1]
			var dir: Vector2i = next - curr
			var perp := Vector2i(-dir.y, dir.x)
			if perp == Vector2i.ZERO:
				continue

			for offset in range(1, c_width):
				var side_pt: Vector2i = curr + perp * offset
				if not seen_cells.has(side_pt):
					# Validar que el punto lateral sea seguro para tallar
					if _is_safe_widening_cell(side_pt, grid, rooms, req.room_a_id, req.room_b_id):
						candidate_carved_cells.append(side_pt)
						seen_cells[side_pt] = true

	# Validar que toda la región a tallar no viole restricciones
	for cell in candidate_carved_cells:
		if not grid.is_in_bounds(cell):
			return {"success": false, "reason": "WIDENING_OUT_OF_BOUNDS"}
		var cell_type := grid.get_cell(cell)
		if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
			return {"success": false, "reason": "BLOCKED_CELL_IN_REGION"}

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
			# Actualizar el peso dinámico en AStar para futuras conexiones
			var cid: int = _get_cell_id(cell, grid_width)
			var w_corridor: float = config.corridor_cost_corridor if ("corridor_cost_corridor" in config) else 1.0
			astar.set_point_weight_scale(cid, w_corridor)

		total_cost += 1.0

	# Asegurar que los interiores de entrada (inner_cell) sean transitable FLOOR si fueron afectados por CA
	var room_a: RoomData = room_map.get(req.room_a_id, null)
	var room_b: RoomData = room_map.get(req.room_b_id, null)

	var inner_a: Vector2i = req.start_boundary - req.start_direction
	var inner_b: Vector2i = req.goal_boundary - req.goal_direction
	if grid.is_in_bounds(inner_a) and grid.get_cell(inner_a) != CellGrid.CellType.CORRIDOR:
		grid.set_cell(inner_a, CellGrid.CellType.FLOOR)
	if grid.is_in_bounds(inner_b) and grid.get_cell(inner_b) != CellGrid.CellType.CORRIDOR:
		grid.set_cell(inner_b, CellGrid.CellType.FLOOR)

	# Registrar conexiones en los RoomData correspondientes
	if room_a != null:
		if not room_a.connections.has(req.start_boundary):
			room_a.connections.append(req.start_boundary)
		if not room_a.connected_room_ids.has(req.room_b_id):
			room_a.connected_room_ids.append(req.room_b_id)

	if room_b != null:
		if not room_b.connections.has(req.goal_boundary):
			room_b.connections.append(req.goal_boundary)
		if not room_b.connected_room_ids.has(req.room_a_id):
			room_b.connected_room_ids.append(req.room_a_id)

	var path = _CorridorPathScript.new(
		req.connection_id,
		req.room_a_id,
		req.room_b_id,
		centerline,
		candidate_carved_cells,
		total_cost,
		reused_count
	)

	return {
		"success": true,
		"path": path
	}

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

		# Comprobar que no atraviese el interior de una habitación prohibida
		var owner_id: int = _get_room_id_at(p, rooms)
		if owner_id != -1 and owner_id != room_a_id and owner_id != room_b_id:
			return "FORBIDDEN_ROOM"

	return ""

static func _is_safe_widening_cell(
	pos: Vector2i,
	grid: CellGrid,
	rooms: Array[RoomData],
	room_a_id: int,
	room_b_id: int
) -> bool:
	if not grid.is_in_bounds(pos):
		return false

	var cell_type := grid.get_cell(pos)
	if cell_type == CellGrid.CellType.COLUMN or cell_type == CellGrid.CellType.OBSTACLE or cell_type == CellGrid.CellType.VOID:
		return false

	var owner_id: int = _get_room_id_at(pos, rooms)
	if owner_id != -1 and owner_id != room_a_id and owner_id != room_b_id:
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
	var cost_floor: float = config.corridor_cost_room_floor if ("corridor_cost_room_floor" in config) else 35.0

	# 1. Añadir puntos con pesos según el CellType
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var id: int = _get_cell_id(pos, width)
			astar.add_point(id, Vector2(x, y))

			var cell_type: CellGrid.CellType = grid.get_cell(pos)
			match cell_type:
				CellGrid.CellType.CORRIDOR:
					astar.set_point_weight_scale(id, cost_corridor)
				CellGrid.CellType.FLOOR, CellGrid.CellType.DOOR:
					astar.set_point_weight_scale(id, cost_floor)
				CellGrid.CellType.COLUMN, CellGrid.CellType.OBSTACLE, CellGrid.CellType.VOID:
					astar.set_point_weight_scale(id, 99999.0)
					astar.set_point_disabled(id, true)
				_:
					# WALL
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
	config: DungeonConfig,
	grid_width: int,
	modified_nodes: Dictionary
) -> void:
	var other_room_cost: float = config.corridor_cost_other_room if ("corridor_cost_other_room" in config) else 1000.0

	for r in rooms:
		if r == null or r.id == room_a_id or r.id == room_b_id:
			continue

		for y in range(r.rect.position.y, r.rect.end.y):
			for x in range(r.rect.position.x, r.rect.end.x):
				var cid: int = _get_cell_id(Vector2i(x, y), grid_width)
				if astar.has_point(cid):
					if not modified_nodes.has(cid):
						modified_nodes[cid] = astar.get_point_weight_scale(cid)
					astar.set_point_weight_scale(cid, other_room_cost)

static func _restore_modified_weights(astar: AStar2D, modified_nodes: Dictionary) -> void:
	for cid in modified_nodes.keys():
		if astar.has_point(cid):
			astar.set_point_weight_scale(cid, modified_nodes[cid])
	modified_nodes.clear()

static func _get_cell_id(pos: Vector2i, grid_width: int) -> int:
	return pos.y * grid_width + pos.x
