class_name DelaunayTriangulator
extends RefCounted

## Implementación pura de Triangulación de Delaunay 2D (Bowyer-Watson).
## Conecta los centros de las habitaciones en un grafo planar libre de cruces caóticos.

class Edge:
	var u: int
	var v: int
	var weight: float

	func _init(p_u: int, p_v: int, p_weight: float) -> void:
		u = mini(p_u, p_v)
		v = maxi(p_u, p_v)
		weight = p_weight

	func equals(other: Edge) -> bool:
		return u == other.u and v == other.v

class _Triangle:
	var a: int
	var b: int
	var c: int
	var circum_center: Vector2
	var circum_radius_sq: float

	func _init(p_a: int, p_b: int, p_c: int, points: Array[Vector2]) -> void:
		a = p_a
		b = p_b
		c = p_c
		_calculate_circumcircle(points[a], points[b], points[c])

	func _calculate_circumcircle(p1: Vector2, p2: Vector2, p3: Vector2) -> void:
		var d: float = 2.0 * (p1.x * (p2.y - p3.y) + p2.x * (p3.y - p1.y) + p3.x * (p1.y - p2.y))
		if absf(d) < 0.00001:
			circum_center = (p1 + p2 + p3) / 3.0
			circum_radius_sq = 99999999.0
			return

		var ux: float = ((p1.x * p1.x + p1.y * p1.y) * (p2.y - p3.y) + (p2.x * p2.x + p2.y * p2.y) * (p3.y - p1.y) + (p3.x * p3.x + p3.y * p3.y) * (p1.y - p2.y)) / d
		var uy: float = ((p1.x * p1.x + p1.y * p1.y) * (p3.x - p2.x) + (p2.x * p2.x + p2.y * p2.y) * (p1.x - p3.x) + (p3.x * p3.x + p3.y * p3.y) * (p2.x - p1.x)) / d
		circum_center = Vector2(ux, uy)
		circum_radius_sq = circum_center.distance_squared_to(p1)

	func contains_in_circumcircle(point: Vector2) -> bool:
		return circum_center.distance_squared_to(point) <= circum_radius_sq

	func has_vertex(v_idx: int) -> bool:
		return a == v_idx or b == v_idx or c == v_idx

## Triangula un conjunto de habitaciones y retorna la lista de aristas candidatas.
static func triangulate(rooms: Array[RoomData]) -> Array[Edge]:
	var n: int = rooms.size()
	if n < 2:
		return []

	# Casos base para 2 y 3 habitaciones
	if n == 2:
		var dist: float = Vector2(rooms[0].get_center()).distance_to(Vector2(rooms[1].get_center()))
		return [Edge.new(0, 1, dist)]

	if n == 3:
		var p0 := Vector2(rooms[0].get_center())
		var p1 := Vector2(rooms[1].get_center())
		var p2 := Vector2(rooms[2].get_center())
		return [
			Edge.new(0, 1, p0.distance_to(p1)),
			Edge.new(1, 2, p1.distance_to(p2)),
			Edge.new(0, 2, p0.distance_to(p2))
		]

	var points: Array[Vector2] = []
	var min_x: float = 999999.0
	var min_y: float = 999999.0
	var max_x: float = -999999.0
	var max_y: float = -999999.0

	for room in rooms:
		var c := Vector2(room.get_center())
		points.append(c)
		min_x = minf(min_x, c.x)
		min_y = minf(min_y, c.y)
		max_x = maxf(max_x, c.x)
		max_y = maxf(max_y, c.y)

	var dx: float = (max_x - min_x) * 2.0 + 100.0
	var dy: float = (max_y - min_y) * 2.0 + 100.0
	var mid_x: float = (min_x + max_x) * 0.5
	var mid_y: float = (min_y + max_y) * 0.5

	# Vértices del Super-Triángulo
	var st_idx0: int = points.size()
	var st_idx1: int = points.size() + 1
	var st_idx2: int = points.size() + 2

	points.append(Vector2(mid_x - dx, mid_y - dy))
	points.append(Vector2(mid_x + dx, mid_y - dy))
	points.append(Vector2(mid_x, mid_y + dy * 2.0))

	var triangles: Array[_Triangle] = []
	triangles.append(_Triangle.new(st_idx0, st_idx1, st_idx2, points))

	# Bowyer-Watson para cada punto
	for i in range(n):
		var p := points[i]
		var bad_triangles: Array[_Triangle] = []

		for tri in triangles:
			if tri.contains_in_circumcircle(p):
				bad_triangles.append(tri)

		# Hallar aristas de frontera del polígono
		var polygon_edges: Array[Array] = []
		for tri in bad_triangles:
			var tri_edges := [
				[tri.a, tri.b],
				[tri.b, tri.c],
				[tri.c, tri.a]
			]
			for edge in tri_edges:
				var is_shared: bool = false
				for other in bad_triangles:
					if other == tri:
						continue
					if other.has_vertex(edge[0]) and other.has_vertex(edge[1]):
						is_shared = true
						break
				if not is_shared:
					polygon_edges.append(edge)

		# Eliminar triángulos inválidos
		for tri in bad_triangles:
			triangles.erase(tri)

		# Re-triangular con el nuevo punto
		for edge in polygon_edges:
			triangles.append(_Triangle.new(edge[0], edge[1], i, points))

	# Filtrar triángulos que contengan vértices del super-triángulo
	var final_edges_dict: Dictionary = {}
	for tri in triangles:
		if tri.has_vertex(st_idx0) or tri.has_vertex(st_idx1) or tri.has_vertex(st_idx2):
			continue

		var tri_edges := [
			[tri.a, tri.b],
			[tri.b, tri.c],
			[tri.c, tri.a]
		]
		for e in tri_edges:
			var u: int = mini(e[0], e[1])
			var v: int = maxi(e[0], e[1])
			var key := "%d-%d" % [u, v]
			if not final_edges_dict.has(key):
				var dist: float = points[u].distance_to(points[v])
				final_edges_dict[key] = Edge.new(u, v, dist)

	var result: Array[Edge] = []
	for edge in final_edges_dict.values():
		result.append(edge)

	return result
