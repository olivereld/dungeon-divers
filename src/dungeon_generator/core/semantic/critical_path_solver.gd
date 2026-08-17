class_name CriticalPathSolver
extends RefCounted

## Calcula el mapa de profundidades, la ruta canónica y las aristas puente (mandatory_connections).
## 100% puro y determinista.

func compute_depth_map(start_room_id: int, rooms: Array = [], connections: Array = []) -> Dictionary:
	var depth_map: Dictionary = {} # room_id -> int
	if start_room_id < 0:
		return depth_map

	var adj: Dictionary = _build_adjacency_dict(connections)
	var queue: Array[int] = [start_room_id]
	depth_map[start_room_id] = 0

	while not queue.is_empty():
		var curr_id: int = queue.pop_front()
		var curr_depth: int = int(depth_map[curr_id])
		var neighbors: Array = adj.get(curr_id, [])

		for neighbor_info in neighbors:
			var neighbor_id: int = neighbor_info["room_id"]
			if not depth_map.has(neighbor_id):
				depth_map[neighbor_id] = curr_depth + 1
				queue.append(neighbor_id)

	return depth_map

func solve_critical_path(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array = [],
	connections: Array = []
) -> Dictionary:
	# Retorna: {
	#   "critical_path_rooms": Array[int],
	#   "critical_path_connections": Array[int],
	#   "mandatory_connections": Array[int],
	#   "depth_map": Dictionary
	# }
	var depth_map := compute_depth_map(start_room_id, rooms, connections)

	var path_rooms: Array[int] = []
	var path_conns: Array[int] = []

	if start_room_id >= 0 and boss_room_id >= 0:
		var path_result := _find_canonical_path(start_room_id, boss_room_id, connections)
		path_rooms = path_result["rooms"]
		path_conns = path_result["connections"]

	var mandatory_conns: Array[int] = _find_mandatory_connections(start_room_id, boss_room_id, connections)

	return {
		"critical_path_rooms": path_rooms,
		"critical_path_connections": path_conns,
		"mandatory_connections": mandatory_conns,
		"depth_map": depth_map
	}

func _find_canonical_path(start_id: int, target_id: int, connections: Array = []) -> Dictionary:
	if start_id == target_id:
		return { "rooms": [start_id] as Array[int], "connections": [] as Array[int] }

	var adj: Dictionary = _build_adjacency_dict(connections)
	var queue: Array[int] = [start_id]
	var parent_map: Dictionary = {} # room_id -> { "parent_id": int, "conn_id": int }
	parent_map[start_id] = { "parent_id": -1, "conn_id": -1 }

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		if curr == target_id:
			break

		var neighbors: Array = adj.get(curr, [])
		for n_info in neighbors:
			var n_id: int = n_info["room_id"]
			var c_id: int = n_info["conn_id"]
			if not parent_map.has(n_id):
				parent_map[n_id] = { "parent_id": curr, "conn_id": c_id }
				queue.append(n_id)

	if not parent_map.has(target_id):
		return { "rooms": [] as Array[int], "connections": [] as Array[int] }

	# Reconstruir camino desde target_id hacia start_id
	var r_list: Array[int] = []
	var c_list: Array[int] = []
	var curr_node: int = target_id

	while curr_node != -1:
		r_list.append(curr_node)
		var p_info: Dictionary = parent_map[curr_node]
		if p_info["conn_id"] != -1:
			c_list.append(p_info["conn_id"])
		curr_node = p_info["parent_id"]

	r_list.reverse()
	c_list.reverse()

	return { "rooms": r_list, "connections": c_list }

func _find_mandatory_connections(start_id: int, target_id: int, connections: Array = []) -> Array[int]:
	var mandatory: Array[int] = []
	if start_id < 0 or target_id < 0 or start_id == target_id:
		return mandatory

	for test_conn in connections:
		if test_conn == null:
			continue
		# Probar si target_id sigue siendo alcanzable desde start_id omitiendo test_conn.id
		if not _is_reachable_without_connection(start_id, target_id, connections, test_conn.id):
			mandatory.append(test_conn.id)

	return mandatory

func _is_reachable_without_connection(
	start_id: int,
	target_id: int,
	connections: Array = [],
	excluded_conn_id: int = -1
) -> bool:
	var adj: Dictionary = _build_adjacency_dict(connections, excluded_conn_id)
	var queue: Array[int] = [start_id]
	var visited: Dictionary = { start_id: true }

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		if curr == target_id:
			return true

		var neighbors: Array = adj.get(curr, [])
		for n_info in neighbors:
			var n_id: int = n_info["room_id"]
			if not visited.has(n_id):
				visited[n_id] = true
				queue.append(n_id)

	return false

func _build_adjacency_dict(connections: Array = [], excluded_conn_id: int = -1) -> Dictionary:
	var adj: Dictionary = {} # room_id -> Array[Dictionary{ "room_id": int, "conn_id": int }]
	for conn in connections:
		if conn == null or conn.id == excluded_conn_id:
			continue
		if not adj.has(conn.room_a_id):
			adj[conn.room_a_id] = []
		if not adj.has(conn.room_b_id):
			adj[conn.room_b_id] = []

		adj[conn.room_a_id].append({ "room_id": conn.room_b_id, "conn_id": conn.id })
		adj[conn.room_b_id].append({ "room_id": conn.room_a_id, "conn_id": conn.id })
	return adj
