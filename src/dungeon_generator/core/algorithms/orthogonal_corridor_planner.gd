class_name OrthogonalCorridorPlanner
extends RefCounted

## Planificador analítico de corredores ortogonales de alta calidad arquitectónica (Fase Refined).
## Genera rutas puramente ortogonales evaluando en orden estricto de preferencia:
## - Nivel 0: Línea recta (0 giros)
## - Nivel 1: L limpia (H->V o V->H, 1 giro)
## - Nivel 2: Multi-giro ortogonal (2–3 giros: Z-routes y U-routes)
##
## Aplica validación estricta de límites, columnas, obstáculos sólidos y salas ajenas antes de aceptar cualquier ruta.

static func plan_route(
	grid: CellGrid,
	rooms: Array,
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i,
	config: DungeonConfig = null
) -> Dictionary:
	var cfg := config
	if cfg == null:
		cfg = DungeonConfig.new()

	var room_map: Dictionary = {}
	for r in rooms:
		if r != null and "id" in r:
			room_map[r.id] = r

	# Nivel 0: Línea recta (colineal en X o Y)
	if start.y == goal.y or start.x == goal.x:
		var straight_path: Array[Vector2i] = _try_straight(grid, room_map, room_a_id, room_b_id, start, goal)
		if not straight_path.is_empty():
			return {
				"success": true,
				"centerline": straight_path,
				"strategy": "Straight",
				"turns": 0
			}

	# Nivel 1: Forma en L (1 giro: H->V o V->H)
	if start.x != goal.x and start.y != goal.y:
		var l_res: Dictionary = _try_l_routes(grid, room_map, room_a_id, room_b_id, start, goal)
		if l_res.get("success", false):
			return l_res

	# Nivel 2: Multi-giro ortogonal (Z-routes y U-routes de 2 a 3 giros)
	if cfg.corridor_max_preferred_turns >= 2:
		var multi_res: Dictionary = _try_multi_turn_routes(grid, room_map, room_a_id, room_b_id, start, goal, cfg)
		if multi_res.get("success", false):
			return multi_res

	return {
		"success": false,
		"centerline": [] as Array[Vector2i],
		"strategy": "None",
		"turns": -1
	}

## Verifica si una celda individual es válida para ser parte del trazado de un corredor.
static func is_cell_valid_for_corridor(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	cell: Vector2i
) -> bool:
	if not grid.is_in_bounds(cell):
		return false

	var ctype: int = grid.get_cell(cell)
	# Rechazar vacío, columnas sólidas y obstáculos
	if ctype == CellGrid.CellType.VOID or ctype == CellGrid.CellType.COLUMN or ctype == CellGrid.CellType.OBSTACLE:
		return false

	# Rechazar penetración en el interior de CUALQUIER sala
	var owner: int = grid.get_room_owner(cell)
	if owner != -1:
		return false

	for rid in room_map:
		var r = room_map[rid]
		if r != null and "rect" in r:
			if r.rect.has_point(cell):
				return false

	return true

## Construye una línea cardinal recta paso a paso entre dos puntos colineales.
static func _build_straight_segment(p1: Vector2i, p2: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	var dx: int = clampi(p2.x - p1.x, -1, 1)
	var dy: int = clampi(p2.y - p1.y, -1, 1)
	var curr: Vector2i = p1

	while true:
		line.append(curr)
		if curr == p2:
			break
		curr += Vector2i(dx, dy)

	return line

## Une múltiples waypoints en una ruta continua ortogonal asegurando no duplicar vértices intermedios.
static func _combine_waypoints(waypoints: Array[Vector2i]) -> Array[Vector2i]:
	if waypoints.is_empty():
		return []
	var full_path: Array[Vector2i] = []
	for i in range(waypoints.size() - 1):
		var seg: Array[Vector2i] = _build_straight_segment(waypoints[i], waypoints[i + 1])
		var start_idx: int = 1 if i > 0 else 0
		for j in range(start_idx, seg.size()):
			full_path.append(seg[j])
	return full_path

## Valida si una ruta completa es transitable celda a celda.
static func _is_path_valid(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	path: Array[Vector2i]
) -> bool:
	if path.is_empty():
		return false
	for cell in path:
		if not is_cell_valid_for_corridor(grid, room_map, room_a_id, room_b_id, cell):
			return false
	return true

## Intenta generar y validar una línea recta directa.
static func _try_straight(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i
) -> Array[Vector2i]:
	var line: Array[Vector2i] = _build_straight_segment(start, goal)
	for cell in line:
		if not is_cell_valid_for_corridor(grid, room_map, room_a_id, room_b_id, cell):
			return []
	return line

## Evalúa ambas variantes de L (Horizontal primero o Vertical primero) y selecciona la mejor.
static func _try_l_routes(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i
) -> Dictionary:
	# Opción A: H -> V (Esquina en goal.x, start.y)
	var corner_hv: Vector2i = Vector2i(goal.x, start.y)
	var path_hv: Array[Vector2i] = _combine_waypoints([start, corner_hv, goal])
	var valid_hv: bool = _is_path_valid(grid, room_map, room_a_id, room_b_id, path_hv)

	# Opción B: V -> H (Esquina en start.x, goal.y)
	var corner_vh: Vector2i = Vector2i(start.x, goal.y)
	var path_vh: Array[Vector2i] = _combine_waypoints([start, corner_vh, goal])
	var valid_vh: bool = _is_path_valid(grid, room_map, room_a_id, room_b_id, path_vh)

	if valid_hv and not valid_vh:
		return {
			"success": true,
			"centerline": path_hv,
			"strategy": "L_HV",
			"turns": 1
		}
	if valid_vh and not valid_hv:
		return {
			"success": true,
			"centerline": path_vh,
			"strategy": "L_VH",
			"turns": 1
		}
	if valid_hv and valid_vh:
		# Si ambas son válidas geométricamente, preferir la que reutilice más corredor existente
		var reused_hv: int = 0
		var reused_vh: int = 0
		for c in path_hv:
			if grid.get_cell(c) == CellGrid.CellType.CORRIDOR:
				reused_hv += 1
		for c in path_vh:
			if grid.get_cell(c) == CellGrid.CellType.CORRIDOR:
				reused_vh += 1

		if reused_vh > reused_hv:
			return {
				"success": true,
				"centerline": path_vh,
				"strategy": "L_VH",
				"turns": 1
			}
		return {
			"success": true,
			"centerline": path_hv,
			"strategy": "L_HV",
			"turns": 1
		}

	return {
		"success": false,
		"centerline": [] as Array[Vector2i],
		"strategy": "None",
		"turns": -1
	}

## Evalúa rutas multi-giro deterministas (2–3 giros) como Z-routes (H-V-H / V-H-V) y U-routes (rodeos).
static func _try_multi_turn_routes(
	grid: CellGrid,
	room_map: Dictionary,
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i,
	config: DungeonConfig
) -> Dictionary:
	var best_path: Array[Vector2i] = []
	var best_cost: float = INF
	var best_turns: int = 999
	var best_strat: String = ""

	# 1. Z-Routes para start y goal no colineales
	if start.x != goal.x and start.y != goal.y:
		var min_x: int = mini(start.x, goal.x)
		var max_x: int = maxi(start.x, goal.x)
		var mid_x: int = int((start.x + goal.x) / 2.0)

		var min_y: int = mini(start.y, goal.y)
		var max_y: int = maxi(start.y, goal.y)
		var mid_y: int = int((start.y + goal.y) / 2.0)

		# Generar candidatos X interiores para Z_HVH (start -> (x, start.y) -> (x, goal.y) -> goal)
		var xs_z: Array[int] = [mid_x]
		for offset in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 8, -8]:
			var test_x: int = mid_x + offset
			if test_x > min_x and test_x < max_x and not xs_z.has(test_x):
				xs_z.append(test_x)

		for x in xs_z:
			var p1 := Vector2i(x, start.y)
			var p2 := Vector2i(x, goal.y)
			var candidate_z := _combine_waypoints([start, p1, p2, goal])
			if _is_path_valid(grid, room_map, room_a_id, room_b_id, candidate_z):
				var cost: float = _score_path(grid, candidate_z, 2, config)
				if cost < best_cost:
					best_cost = cost
					best_path = candidate_z
					best_turns = 2
					best_strat = "Z_HVH"

		# Generar candidatos Y interiores para Z_VHV (start -> (start.x, y) -> (goal.x, y) -> goal)
		var ys_z: Array[int] = [mid_y]
		for offset in [1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 8, -8]:
			var test_y: int = mid_y + offset
			if test_y > min_y and test_y < max_y and not ys_z.has(test_y):
				ys_z.append(test_y)

		for y in ys_z:
			var p1 := Vector2i(start.x, y)
			var p2 := Vector2i(goal.x, y)
			var candidate_z := _combine_waypoints([start, p1, p2, goal])
			if _is_path_valid(grid, room_map, room_a_id, room_b_id, candidate_z):
				var cost: float = _score_path(grid, candidate_z, 2, config)
				if cost < best_cost:
					best_cost = cost
					best_path = candidate_z
					best_turns = 2
					best_strat = "Z_VHV"

	# 2. U-routes (Rodeo de 2 giros) si start y goal son colineales pero están bloqueados
	if start.y == goal.y:
		# Colineal horizontal: probar desplazamientos en Y hacia arriba y abajo
		for delta_y in [2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 8, -8, 10, -10]:
			var test_y: int = start.y + delta_y
			if test_y < 1 or test_y >= grid.height - 1:
				continue
			var p1 := Vector2i(start.x, test_y)
			var p2 := Vector2i(goal.x, test_y)
			var candidate_u := _combine_waypoints([start, p1, p2, goal])
			if _is_path_valid(grid, room_map, room_a_id, room_b_id, candidate_u):
				var cost: float = _score_path(grid, candidate_u, 2, config)
				if cost < best_cost:
					best_cost = cost
					best_path = candidate_u
					best_turns = 2
					best_strat = "U_HVH"

	if start.x == goal.x:
		# Colineal vertical: probar desplazamientos en X hacia izquierda y derecha
		for delta_x in [2, -2, 3, -3, 4, -4, 5, -5, 6, -6, 8, -8, 10, -10]:
			var test_x: int = start.x + delta_x
			if test_x < 1 or test_x >= grid.width - 1:
				continue
			var p1 := Vector2i(test_x, start.y)
			var p2 := Vector2i(test_x, goal.y)
			var candidate_u := _combine_waypoints([start, p1, p2, goal])
			if _is_path_valid(grid, room_map, room_a_id, room_b_id, candidate_u):
				var cost: float = _score_path(grid, candidate_u, 2, config)
				if cost < best_cost:
					best_cost = cost
					best_path = candidate_u
					best_turns = 2
					best_strat = "U_VHV"

	if not best_path.is_empty() and best_turns <= config.corridor_max_preferred_turns:
		return {
			"success": true,
			"centerline": best_path,
			"strategy": best_strat,
			"turns": best_turns
		}

	return {
		"success": false,
		"centerline": [] as Array[Vector2i],
		"strategy": "None",
		"turns": -1
	}

## Calcula el coste heurístico de un candidato ortogonal.
static func _score_path(grid: CellGrid, path: Array[Vector2i], turns: int, config: DungeonConfig) -> float:
	var length_cost: float = float(path.size())
	var turn_cost: float = float(turns) * config.corridor_turn_penalty
	var reuse_bonus: float = 0.0

	for c in path:
		if grid.get_cell(c) == CellGrid.CellType.CORRIDOR:
			reuse_bonus += 0.5

	return length_cost + turn_cost - reuse_bonus
