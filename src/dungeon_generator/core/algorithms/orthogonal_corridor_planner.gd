class_name OrthogonalCorridorPlanner
extends RefCounted

## Planificador analítico de corredores ortogonales de alta calidad arquitectónica (Fase Refined).
## Genera rutas puramente ortogonales evaluando en orden estricto de preferencia:
## - Nivel 0: Línea recta (0 giros)
## - Nivel 1: L limpia (H->V o V->H, 1 giro)
## - Nivel 2: Multi-giro ortogonal (2–3 giros) [Preparado para Task 3]
##
## Aplica validación estricta de límites, columnas, obstáculos sólidos y salas ajenas antes de aceptar cualquier ruta.

static func plan_route(
	grid: CellGrid,
	rooms: Array,
	room_a_id: int,
	room_b_id: int,
	start: Vector2i,
	goal: Vector2i,
	_config: DungeonConfig
) -> Dictionary:
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

	# Rechazar penetración en el interior de salas que no sean los extremos a conectar
	for rid in room_map:
		if rid != room_a_id and rid != room_b_id:
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
	var path_hv: Array[Vector2i] = _build_straight_segment(start, corner_hv)
	var leg2_hv: Array[Vector2i] = _build_straight_segment(corner_hv, goal)
	for i in range(1, leg2_hv.size()):
		path_hv.append(leg2_hv[i])

	var valid_hv: bool = true
	for cell in path_hv:
		if not is_cell_valid_for_corridor(grid, room_map, room_a_id, room_b_id, cell):
			valid_hv = false
			break

	# Opción B: V -> H (Esquina en start.x, goal.y)
	var corner_vh: Vector2i = Vector2i(start.x, goal.y)
	var path_vh: Array[Vector2i] = _build_straight_segment(start, corner_vh)
	var leg2_vh: Array[Vector2i] = _build_straight_segment(corner_vh, goal)
	for i in range(1, leg2_vh.size()):
		path_vh.append(leg2_vh[i])

	var valid_vh: bool = true
	for cell in path_vh:
		if not is_cell_valid_for_corridor(grid, room_map, room_a_id, room_b_id, cell):
			valid_vh = false
			break

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
