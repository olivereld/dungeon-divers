class_name DelaunayCandidateBuilder
extends RefCounted

## Constructor de aristas candidatas mediante Triangulación de Delaunay (Bowyer-Watson).
## Maneja casos degenerados (0, 1, 2, 3 habitaciones, puntos colineales) y normaliza aristas deterministamente.

const _CandidateEdgeScript = preload("res://src/dungeon_generator/core/topology/candidate_edge.gd")

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

static func build_candidates(rooms: Array[RoomData]) -> Array:
	var n: int = rooms.size()
	if n < 2:
		return []

	# Caso 2 habitaciones
	if n == 2:
		var p0 := Vector2(rooms[0].get_center())
		var p1 := Vector2(rooms[1].get_center())
		var dist_sq: int = int(p0.distance_squared_to(p1))
		var edge = _CandidateEdgeScript.new(rooms[0].id, rooms[1].id, dist_sq, sqrt(float(dist_sq)))
		return [edge]

	# Caso 3 habitaciones
	if n == 3:
		var p0 := Vector2(rooms[0].get_center())
		var p1 := Vector2(rooms[1].get_center())
		var p2 := Vector2(rooms[2].get_center())
		var edges: Array = [
			_CandidateEdgeScript.new(rooms[0].id, rooms[1].id, int(p0.distance_squared_to(p1))),
			_CandidateEdgeScript.new(rooms[1].id, rooms[2].id, int(p1.distance_squared_to(p2))),
			_CandidateEdgeScript.new(rooms[0].id, rooms[2].id, int(p0.distance_squared_to(p2)))
		]
		_sort_edges(edges)
		return edges

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

	for i in range(n):
		var p := points[i]
		var bad_triangles: Array[_Triangle] = []

		for tri in triangles:
			if tri.contains_in_circumcircle(p):
				bad_triangles.append(tri)

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

		for tri in bad_triangles:
			triangles.erase(tri)

		for edge in polygon_edges:
			triangles.append(_Triangle.new(edge[0], edge[1], i, points))

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
			if u >= n or v >= n or u == v:
				continue
			var room_a_id: int = rooms[u].id
			var room_b_id: int = rooms[v].id
			var key := "%d-%d" % [mini(room_a_id, room_b_id), maxi(room_a_id, room_b_id)]
			if not final_edges_dict.has(key):
				var dist_sq: int = int(points[u].distance_squared_to(points[v]))
				final_edges_dict[key] = _CandidateEdgeScript.new(room_a_id, room_b_id, dist_sq, sqrt(float(dist_sq)))

	var result: Array = []
	for edge in final_edges_dict.values():
		result.append(edge)

	# Fallback si los puntos eran colineales o degenerados y Delaunay no pudo triangular:
	if result.size() < n - 1:
		for i in range(n - 1):
			var r_a := rooms[i]
			var r_b := rooms[i + 1]
			var key := "%d-%d" % [mini(r_a.id, r_b.id), maxi(r_a.id, r_b.id)]
			if not final_edges_dict.has(key):
				var p_a := Vector2(r_a.get_center())
				var p_b := Vector2(r_b.get_center())
				var dist_sq: int = int(p_a.distance_squared_to(p_b))
				var e = _CandidateEdgeScript.new(r_a.id, r_b.id, dist_sq, sqrt(float(dist_sq)))
				final_edges_dict[key] = e
				result.append(e)

	_sort_edges(result)
	return result

static func _sort_edges(edges: Array) -> void:
	edges.sort_custom(func(a, b):
		if not is_equal_approx(a.weight, b.weight):
			return a.weight < b.weight
		if a.room_a_id != b.room_a_id:
			return a.room_a_id < b.room_a_id
		return a.room_b_id < b.room_b_id
	)
