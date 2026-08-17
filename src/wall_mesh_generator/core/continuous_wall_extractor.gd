class_name ContinuousWallExtractor
extends RefCounted

## Extractor de contornos y bucles perimetrales continuos a partir de un CellGrid.
## Utiliza trazado de aristas dirigidas (Half-Edge Contour Following) para garantizar
## que ningún contorno salte entre habitaciones ni genere diagonales espurias.

enum EdgeDir {
	NORTH = 0, # Arista de (x, y) a (x+1, y)
	EAST = 1,  # Arista de (x+1, y) a (x+1, y+1)
	SOUTH = 2, # Arista de (x+1, y+1) a (x, y+1)
	WEST = 3   # Arista de (x, y+1) a (x, y)
}

class WallLoop:
	var vertices: Array[Vector3] = []
	var is_closed: bool = true

## Extrae todos los bucles de contorno cerrados exactos de la mazmorra.
static func extract_wall_loops(grid: CellGrid, cell_size: float = 2.0) -> Array[WallLoop]:
	var loops: Array[WallLoop] = []
	if grid == null:
		return loops

	var w: int = grid.width
	var h: int = grid.height

	# 1. Encontrar todas las aristas de frontera activas
	# Clave de arista única: Vector3i(cell_x, cell_y, edge_dir)
	var active_edges: Dictionary = {} # Vector3i -> bool

	for y in range(h):
		for x in range(w):
			var cell := Vector2i(x, y)
			if not grid.is_walkable(cell):
				continue

			# Borde Norte (Norte es muro o vacío)
			if not grid.is_walkable(cell + Vector2i(0, -1)):
				active_edges[Vector3i(x, y, EdgeDir.NORTH)] = true

			# Borde Este (Este es muro o vacío)
			if not grid.is_walkable(cell + Vector2i(1, 0)):
				active_edges[Vector3i(x, y, EdgeDir.EAST)] = true

			# Borde Sur (Sur es muro o vacío)
			if not grid.is_walkable(cell + Vector2i(0, 1)):
				active_edges[Vector3i(x, y, EdgeDir.SOUTH)] = true

			# Borde Oeste (Oeste es muro o vacío)
			if not grid.is_walkable(cell + Vector2i(-1, 0)):
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

## Encuentra la siguiente arista en el orden geométrico de giro (prioridad: giro izquierda, recto, giro derecha)
static func _find_next_connected_edge(curr_edge: Vector3i, active_edges: Dictionary) -> Vector3i:
	var end_pt: Vector2i = _get_edge_end_point(curr_edge)
	var x: int = curr_edge.x
	var y: int = curr_edge.y
	var dir: int = curr_edge.z

	# Candidatos según la dirección actual para mantener el orden estricto de contorno
	var candidates: Array[Vector3i] = []

	match dir:
		EdgeDir.NORTH:
			candidates = [
				Vector3i(x + 1, y - 1, EdgeDir.WEST),
				Vector3i(x + 1, y, EdgeDir.NORTH),
				Vector3i(x, y, EdgeDir.EAST),
			]
		EdgeDir.EAST:
			candidates = [
				Vector3i(x + 1, y + 1, EdgeDir.NORTH),
				Vector3i(x, y + 1, EdgeDir.EAST),
				Vector3i(x, y, EdgeDir.SOUTH),
			]
		EdgeDir.SOUTH:
			candidates = [
				Vector3i(x - 1, y + 1, EdgeDir.EAST),
				Vector3i(x - 1, y, EdgeDir.SOUTH),
				Vector3i(x, y, EdgeDir.WEST),
			]
		EdgeDir.WEST:
			candidates = [
				Vector3i(x - 1, y - 1, EdgeDir.SOUTH),
				Vector3i(x, y - 1, EdgeDir.WEST),
				Vector3i(x, y, EdgeDir.NORTH),
			]

	# Probar candidatos específicos
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
