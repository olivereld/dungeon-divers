class_name ComponentExtractor
extends RefCounted

## Descompone un WallBoundaryGraph en un conjunto de WallComponents independientes.
## Extrae bucles cerrados y cadenas abiertas ordenadas, simplificando vértices colineales.

const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _WallBoundaryGraphScript = preload("res://src/geometry_generator/data/wall_boundary_graph.gd")

func extract_components(graph: WallBoundaryGraph) -> Array[WallComponent]:
	var components: Array[WallComponent] = []
	if graph == null or graph.get_edge_count() == 0:
		return components

	var all_edges: Array[Dictionary] = graph.get_all_edges()

	# Paso 1: Agrupar aristas en componentes conexas no dirigidas
	var adj: Dictionary = {} # Vector2i -> Array[Dictionary (edges)]
	for e in all_edges:
		var u: Vector2i = e["start"]
		var v: Vector2i = e["end"]
		if not adj.has(u):
			adj[u] = []
		if not adj.has(v):
			adj[v] = []
		adj[u].append(e)
		adj[v].append(e)

	var visited_vertices: Dictionary = {}
	var connected_edge_groups: Array[Array] = []
	var visited_edges_global: Dictionary = {}

	for v_start in adj.keys():
		if visited_vertices.has(v_start):
			continue

		var group_edges: Array[Dictionary] = []
		var queue: Array[Vector2i] = [v_start]
		visited_vertices[v_start] = true

		while not queue.is_empty():
			var curr: Vector2i = queue.pop_front()
			for e in adj[curr]:
				var edge_k := Vector4i(e["start"].x, e["start"].y, e["end"].x, e["end"].y)
				if not visited_edges_global.has(edge_k):
					visited_edges_global[edge_k] = true
					group_edges.append(e)

				var nxt: Vector2i = e["end"] if e["start"] == curr else e["start"]
				if not visited_vertices.has(nxt):
					visited_vertices[nxt] = true
					queue.append(nxt)

		if not group_edges.is_empty():
			connected_edge_groups.append(group_edges)

	# Paso 2: Dentro de cada componente conexa, reconstruir loops y open_chains completos
	var comp_id: int = 0
	for group in connected_edge_groups:
		var comp := _WallComponentScript.new(comp_id)
		_reconstruct_component_paths(group, comp)
		if not comp.is_empty():
			components.append(comp)
			comp_id += 1

	return components

static func _reconstruct_component_paths(group_edges: Array, comp: WallComponent) -> void:
	var outgoing: Dictionary = {} # Vector2i -> Array[Vector2i]
	var in_deg: Dictionary = {}
	var out_deg: Dictionary = {}

	for e in group_edges:
		var u: Vector2i = e["start"]
		var v: Vector2i = e["end"]
		if not outgoing.has(u):
			outgoing[u] = []
		outgoing[u].append(v)
		out_deg[u] = out_deg.get(u, 0) + 1
		in_deg[v] = in_deg.get(v, 0) + 1

	var visited_edges: Dictionary = {}

	var get_unvisited_out = func(pt: Vector2i) -> Array[Vector2i]:
		var res: Array[Vector2i] = []
		for nxt in outgoing.get(pt, []):
			var k := Vector4i(pt.x, pt.y, nxt.x, nxt.y)
			if not visited_edges.has(k):
				res.append(nxt)
		return res

	# 1. Extraer cadenas abiertas buscando vértices donde out_degree > in_degree
	while true:
		var start_pt := Vector2i(-999999, -999999)
		for u in out_deg.keys():
			var u_out: Array[Vector2i] = get_unvisited_out.call(u)
			if u_out.is_empty():
				continue
			if out_deg.get(u, 0) > in_deg.get(u, 0):
				start_pt = u
				break

		if start_pt == Vector2i(-999999, -999999):
			break

		var path: Array[Vector2i] = [start_pt]
		var curr := start_pt
		var closed := false

		while true:
			var candidates: Array[Vector2i] = get_unvisited_out.call(curr)
			if candidates.is_empty():
				break
			var nxt: Vector2i = candidates[0]
			visited_edges[Vector4i(curr.x, curr.y, nxt.x, nxt.y)] = true
			if nxt == start_pt:
				closed = true
				break
			curr = nxt
			path.append(curr)

		if path.size() >= 2:
			if closed and path.size() >= 3:
				var simplified: Array[Vector2i] = simplify_polygon(path)
				if simplified.size() >= 3:
					comp.add_loop(simplified)
			else:
				var simplified: Array[Vector2i] = simplify_chain(path)
				if simplified.size() >= 2:
					comp.add_chain(simplified)

	# 2. Extraer ciclos cerrados restantes (Eulerian circuits)
	while true:
		var start_pt := Vector2i(-999999, -999999)
		for u in outgoing.keys():
			var u_out: Array[Vector2i] = get_unvisited_out.call(u)
			if not u_out.is_empty():
				start_pt = u
				break

		if start_pt == Vector2i(-999999, -999999):
			break

		var path: Array[Vector2i] = [start_pt]
		var curr := start_pt
		var closed := false

		while true:
			var candidates: Array[Vector2i] = get_unvisited_out.call(curr)
			if candidates.is_empty():
				break
			var nxt: Vector2i = candidates[0]
			visited_edges[Vector4i(curr.x, curr.y, nxt.x, nxt.y)] = true
			if nxt == start_pt:
				closed = true
				break
			curr = nxt
			path.append(curr)

		if path.size() >= 2:
			if closed and path.size() >= 3:
				var simplified: Array[Vector2i] = simplify_polygon(path)
				if simplified.size() >= 3:
					comp.add_loop(simplified)
			else:
				var simplified: Array[Vector2i] = simplify_chain(path)
				if simplified.size() >= 2:
					comp.add_chain(simplified)

## Simplifica vértices colineales consecutivos en un polígono cerrado ortogonal.
static func simplify_polygon(pts: Array[Vector2i]) -> Array[Vector2i]:
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

## Simplifica vértices colineales en una cadena abierta sin tratar los extremos como cíclicos.
static func simplify_chain(pts: Array[Vector2i]) -> Array[Vector2i]:
	var n: int = pts.size()
	if n < 3:
		return pts

	var result: Array[Vector2i] = []
	result.append(pts[0])

	for i in range(1, n - 1):
		var prev: Vector2i = pts[i - 1]
		var curr: Vector2i = pts[i]
		var next: Vector2i = pts[i + 1]

		var dir1: Vector2i = curr - prev
		var dir2: Vector2i = next - curr

		var cross_prod: int = dir1.x * dir2.y - dir1.y * dir2.x
		var dot_prod: int = dir1.x * dir2.x + dir1.y * dir2.y
		if cross_prod != 0 or dot_prod <= 0:
			result.append(curr)

	result.append(pts[n - 1])
	return result
