class_name GameplayValidator
extends RefCounted

## Game Solver determinista basado en BFS sobre espacio de estados (room_id, inventory_mask).
## Mapea key_id -> key_index para operaciones de bits compactas y rápidas (1 << key_index).
## Simula transiciones a través de RoomConnection con bloqueo bidireccional por LockData.
## 100% puro: no muta geometría ni depende de nodos de escena.

const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")
const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")

func validate_gameplay(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array = [],
	connections: Array = [],
	keys: Array = [],
	locks: Array = [],
	objectives: Array = []
) -> Dictionary:
	# Retorna: {
	#   "is_resolvable": bool,
	#   "solution_trace": Array[Dictionary],
	#   "unreachable_rooms": Array[int],
	#   "unreachable_mandatory_objectives": Array[ObjectiveData],
	#   "unreachable_optional_objectives": Array[ObjectiveData],
	#   "failing_reasons": Array[String]
	# }
	if start_room_id < 0:
		return _fail_result(["Start room is invalid: %d" % start_room_id])

	# 1. Construir Mapeo Compacto key_id -> key_index
	var key_to_index: Dictionary = {} # key_id -> int (0..K-1)
	for i in range(keys.size()):
		var k: KeyData = keys[i]
		if k != null:
			key_to_index[k.key_id] = i

	# 2. Mapear llaves por sala
	var room_keys: Dictionary = {} # room_id -> Array[int (key_index)]
	for i in range(keys.size()):
		var k: KeyData = keys[i]
		if k != null and k.room_id >= 0:
			if not room_keys.has(k.room_id):
				room_keys[k.room_id] = []
			room_keys[k.room_id].append(i)

	# 3. Mapear cerraduras por connection_id
	var conn_locks: Dictionary = {} # connection_id -> LockData
	for l in locks:
		if l != null and l.connection_id >= 0:
			conn_locks[l.connection_id] = l

	# 4. Construir adyacencias
	var adj: Dictionary = {} # room_id -> Array[Dictionary{ "room_id": int, "conn_id": int }]
	for conn in connections:
		if conn == null:
			continue
		if not adj.has(conn.room_a_id):
			adj[conn.room_a_id] = []
		if not adj.has(conn.room_b_id):
			adj[conn.room_b_id] = []
		adj[conn.room_a_id].append({ "room_id": conn.room_b_id, "conn_id": conn.id })
		adj[conn.room_b_id].append({ "room_id": conn.room_a_id, "conn_id": conn.id })

	# 5. Inicializar BFS de estados
	var initial_mask: int = 0
	if room_keys.has(start_room_id):
		for k_idx in room_keys[start_room_id]:
			initial_mask |= (1 << int(k_idx))

	var initial_state := { "room_id": start_room_id, "inventory_mask": initial_mask }
	var queue: Array[Dictionary] = [initial_state]

	var visited: Dictionary = {} # int state_key -> bool
	var state_key: int = (start_room_id << 16) | initial_mask
	visited[state_key] = true

	var reachable_rooms: Dictionary = { start_room_id: true } # room_id -> bool
	var trace: Array[Dictionary] = []

	# Árbol de reconstrucción para trace: state_key -> { parent_key, transition_info }
	var parent_map: Dictionary = {}
	parent_map[state_key] = { "parent_key": 0, "info": { "action": "spawn", "room": start_room_id, "mask": initial_mask } }

	var boss_reached_state_key: int = 0
	if start_room_id == boss_room_id:
		boss_reached_state_key = state_key

	while not queue.is_empty():
		var curr_state: Dictionary = queue.pop_front()
		var curr_room: int = curr_state["room_id"]
		var curr_mask: int = curr_state["inventory_mask"]
		var curr_key: int = (curr_room << 16) | curr_mask

		reachable_rooms[curr_room] = true

		if curr_room == boss_room_id and boss_reached_state_key == 0:
			boss_reached_state_key = curr_key

		var neighbors: Array = adj.get(curr_room, [])
		for n_info in neighbors:
			var next_room: int = n_info["room_id"]
			var c_id: int = n_info["conn_id"]

			# Comprobar si la conexión está bloqueada por un lock
			if conn_locks.has(c_id):
				var lock: LockData = conn_locks[c_id]
				var req_key_id: int = lock.required_key_id
				var req_idx: int = int(key_to_index.get(req_key_id, -1))
				if req_idx == -1 or (curr_mask & (1 << req_idx)) == 0:
					# Cerradura cerrada: el jugador no tiene la llave requerida
					continue

			# Calcular nuevo inventario al entrar a next_room
			var next_mask: int = curr_mask
			if room_keys.has(next_room):
				for k_idx in room_keys[next_room]:
					next_mask |= (1 << int(k_idx))

			var next_state_key: int = (next_room << 16) | next_mask
			if not visited.has(next_state_key):
				visited[next_state_key] = true
				parent_map[next_state_key] = {
					"parent_key": curr_key,
					"info": {
						"action": "move",
						"from_room": curr_room,
						"to_room": next_room,
						"conn_id": c_id,
						"mask": next_mask
					}
				}
				queue.append({ "room_id": next_room, "inventory_mask": next_mask })

	# 6. Reconstruir solution_trace hacia el Boss si fue alcanzado
	if boss_reached_state_key != 0:
		var k_cursor: int = boss_reached_state_key
		while k_cursor != 0 and parent_map.has(k_cursor):
			var node: Dictionary = parent_map[k_cursor]
			trace.append(node["info"])
			k_cursor = node["parent_key"]
		trace.reverse()

	# 7. Evaluar Alcanzabilidad de Salas y Objetivos
	var unreachable_rooms: Array[int] = []
	for r in rooms:
		if not reachable_rooms.has(r.id):
			unreachable_rooms.append(r.id)

	var unreachable_mandatory: Array = []
	var unreachable_optional: Array = []
	for obj in objectives:
		if not reachable_rooms.has(obj.room_id):
			if obj.is_mandatory:
				unreachable_mandatory.append(obj)
			else:
				unreachable_optional.append(obj)

	var failing_reasons: Array[String] = []

	# Boss debe ser alcanzable
	if boss_room_id >= 0 and not reachable_rooms.has(boss_room_id):
		failing_reasons.append("Boss room %d is unreachable from start room %d" % [boss_room_id, start_room_id])

	# Objetivos obligatorios deben ser alcanzables
	if not unreachable_mandatory.is_empty():
		for obj in unreachable_mandatory:
			failing_reasons.append("Mandatory objective '%s' in room %d is unreachable" % [
				_ObjectiveDataScript.type_to_string(obj.type), obj.room_id
			])

	var is_resolvable: bool = failing_reasons.is_empty()

	return {
		"is_resolvable": is_resolvable,
		"solution_trace": trace,
		"unreachable_rooms": unreachable_rooms,
		"unreachable_mandatory_objectives": unreachable_mandatory,
		"unreachable_optional_objectives": unreachable_optional,
		"failing_reasons": failing_reasons
	}

func _fail_result(reasons: Array[String]) -> Dictionary:
	return {
		"is_resolvable": false,
		"solution_trace": [],
		"unreachable_rooms": [],
		"unreachable_mandatory_objectives": [],
		"unreachable_optional_objectives": [],
		"failing_reasons": reasons
	}
