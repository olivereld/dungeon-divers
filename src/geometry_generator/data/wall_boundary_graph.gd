class_name WallBoundaryGraph
extends RefCounted

## Grafo explícito de aristas dirigidas de frontera entre celdas transitables y sólidas.
## Soporta búsqueda de vecindad, extracción de componentes y seguimiento topológico sin heurísticas locales ambiguas.

var vertices: Array[Vector2i] = []
var vertex_index_map: Dictionary = {} # Vector2i -> int

# Lista de adyacencia dirigida: u_idx -> Array[v_idx]
var adjacency: Dictionary = {} # int -> Array[int]

# Metadatos por arista: Vector4i(start.x, start.y, end.x, end.y) -> Dictionary
var edge_meta: Dictionary = {} # Vector4i -> Dictionary

func add_vertex(pt: Vector2i) -> int:
	if vertex_index_map.has(pt):
		return vertex_index_map[pt]
	var idx: int = vertices.size()
	vertices.append(pt)
	vertex_index_map[pt] = idx
	adjacency[idx] = []
	return idx

func add_directed_edge(start_pt: Vector2i, end_pt: Vector2i, meta: Dictionary = {}) -> void:
	var u: int = add_vertex(start_pt)
	var v: int = add_vertex(end_pt)
	if not adjacency[u].has(v):
		adjacency[u].append(v)
	var edge_key := Vector4i(start_pt.x, start_pt.y, end_pt.x, end_pt.y)
	edge_meta[edge_key] = meta

func has_edge(start_pt: Vector2i, end_pt: Vector2i) -> bool:
	if not vertex_index_map.has(start_pt) or not vertex_index_map.has(end_pt):
		return false
	var u: int = vertex_index_map[start_pt]
	var v: int = vertex_index_map[end_pt]
	return adjacency.has(u) and adjacency[u].has(v)

func get_outgoing_neighbors(pt: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not vertex_index_map.has(pt):
		return result
	var u: int = vertex_index_map[pt]
	for v in adjacency.get(u, []):
		result.append(vertices[v])
	return result

func get_edge_count() -> int:
	var count: int = 0
	for u in adjacency.keys():
		count += adjacency[u].size()
	return count

func get_all_edges() -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for u in adjacency.keys():
		var start_pt: Vector2i = vertices[u]
		for v in adjacency[u]:
			var end_pt: Vector2i = vertices[v]
			var k := Vector4i(start_pt.x, start_pt.y, end_pt.x, end_pt.y)
			edges.append({
				"start": start_pt,
				"end": end_pt,
				"meta": edge_meta.get(k, {})
			})
	return edges
