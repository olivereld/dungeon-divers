class_name GameplayValidator
extends RefCounted

## Game Solver y Validador determinista de jugabilidad (winnability) de Fase 6.
## Determina si una mazmorra es verdaderamente completable por el jugador y no sólo topológicamente conectada.
##
## Preguntas lógicas resueltas:
## 1. ¿Existe un camino desde START -> BOSS?
## 2. ¿Son alcanzables todos los Objetivos obligatorios desde START?
## 3. ¿Son alcanzables las LLAVES antes de sus respectivas CERRADURAS? (Detección de dependencias circulares)
## 4. ¿Puede abrirse la CERRADURA con la LLAVE adquirida?
## 5. ¿Continúa la progresión tras abrir la CERRADURA (LOCK -> BOSS)?
##
## Utiliza un motor de exploración basado en espacio de estados: State = (current_room, acquired_keys).
## 100% puro y determinista.

const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")
const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")
const _GameplayValidationResultScript = preload("res://src/dungeon_generator/core/semantic/data/gameplay_validation_result.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")

## Punto de entrada formal para validar un DungeonSemanticResult completo.
func validate(semantic_result: RefCounted) -> _GameplayValidationResultScript:
	if semantic_result == null:
		var empty_res := _GameplayValidationResultScript.new()
		empty_res.valid = false
		empty_res.failure_reason = "DungeonSemanticResult is null"
		empty_res.failing_reasons = ["DungeonSemanticResult is null"]
		empty_res.seal()
		return empty_res

	return _evaluate_gameplay(
		semantic_result.start_room_id,
		semantic_result.boss_room_id,
		semantic_result.rooms,
		semantic_result.connections,
		semantic_result.keys,
		semantic_result.locks,
		semantic_result.objectives
	)

## API compatible con versiones anteriores y solvers auxiliares (KeyLockPlanner).
func validate_gameplay(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array = [],
	connections: Array = [],
	keys: Array = [],
	locks: Array = [],
	objectives: Array = []
) -> Dictionary:
	var val_res := _evaluate_gameplay(
		start_room_id,
		boss_room_id,
		rooms,
		connections,
		keys,
		locks,
		objectives
	)

	return {
		"is_resolvable": val_res.valid,
		"solution_trace": val_res.solution_trace,
		"unreachable_rooms": val_res.unreachable_rooms,
		"unreachable_mandatory_objectives": val_res.unreachable_objectives,
		"unreachable_optional_objectives": val_res.unreachable_optional_objectives,
		"failing_reasons": val_res.failing_reasons,
		"validation_result": val_res
	}

## Motor de exploración C2 y orquestación C1
func _evaluate_gameplay(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array = [],
	connections: Array = [],
	keys: Array = [],
	locks: Array = [],
	objectives: Array = []
) -> _GameplayValidationResultScript:
	var result := _GameplayValidationResultScript.new()
	var failing_reasons: Array[String] = []
	var unreachable_objectives: Array = []
	var unavailable_keys: Array = []
	var blocked_locks: Array = []

	# 1. Validación de entradas básicas
	if start_room_id < 0:
		failing_reasons.append("Start room is invalid: %d" % start_room_id)
		result.valid = false
		result.failure_reason = failing_reasons[0]
		result.failing_reasons = failing_reasons
		result.seal()
		return result

	# Mapeo de RoomConnection
	var adj: Dictionary = {}
	var conn_map: Dictionary = {}
	for c in connections:
		if c == null:
			continue
		conn_map[c.id] = c
		if not adj.has(c.room_a_id): adj[c.room_a_id] = []
		if not adj.has(c.room_b_id): adj[c.room_b_id] = []
		adj[c.room_a_id].append({ "room_id": c.room_b_id, "conn_id": c.id })
		adj[c.room_b_id].append({ "room_id": c.room_a_id, "conn_id": c.id })

	# Ordenar adyacencias deterministamente
	for r_id in adj:
		(adj[r_id] as Array).sort_custom(func(a, b): return a["room_id"] < b["room_id"])

	# 2. Mapeo de Llaves y Cerraduras
	var key_to_index: Dictionary = {}
	var key_by_id: Dictionary = {}
	var room_keys: Dictionary = {}
	for i in range(keys.size()):
		var k: KeyData = keys[i]
		if k != null:
			key_to_index[k.id] = i
			key_by_id[k.id] = k
			if k.room_id >= 0:
				if not room_keys.has(k.room_id):
					room_keys[k.room_id] = []
				room_keys[k.room_id].append(k)

	var conn_locks: Dictionary = {}
	var lock_by_id: Dictionary = {}
	for l in locks:
		if l != null:
			lock_by_id[l.id] = l
			if l.connection_id >= 0:
				conn_locks[l.connection_id] = l

	# -------------------------------------------------------------
	# C1 - Pregunta 3: Verificación Explícita de Dependencias Circulares
	# (Llave alcanzable sólo tras pasar por su propio lock)
	# -------------------------------------------------------------
	for k in keys:
		if k == null or k.room_id < 0:
			continue
		var target_lock_id: int = k.unlocks
		var matching_lock: LockData = lock_by_id.get(target_lock_id, null)
		if matching_lock == null:
			for l in locks:
				if l.required_key_id == k.id:
					matching_lock = l
					break

		if matching_lock != null and matching_lock.connection_id >= 0:
			var lock_cid: int = matching_lock.connection_id
			# 1. Comprobar si la llave es inalcanzable topológicamente
			if not _is_room_reachable_without_conn(start_room_id, k.room_id, -1, connections):
				var reason := "Key %d in room %d is unreachable from start room %d" % [
					k.id, k.room_id, start_room_id
				]
				failing_reasons.append(reason)
				if not unavailable_keys.has(k):
					unavailable_keys.append(k)
				if not blocked_locks.has(matching_lock):
					blocked_locks.append(matching_lock)
			# 2. Comprobar si existe dependencia circular (atrapada detrás de su propio lock)
			elif not _is_room_reachable_without_conn(start_room_id, k.room_id, lock_cid, connections):
				var reason := "Circular dependency detected: Key %d in room %d is trapped behind its own Lock %d on connection %d" % [
					k.id, k.room_id, matching_lock.id, lock_cid
				]
				failing_reasons.append(reason)
				if not unavailable_keys.has(k):
					unavailable_keys.append(k)
				if not blocked_locks.has(matching_lock):
					blocked_locks.append(matching_lock)

	# -------------------------------------------------------------
	# C2: State-driven Exploration Engine (Key/Lock Solver)
	# State = (current_room, acquired_keys_mask)
	# -------------------------------------------------------------
	var initial_mask: int = 0
	if room_keys.has(start_room_id):
		for k in room_keys[start_room_id]:
			var k_idx: int = int(key_to_index.get(k.id, -1))
			if k_idx >= 0:
				initial_mask |= (1 << k_idx)

	var initial_state := { "room_id": start_room_id, "inventory_mask": initial_mask }
	var queue: Array[Dictionary] = [initial_state]

	var visited: Dictionary = {} # (room_id << 16) | mask -> bool
	var state_key: int = (start_room_id << 16) | initial_mask
	visited[state_key] = true

	var reachable_rooms: Dictionary = { start_room_id: true }
	var opened_lock_ids: Dictionary = {}
	var encountered_lock_ids: Dictionary = {}
	var collected_key_ids: Dictionary = {}

	if room_keys.has(start_room_id):
		for k in room_keys[start_room_id]:
			collected_key_ids[k.id] = true

	var parent_map: Dictionary = {}
	parent_map[state_key] = {
		"parent_key": -1,
		"room": start_room_id,
		"action": "spawn",
		"conn_id": -1
	}

	var boss_reached_state_key: int = -1
	if start_room_id == boss_room_id:
		boss_reached_state_key = state_key

	while not queue.is_empty():
		var curr_state: Dictionary = queue.pop_front()
		var curr_room: int = curr_state["room_id"]
		var curr_mask: int = curr_state["inventory_mask"]
		var curr_key: int = (curr_room << 16) | curr_mask

		reachable_rooms[curr_room] = true

		if curr_room == boss_room_id and boss_reached_state_key == -1:
			boss_reached_state_key = curr_key

		var neighbors: Array = adj.get(curr_room, [])
		for n_info in neighbors:
			var next_room: int = n_info["room_id"]
			var c_id: int = n_info["conn_id"]

			# C1 - Pregunta 4: ¿Puede abrirse la cerradura con la llave adquirida?
			if conn_locks.has(c_id):
				var lock: LockData = conn_locks[c_id]
				encountered_lock_ids[lock.id] = true
				var req_key_id: int = lock.required_key_id
				var req_idx: int = int(key_to_index.get(req_key_id, -1))
				if req_idx == -1 or (curr_mask & (1 << req_idx)) == 0:
					# Cerradura bloqueada: no se posee la llave requerida
					continue
				opened_lock_ids[lock.id] = true

			# C2: Transición de estado y recolección de llaves al visitar next_room
			var next_mask: int = curr_mask
			if room_keys.has(next_room):
				for k in room_keys[next_room]:
					var k_idx: int = int(key_to_index.get(k.id, -1))
					if k_idx >= 0:
						next_mask |= (1 << k_idx)
						collected_key_ids[k.id] = true

			var next_state_key: int = (next_room << 16) | next_mask
			if not visited.has(next_state_key):
				visited[next_state_key] = true
				parent_map[next_state_key] = {
					"parent_key": curr_key,
					"room": next_room,
					"action": "move",
					"conn_id": c_id
				}
				queue.append({ "room_id": next_room, "inventory_mask": next_mask })

	# -------------------------------------------------------------
	# C1 - Pregunta 1 y 5: ¿Existe camino START -> BOSS y continúa la progresión tras abrir locks?
	# -------------------------------------------------------------
	if boss_room_id >= 0 and not reachable_rooms.has(boss_room_id):
		# Identificar cerraduras bloqueadas que impiden el paso
		for l in locks:
			if not opened_lock_ids.has(l.id):
				if not blocked_locks.has(l):
					blocked_locks.append(l)
		for k in keys:
			if not collected_key_ids.has(k.id):
				if not unavailable_keys.has(k):
					unavailable_keys.append(k)

		if not blocked_locks.is_empty():
			failing_reasons.append("Boss room %d is unreachable from start room %d due to %d blocked lock(s)" % [
				boss_room_id, start_room_id, blocked_locks.size()
			])
		else:
			failing_reasons.append("No path exists from START (%d) to BOSS (%d)" % [start_room_id, boss_room_id])

	# -------------------------------------------------------------
	# C1 - Pregunta 2: ¿Son alcanzables todos los Objetivos obligatorios?
	# -------------------------------------------------------------
	var unreachable_optional_objectives: Array = []
	for obj in objectives:
		if obj == null:
			continue
		if obj.required:
			if not reachable_rooms.has(obj.room_id):
				unreachable_objectives.append(obj)
				failing_reasons.append("Mandatory objective '%s' in room %d is unreachable" % [
					_ObjectiveDataScript.type_to_string(obj.type), obj.room_id
				])
		else:
			if not reachable_rooms.has(obj.room_id):
				unreachable_optional_objectives.append(obj)

	# -------------------------------------------------------------
	# Reconstruir Camino Crítico Jugable Real (Playable Critical Path)
	# -------------------------------------------------------------
	var critical_path: Array[int] = []
	var solution_trace: Array[Dictionary] = []

	if boss_reached_state_key != -1:
		var curr_k: int = boss_reached_state_key
		while curr_k != -1 and parent_map.has(curr_k):
			var step_info: Dictionary = parent_map[curr_k]
			critical_path.append(step_info["room"])
			solution_trace.append(step_info)
			curr_k = step_info["parent_key"]
		critical_path.reverse()
		solution_trace.reverse()

	# -------------------------------------------------------------
	# C3: Ensamblado y Sellado de GameplayValidationResult
	# -------------------------------------------------------------
	var unreached_room_ids: Array[int] = []
	for r in rooms:
		if r != null and not reachable_rooms.has(r.id):
			unreached_room_ids.append(r.id)

	result.valid = failing_reasons.is_empty()
	result.failure_reason = failing_reasons[0] if not failing_reasons.is_empty() else ""
	result.failing_reasons = failing_reasons
	result.critical_path = critical_path
	result.unreachable_objectives = unreachable_objectives
	result.unreachable_optional_objectives = unreachable_optional_objectives
	result.unavailable_keys = unavailable_keys
	result.blocked_locks = blocked_locks
	result.unreachable_rooms = unreached_room_ids
	result.solution_trace = solution_trace
	result.seal()

	return result

func _is_room_reachable_without_conn(start_id: int, target_room_id: int, blocked_conn_id: int, connections: Array) -> bool:
	if start_id == target_room_id:
		return true

	var adj: Dictionary = {}
	for c in connections:
		if c == null or c.id == blocked_conn_id:
			continue
		if not adj.has(c.room_a_id): adj[c.room_a_id] = []
		if not adj.has(c.room_b_id): adj[c.room_b_id] = []
		adj[c.room_a_id].append(c.room_b_id)
		adj[c.room_b_id].append(c.room_a_id)

	var visited: Dictionary = { start_id: true }
	var queue: Array[int] = [start_id]

	while not queue.is_empty():
		var curr: int = queue.pop_front()
		if curr == target_room_id:
			return true
		for neighbor in adj.get(curr, []):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)

	return false
