class_name ContinuousWallExtractor
extends RefCounted

## Extractor de contornos y bucles perimetrales continuos a partir de un CellGrid.
## Utiliza trazado de aristas dirigidas (Half-Edge Contour Following) y soporta
## "carving" de vanos por arista orientada a través de WallOpeningManifest (Fase 9).

const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

enum EdgeDir {
	NORTH = 0, # Arista de (x, y) a (x+1, y)
	EAST = 1,  # Arista de (x+1, y) a (x+1, y+1)
	SOUTH = 2, # Arista de (x+1, y+1) a (x, y+1)
	WEST = 3   # Arista de (x, y+1) a (x, y)
}

class WallLoop:
	var vertices: Array[Vector3] = []
	var is_closed: bool = true

## Extrae todos los bucles de contorno cerrados exactos de la mazmorra respetando vanos de puerta.
static func extract_wall_loops(
	grid: CellGrid,
	cell_size: float = 2.0,
	opening_manifest: WallOpeningManifest = null
) -> Array[WallLoop]:
	var loops: Array[WallLoop] = []
	if grid == null:
		return loops

	var w: int = grid.width
	var h: int = grid.height

	# 1. Encontrar todas las aristas de frontera activas (omitiendo vanos de puerta registrados)
	# Clave de arista única: Vector3i(cell_x, cell_y, edge_dir)
	var active_edges: Dictionary = {} # Vector3i -> bool

	for y in range(h):
		for x in range(w):
			var cell := Vector2i(x, y)
			if not grid.is_walkable(cell):
				continue

			# Borde Norte (Norte es muro, vacío o transición de sala a corredor sin vano)
			if _should_have_wall(grid, cell, cell + Vector2i(0, -1), _RoomEntranceScript.NORTH, opening_manifest):
				active_edges[Vector3i(x, y, EdgeDir.NORTH)] = true

			# Borde Este
			if _should_have_wall(grid, cell, cell + Vector2i(1, 0), _RoomEntranceScript.EAST, opening_manifest):
				active_edges[Vector3i(x, y, EdgeDir.EAST)] = true

			# Borde Sur
			if _should_have_wall(grid, cell, cell + Vector2i(0, 1), _RoomEntranceScript.SOUTH, opening_manifest):
				active_edges[Vector3i(x, y, EdgeDir.SOUTH)] = true

			# Borde Oeste
			if _should_have_wall(grid, cell, cell + Vector2i(-1, 0), _RoomEntranceScript.WEST, opening_manifest):
				active_edges[Vector3i(x, y, EdgeDir.WEST)] = true

	# 2. Trazar bucles cerrados siguiendo la continuidad geométrica exacta de aristas
	var visited_edges: Dictionary = {} # Vector3i -> bool

	for start_edge in active_edges.keys():
		if visited_edges.has(start_edge):
			continue

		var loop_points: Array[Vector2i] = []
		var curr_edge: Vector3i = start_edge
		var max_steps: int = active_edges.size() + 10
		var step_count: int = 0

		while not visited_edges.has(curr_edge) and step_count < max_steps:
			visited_edges[curr_edge] = true
			step_count += 1

			var start_pt: Vector2i = _get_edge_start_point(curr_edge)
			loop_points.append(start_pt)

			# Buscar la siguiente arista conectada geométricamente
			var next_edge: Vector3i = _find_next_connected_edge(curr_edge, active_edges)
			if next_edge == Vector3i(-1, -1, -1) or next_edge == start_edge:
				break
			curr_edge = next_edge

		if loop_points.size() >= 3:
			var simplified: Array[Vector2i] = _simplify_polygon(loop_points)
			if simplified.size() >= 3:
				var loop := WallLoop.new()
				for pt in simplified:
					loop.vertices.append(Vector3(float(pt.x) * cell_size, 0.0, float(pt.y) * cell_size))
				loops.append(loop)

	return loops

static func _get_edge_start_point(edge: Vector3i) -> Vector2i:
	var x: int = edge.x
	var y: int = edge.y
	match edge.z:
		EdgeDir.NORTH: return Vector2i(x, y)
		EdgeDir.EAST:  return Vector2i(x + 1, y)
		EdgeDir.SOUTH: return Vector2i(x + 1, y + 1)
		EdgeDir.WEST:  return Vector2i(x, y + 1)
	return Vector2i(x, y)

static func _get_edge_end_point(edge: Vector3i) -> Vector2i:
	var x: int = edge.x
	var y: int = edge.y
	match edge.z:
		EdgeDir.NORTH: return Vector2i(x + 1, y)
		EdgeDir.EAST:  return Vector2i(x + 1, y + 1)
		EdgeDir.SOUTH: return Vector2i(x, y + 1)
		EdgeDir.WEST:  return Vector2i(x, y)
	return Vector2i(x, y)

## Encuentra la siguiente arista en el orden geométrico de giro (prioridad: giro exterior, recto, giro interior)
static func _find_next_connected_edge(curr_edge: Vector3i, active_edges: Dictionary) -> Vector3i:
	var end_pt: Vector2i = _get_edge_end_point(curr_edge)
	var x: int = curr_edge.x
	var y: int = curr_edge.y
	var dir: int = curr_edge.z

	var candidates: Array[Vector3i] = []

	match dir:
		EdgeDir.NORTH:
			candidates = [
				Vector3i(x, y, EdgeDir.EAST),
				Vector3i(x + 1, y, EdgeDir.NORTH),
				Vector3i(x + 1, y - 1, EdgeDir.WEST),
			]
		EdgeDir.EAST:
			candidates = [
				Vector3i(x, y, EdgeDir.SOUTH),
				Vector3i(x, y + 1, EdgeDir.EAST),
				Vector3i(x + 1, y + 1, EdgeDir.NORTH),
			]
		EdgeDir.SOUTH:
			candidates = [
				Vector3i(x, y, EdgeDir.WEST),
				Vector3i(x - 1, y, EdgeDir.SOUTH),
				Vector3i(x - 1, y + 1, EdgeDir.EAST),
			]
		EdgeDir.WEST:
			candidates = [
				Vector3i(x, y, EdgeDir.NORTH),
				Vector3i(x, y - 1, EdgeDir.WEST),
				Vector3i(x - 1, y - 1, EdgeDir.SOUTH),
			]

	# Probar candidatos específicos de giro
	for cand in candidates:
		if active_edges.has(cand):
			return cand

	# Fallback: cualquier arista activa que comience en end_pt
	for edge in active_edges.keys():
		if _get_edge_start_point(edge) == end_pt:
			return edge

	return Vector3i(-1, -1, -1)

## Simplifica vértices colineales en un polígono cerrado ortogonal.
static func _simplify_polygon(pts: Array[Vector2i]) -> Array[Vector2i]:
	var n: int = pts.size()
	if n < 3:
		return pts

	var result: Array[Vector2i] = []
	for i in range(n):
		var prev: Vector2i = pts[(i - 1 + n) % n]
		var curr: Vector2i = pts[i]
		var next: Vector2i = pts[(i + 1) % n]

		var dir1: Vector2i = curr - prev
		var dir2: Vector2i = next - curr

		# Si cambian de dirección ortogonal, conservamos el vértice de esquina
		var cross_prod: int = dir1.x * dir2.y - dir1.y * dir2.x
		var dot_prod: int = dir1.x * dir2.x + dir1.y * dir2.y
		if cross_prod != 0 or dot_prod <= 0:
			result.append(curr)

	return result

static func _should_have_wall(
	grid: CellGrid,
	cell: Vector2i,
	neighbor: Vector2i,
	side: int,
	opening_manifest: WallOpeningManifest
) -> bool:
	if not grid.is_in_bounds(neighbor):
		return true

	if not grid.is_walkable(neighbor):
		if opening_manifest != null and opening_manifest.has_opening(cell, side):
			return false
		return true

	# Ambas celdas son transitables (walkable -> walkable):
	# Si es frontera ROOM <-> CORRIDOR, debe generar pared divisoria a menos que
	# exista una abertura explícita de puerta/arco registrada.
	if _is_room_corridor_boundary(grid, cell, neighbor):
		var opp_side := _opposite_side(side)
		if opening_manifest != null and (opening_manifest.has_opening(cell, side) or opening_manifest.has_opening(neighbor, opp_side)):
			return false
		return true

	# ROOM <-> ROOM o CORRIDOR <-> CORRIDOR: no crear pared
	return false

static func _is_room_corridor_boundary(grid: CellGrid, cell: Vector2i, neighbor: Vector2i) -> bool:
	var c_room := _is_room_cell(grid, cell)
	var n_room := _is_room_cell(grid, neighbor)
	var c_corr := _is_corridor_cell(grid, cell)
	var n_corr := _is_corridor_cell(grid, neighbor)
	return (c_room and n_corr) or (c_corr and n_room)

static func _is_room_cell(grid: CellGrid, pos: Vector2i) -> bool:
	if not grid.is_walkable(pos):
		return false
	if grid.get_room_owner(pos) != -1:
		return true
	var t: int = grid.get_cell(pos)
	return t != CellGrid.CellType.CORRIDOR and t != CellGrid.CellType.DOOR and t != CellGrid.CellType.LOCKED_DOOR

static func _is_corridor_cell(grid: CellGrid, pos: Vector2i) -> bool:
	if not grid.is_walkable(pos):
		return false
	return grid.get_cell(pos) == CellGrid.CellType.CORRIDOR

static func _opposite_side(side: int) -> int:
	match side:
		_RoomEntranceScript.NORTH: return _RoomEntranceScript.SOUTH
		_RoomEntranceScript.SOUTH: return _RoomEntranceScript.NORTH
		_RoomEntranceScript.EAST:  return _RoomEntranceScript.WEST
		_RoomEntranceScript.WEST:  return _RoomEntranceScript.EAST
	return side
