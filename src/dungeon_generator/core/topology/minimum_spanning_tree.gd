class_name MinimumSpanningTree
extends RefCounted

## Sólver de Árbol de Expansión Mínimo (MST) determinista basado en Kruskal y DisjointSet.
## NO utiliza RNG. Produce exactamente N - 1 aristas para N habitaciones conectadas.

const _DisjointSetScript = preload("res://src/dungeon_generator/core/topology/disjoint_set.gd")
const _CandidateEdgeScript = preload("res://src/dungeon_generator/core/topology/candidate_edge.gd")

class MSTResult extends RefCounted:
	var mst_edges: Array = []
	var non_mst_edges: Array = []
	var is_connected: bool = false
	var component_count: int = 1

static func solve(rooms: Array[RoomData], candidate_edges: Array) -> MSTResult:
	var result := MSTResult.new()
	var n: int = rooms.size()
	if n < 2:
		result.is_connected = true
		result.component_count = n
		return result

	# Mapear room_id a índice contiguo 0..n-1
	var id_to_index: Dictionary = {}
	for i in range(n):
		id_to_index[rooms[i].id] = i

	# Ordenar aristas por peso de forma determinista
	var sorted_edges: Array = candidate_edges.duplicate()
	sorted_edges.sort_custom(func(a, b):
		if not is_equal_approx(a.weight, b.weight):
			return a.weight < b.weight
		if a.room_a_id != b.room_a_id:
			return a.room_a_id < b.room_a_id
		return a.room_b_id < b.room_b_id
	)

	var dset = _DisjointSetScript.new(n)

	for edge in sorted_edges:
		var u_idx: int = id_to_index.get(edge.room_a_id, -1)
		var v_idx: int = id_to_index.get(edge.room_b_id, -1)
		if u_idx == -1 or v_idx == -1:
			continue

		if not dset.connected(u_idx, v_idx):
			dset.union(u_idx, v_idx)
			edge.is_mandatory = true
			result.mst_edges.append(edge)
		else:
			result.non_mst_edges.append(edge)

	# Fallback determinista si el grafo candidato quedó con componentes desconectadas:
	if dset.get_component_count() > 1:
		for i in range(n):
			for j in range(i + 1, n):
				if not dset.connected(i, j):
					var p_i := Vector2(rooms[i].get_center())
					var p_j := Vector2(rooms[j].get_center())
					var dist_sq: int = int(p_i.distance_squared_to(p_j))
					var fallback_edge = _CandidateEdgeScript.new(rooms[i].id, rooms[j].id, dist_sq, sqrt(float(dist_sq)), true)
					dset.union(i, j)
					result.mst_edges.append(fallback_edge)

	result.component_count = dset.get_component_count()
	result.is_connected = (result.component_count == 1)
	return result
