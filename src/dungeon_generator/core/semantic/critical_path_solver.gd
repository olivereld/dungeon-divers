class_name CriticalPathSolver
extends RefCounted

## Calcula el camino crítico jugable y las dependencias de misión.
## Opera de forma nativa sobre MissionGraph (topología pura de misión, sin dependencia geométrica),
## produciendo una secuencia crítica determinista: START -> A -> B -> OBJECTIVE -> BOSS.
## 100% puro y determinista.

const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const MissionNode = preload("res://src/dungeon_generator/core/data/mission_node.gd")

## Resuelve la ruta crítica directamente sobre el MissionGraph de manera independiente a la geometría espacial.
func solve_mission_critical_path(
	mission_graph: DungeonGraph,
	start_node_id: int = -1,
	boss_node_id: int = -1
) -> Dictionary:
	if mission_graph == null or mission_graph.get_all_node_ids().is_empty():
		return {
			"mission_critical_path": [] as Array[int],
			"start_node_id": -1,
			"boss_node_id": -1,
			"depth_map": {},
			"mandatory_edges": [] as Array[Vector2i]
		}

	var all_nodes: Array[int] = mission_graph.get_all_node_ids()

	# 1. Identificar START si no se especificó
	var start_id: int = start_node_id
	if start_id < 0:
		for nid in all_nodes:
			var nd: Dictionary = mission_graph.get_node_data(nid)
			var m_node: MissionNode = MissionNode.from_dictionary(nd)
			var ntype_lower: String = String(mission_graph.get_node_type(nid)).to_lower()
			if m_node.action == MissionNode.ActionType.START or ntype_lower == "start":
				start_id = nid
				break
	if start_id < 0 and not all_nodes.is_empty():
		start_id = all_nodes[0]

	# 2. Identificar BOSS / Terminal si no se especificó
	var boss_id: int = boss_node_id
	if boss_id < 0:
		for nid in all_nodes:
			var nd: Dictionary = mission_graph.get_node_data(nid)
			var m_node: MissionNode = MissionNode.from_dictionary(nd)
			var ntype_lower: String = String(mission_graph.get_node_type(nid)).to_lower()
			if m_node.action == MissionNode.ActionType.BOSS or ntype_lower == "boss":
				boss_id = nid
				break

	if boss_id < 0:
		for nid in all_nodes:
			var nd: Dictionary = mission_graph.get_node_data(nid)
			var m_node: MissionNode = MissionNode.from_dictionary(nd)
			var ntype_lower: String = String(mission_graph.get_node_type(nid)).to_lower()
			if m_node.action == MissionNode.ActionType.GOAL or m_node.action == MissionNode.ActionType.PASSAGE_DOWN or ntype_lower == "goal":
				boss_id = nid
				break

	var depths: Dictionary = mission_graph.calculate_depths(start_id)

	if boss_id < 0:
		var max_d: int = -1
		for nid in all_nodes:
			var d: int = depths.get(nid, -1)
			if d > max_d:
				max_d = d
				boss_id = nid

	if boss_id < 0 or boss_id == start_id:
		var topo := mission_graph.get_topological_order()
		boss_id = topo[topo.size() - 1] if not topo.is_empty() else start_id

	# 3. Ruta canónica en el grafo de misiones
	var critical_path: Array[int] = mission_graph.get_shortest_path(start_id, boss_id)

	# 4. Identificar aristas obligatorias / puentes en MissionGraph
	var mandatory_edges: Array[Vector2i] = _find_mandatory_mission_edges(mission_graph, start_id, boss_id, critical_path)

	return {
		"mission_critical_path": critical_path,
		"start_node_id": start_id,
		"boss_node_id": boss_id,
		"depth_map": depths,
		"mandatory_edges": mandatory_edges
	}

func _find_mandatory_mission_edges(
	mission_graph: DungeonGraph,
	start_id: int,
	target_id: int,
	critical_path: Array[int]
) -> Array[Vector2i]:
	var bridges: Array[Vector2i] = []
	if critical_path.size() < 2 or start_id == target_id:
		return bridges

	for i in range(critical_path.size() - 1):
		var u: int = critical_path[i]
		var v: int = critical_path[i + 1]
		# BFS omitiendo la arista u <-> v
		if not _is_mission_reachable_without_edge(mission_graph, start_id, target_id, u, v):
			bridges.append(Vector2i(u, v))

	return bridges

func _is_mission_reachable_without_edge(
	mission_graph: DungeonGraph,
	start_id: int,
	target_id: int,
	blocked_u: int,
	blocked_v: int
) -> bool:
	var visited: Dictionary = { start_id: true }
	var queue: Array[int] = [start_id]

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		if curr == target_id:
			return true

		for neighbor in mission_graph.get_neighbors(curr):
			if (curr == blocked_u and neighbor == blocked_v) or (curr == blocked_v and neighbor == blocked_u):
				continue
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)

	return false

## Mapeo y compatibilidad con salas y conexiones físicas
func compute_depth_map(start_room_id: int, rooms: Array = [], connections: Array = []) -> Dictionary:
	var depth_map: Dictionary = {}
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
	connections: Array = [],
	mission_graph: DungeonGraph = null
) -> Dictionary:
	# Si se proporciona mission_graph, priorizar la resolución lógica determinista
	if mission_graph != null:
		var node_to_room: Dictionary = {}
		for r in rooms:
			if r != null and "mission_node_id" in r and r.mission_node_id >= 0:
				node_to_room[r.mission_node_id] = r.id

		var m_res := solve_mission_critical_path(mission_graph)
		var m_path: Array[int] = m_res["mission_critical_path"]
		var mapped_rooms: Array[int] = []
		for nid in m_path:
			if node_to_room.has(nid):
				mapped_rooms.append(node_to_room[nid])

		if mapped_rooms.size() == m_path.size() and not mapped_rooms.is_empty():
			# Mapear conexiones correspondientes
			var mapped_conns: Array[int] = []
			var conn_lookup: Dictionary = {}
			for c in connections:
				if c != null:
					conn_lookup[Vector2i(c.room_a_id, c.room_b_id)] = c.id
					conn_lookup[Vector2i(c.room_b_id, c.room_a_id)] = c.id

			for i in range(mapped_rooms.size() - 1):
				var r_u: int = mapped_rooms[i]
				var r_v: int = mapped_rooms[i + 1]
				var cid: int = conn_lookup.get(Vector2i(r_u, r_v), -1)
				if cid != -1:
					mapped_conns.append(cid)

			var depth_map := compute_depth_map(start_room_id, rooms, connections)
			var mandatory_conns: Array[int] = _find_mandatory_connections(start_room_id, boss_room_id, connections)

			return {
				"critical_path_rooms": mapped_rooms,
				"critical_path_connections": mapped_conns,
				"mandatory_connections": mandatory_conns,
				"depth_map": depth_map,
				"mission_critical_path": m_path
			}

	# Fallback topológico tradicional sobre habitaciones
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
	var parent_map: Dictionary = {}
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
	var bridges: Array[int] = []
	if start_id < 0 or target_id < 0 or start_id == target_id or connections.is_empty():
		return bridges

	var path_res := _find_canonical_path(start_id, target_id, connections)
	var path_conns: Array[int] = path_res["connections"]

	for conn_id in path_conns:
		if not _is_reachable_without_connection(start_id, target_id, conn_id, connections):
			bridges.append(conn_id)

	return bridges

func _is_reachable_without_connection(start_id: int, target_id: int, blocked_conn_id: int, connections: Array = []) -> bool:
	var adj: Dictionary = {}
	for c in connections:
		if c == null or c.id == blocked_conn_id:
			continue
		if not adj.has(c.room_a_id):
			adj[c.room_a_id] = []
		if not adj.has(c.room_b_id):
			adj[c.room_b_id] = []
		adj[c.room_a_id].append(c.room_b_id)
		adj[c.room_b_id].append(c.room_a_id)

	var visited: Dictionary = { start_id: true }
	var queue: Array[int] = [start_id]

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		if curr == target_id:
			return true

		for neighbor in adj.get(curr, []):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)

	return false

func _build_adjacency_dict(connections: Array = []) -> Dictionary:
	var adj: Dictionary = {}
	for c in connections:
		if c == null:
			continue
		if not adj.has(c.room_a_id):
			adj[c.room_a_id] = []
		if not adj.has(c.room_b_id):
			adj[c.room_b_id] = []
		adj[c.room_a_id].append({ "room_id": c.room_b_id, "conn_id": c.id })
		adj[c.room_b_id].append({ "room_id": c.room_a_id, "conn_id": c.id })
	return adj
