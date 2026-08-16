class_name DungeonGraph
extends RefCounted

## Grafo dirigido genérico con metadatos para gramáticas de misión y espaciales.

var _nodes: Dictionary = {}        # int id -> Dictionary {type: StringName, data: Dictionary}
var _adjacency: Dictionary = {}    # int id -> Array[int] (successors)
var _reverse: Dictionary = {}      # int id -> Array[int] (predecessors)
var _next_id: int = 0

func add_node(type: StringName, data: Dictionary = {}) -> int:
	var id: int = _next_id
	_next_id += 1
	_nodes[id] = {
		"type": type,
		"data": data.duplicate(true)
	}
	_adjacency[id] = []
	_reverse[id] = []
	return id

func remove_node(id: int) -> void:
	if not _nodes.has(id):
		return
	
	# Limpiar aristas salientes
	var succs: Array = _adjacency.get(id, []).duplicate()
	for succ in succs:
		remove_edge(id, succ)
		
	# Limpiar aristas entrantes
	var preds: Array = _reverse.get(id, []).duplicate()
	for pred in preds:
		remove_edge(pred, id)
		
	_nodes.erase(id)
	_adjacency.erase(id)
	_reverse.erase(id)

func add_edge(from_id: int, to_id: int, _data: Dictionary = {}) -> void:
	if not _nodes.has(from_id) or not _nodes.has(to_id):
		return
	var succs: Array = _adjacency[from_id]
	if not succs.has(to_id):
		succs.append(to_id)
	var preds: Array = _reverse[to_id]
	if not preds.has(from_id):
		preds.append(from_id)

func remove_edge(from_id: int, to_id: int) -> void:
	if _adjacency.has(from_id):
		_adjacency[from_id].erase(to_id)
	if _reverse.has(to_id):
		_reverse[to_id].erase(from_id)

func has_node(id: int) -> bool:
	return _nodes.has(id)

func has_edge(from_id: int, to_id: int) -> bool:
	if not _adjacency.has(from_id):
		return false
	return _adjacency[from_id].has(to_id)

func get_node_type(id: int) -> StringName:
	if _nodes.has(id):
		return _nodes[id]["type"]
	return &""

func set_node_type(id: int, type: StringName) -> void:
	if _nodes.has(id):
		_nodes[id]["type"] = type

func get_node_data(id: int) -> Dictionary:
	if _nodes.has(id):
		return _nodes[id]["data"]
	return {}

func set_node_data(id: int, key: String, value: Variant) -> void:
	if _nodes.has(id):
		_nodes[id]["data"][key] = value

func get_successors(id: int) -> Array[int]:
	if _adjacency.has(id):
		var res: Array[int] = []
		for target in _adjacency[id]:
			res.append(int(target))
		return res
	return []

func get_predecessors(id: int) -> Array[int]:
	if _reverse.has(id):
		var res: Array[int] = []
		for src in _reverse[id]:
			res.append(int(src))
		return res
	return []

func get_all_node_ids() -> Array[int]:
	var result: Array[int] = []
	for id in _nodes.keys():
		result.append(int(id))
	return result

func find_nodes_by_type(type: StringName) -> Array[int]:
	var result: Array[int] = []
	for id in _nodes.keys():
		if _nodes[id]["type"] == type:
			result.append(int(id))
	return result

func get_node_count() -> int:
	return _nodes.size()

func get_edge_count() -> int:
	var count: int = 0
	for from_id in _adjacency.keys():
		count += _adjacency[from_id].size()
	return count

## Encuentra coincidencias de subgrafos basadas en patrón.
## pattern_nodes: Array[Dictionary] con {id: int, type: StringName, match_any: bool}
## pattern_edges: Array[Dictionary] con {from: int, to: int}
func find_matching_subgraph(pattern_nodes: Array, pattern_edges: Array) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	if pattern_nodes.is_empty():
		return matches

	var pattern_node_ids: Array[int] = []
	for pn in pattern_nodes:
		pattern_node_ids.append(int(pn["id"]))

	# Buscar combinaciones que satisfagan el patrón (Backtracking)
	var current_mapping: Dictionary = {} # pattern_id -> graph_id
	_match_recursive(0, pattern_nodes, pattern_edges, current_mapping, matches)
	return matches

func _match_recursive(index: int, pattern_nodes: Array, pattern_edges: Array, current_mapping: Dictionary, results: Array[Dictionary]) -> void:
	if index >= pattern_nodes.size():
		# Validar todas las aristas
		for pe in pattern_edges:
			var g_from: int = current_mapping[pe["from"]]
			var g_to: int = current_mapping[pe["to"]]
			if not has_edge(g_from, g_to):
				return
		results.append(current_mapping.duplicate())
		return

	var p_node: Dictionary = pattern_nodes[index]
	var p_id: int = int(p_node["id"])
	var p_type: StringName = p_node.get("type", &"")
	var match_any: bool = p_node.get("match_any", false)

	for g_id in _nodes.keys():
		var int_g_id: int = int(g_id)
		# Evitar asignar el mismo nodo a dos nodos del patrón
		if current_mapping.values().has(int_g_id):
			continue

		var g_type: StringName = _nodes[int_g_id]["type"]
		if match_any or g_type == p_type or p_type == &"*":
			# Comprobación de aristas parciales si ya se asignaron extremos
			var edge_ok := true
			for pe in pattern_edges:
				if pe["from"] == p_id and current_mapping.has(pe["to"]):
					if not has_edge(int_g_id, current_mapping[pe["to"]]):
						edge_ok = false
						break
				if pe["to"] == p_id and current_mapping.has(pe["from"]):
					if not has_edge(current_mapping[pe["from"]], int_g_id):
						edge_ok = false
						break
			if edge_ok:
				current_mapping[p_id] = int_g_id
				_match_recursive(index + 1, pattern_nodes, pattern_edges, current_mapping, results)
				current_mapping.erase(p_id)

func is_reachable(from_id: int, to_id: int) -> bool:
	if from_id == to_id:
		return true
	if not has_node(from_id) or not has_node(to_id):
		return false
	
	var visited: Dictionary = {from_id: true}
	var queue: Array[int] = [from_id]

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		if curr == to_id:
			return true
		for succ in get_successors(curr):
			if not visited.has(succ):
				visited[succ] = true
				queue.append(succ)
	return false

func get_shortest_path(from_id: int, to_id: int) -> Array[int]:
	if not has_node(from_id) or not has_node(to_id):
		return []
	if from_id == to_id:
		return [from_id]

	var parent: Dictionary = {}
	var visited: Dictionary = {from_id: true}
	var queue: Array[int] = [from_id]

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		if curr == to_id:
			var path: Array[int] = []
			var trace: int = to_id
			while trace != from_id:
				path.push_front(trace)
				trace = parent[trace]
			path.push_front(from_id)
			return path

		for succ in get_successors(curr):
			if not visited.has(succ):
				visited[succ] = true
				parent[succ] = curr
				queue.append(succ)

	return []

func get_topological_order() -> Array[int]:
	var in_degree: Dictionary = {}
	for id in _nodes.keys():
		in_degree[int(id)] = get_predecessors(int(id)).size()

	var queue: Array[int] = []
	for id in in_degree.keys():
		if in_degree[id] == 0:
			queue.append(id)

	var order: Array[int] = []
	while not queue.is_empty():
		var curr: int = queue.pop_front()
		order.append(curr)
		for succ in get_successors(curr):
			in_degree[succ] -= 1
			if in_degree[succ] == 0:
				queue.append(succ)

	return order

func duplicate_graph() -> DungeonGraph:
	var copy := DungeonGraph.new()
	copy._next_id = _next_id
	for id in _nodes.keys():
		var int_id: int = int(id)
		copy._nodes[int_id] = {
			"type": _nodes[int_id]["type"],
			"data": _nodes[int_id]["data"].duplicate(true)
		}
		copy._adjacency[int_id] = _adjacency[int_id].duplicate()
		copy._reverse[int_id] = _reverse[int_id].duplicate()
	return copy
