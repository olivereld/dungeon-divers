class_name KeyLockPlanner
extends RefCounted

## Planifica y asigna pares de llaves y cerraduras (KeyData / LockData) sobre conexiones concretas.
## Valida de forma tentativa cada combinación con GameplayValidator para garantizar resolubilidad.
## 100% puro y determinista: no muta el CellGrid.

const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")
const _GameplayValidatorScript = preload("res://src/dungeon_generator/core/semantic/gameplay_validator.gd")
const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")
const MAX_PLANNER_ATTEMPTS: int = 10

var _validator := _GameplayValidatorScript.new()

func plan_keys_and_locks(
	start_room_id: int,
	boss_room_id: int,
	rooms: Array = [],
	connections: Array = [],
	critical_path_rooms: Array[int] = [],
	critical_path_connections: Array[int] = [],
	mandatory_connections: Array[int] = [],
	depth_map: Dictionary = {},
	grid: CellGrid = null,
	config: DungeonConfig = null,
	planner_seed: int = 0
) -> Dictionary:
	# Retorna: {
	#   "keys": Array,
	#   "locks": Array,
	#   "is_valid": bool,
	#   "diagnostics": Dictionary
	# }
	var rng := RandomNumberGenerator.new()
	rng.seed = planner_seed

	var freq: float = config.lock_key_frequency if config != null else 0.35
	if freq <= 0.0 or rooms.size() < 3 or (mandatory_connections.is_empty() and critical_path_connections.is_empty()):
		# Sin cerraduras solicitadas o mazmorra muy pequeña
		return { "keys": [], "locks": [], "is_valid": true, "diagnostics": {} }

	# Determinar número deseado de pares (1 a 3 según frecuencia y profundidad)
	var max_desired_pairs: int = 1
	if freq >= 0.6 and rooms.size() >= 8:
		max_desired_pairs = 2
	if freq >= 0.8 and rooms.size() >= 14:
		max_desired_pairs = 3

	# Conexiones candidatas para locks: preferir mandatory_connections que no toquen directamente Start
	var candidate_conns: Array = _get_candidate_lock_connections(
		start_room_id, boss_room_id, connections, mandatory_connections, critical_path_connections, depth_map
	)

	if candidate_conns.is_empty():
		return { "keys": [], "locks": [], "is_valid": true, "diagnostics": {} }

	# Probar configuraciones candidatas
	for attempt in range(MAX_PLANNER_ATTEMPTS):
		var attempt_seed: int = _DungeonSeedFactoryScript.derive_seed(planner_seed, attempt, &"key_lock_attempt")
		var attempt_rng := RandomNumberGenerator.new()
		attempt_rng.seed = attempt_seed

		var trial_result := _generate_trial_configuration(
			start_room_id, boss_room_id, rooms, connections, candidate_conns, depth_map, grid, max_desired_pairs, attempt_rng
		)

		var trial_keys: Array = trial_result["keys"]
		var trial_locks: Array = trial_result["locks"]

		if trial_locks.is_empty():
			continue

		# Validar con GameplayValidator
		var val_result := _validator.validate_gameplay(
			start_room_id, boss_room_id, rooms, connections, trial_keys, trial_locks, []
		)

		if val_result["is_resolvable"]:
			return {
				"keys": trial_keys,
				"locks": trial_locks,
				"is_valid": true,
				"diagnostics": {}
			}

	# Si no se encontró configuración con cerraduras tras N intentos, retornar sin cerraduras de forma segura
	return {
		"keys": [],
		"locks": [],
		"is_valid": true,
		"diagnostics": { "warning": "No valid key-lock placement found after %d attempts; omitted locks." % MAX_PLANNER_ATTEMPTS }
	}

func _get_candidate_lock_connections(
	start_id: int,
	boss_id: int,
	connections: Array = [],
	mandatory_conns: Array[int] = [],
	critical_conns: Array[int] = [],
	depth_map: Dictionary = {}
) -> Array:
	var candidates: Array = []
	var conn_map: Dictionary = {}
	for c in connections:
		if c != null:
			conn_map[c.id] = c

	# Prioridad 1: mandatory_connections (bridges)
	for cid in mandatory_conns:
		if conn_map.has(cid):
			var c = conn_map[cid]
			# Evitar bloquear salidas inmediatas de Start (depth 0)
			var d_a: int = int(depth_map.get(c.room_a_id, 0))
			var d_b: int = int(depth_map.get(c.room_b_id, 0))
			if mini(d_a, d_b) >= 1 and not candidates.has(c):
				candidates.append(c)

	# Prioridad 2: critical_path_connections
	for cid in critical_conns:
		if conn_map.has(cid):
			var c = conn_map[cid]
			var d_a: int = int(depth_map.get(c.room_a_id, 0))
			var d_b: int = int(depth_map.get(c.room_b_id, 0))
			if mini(d_a, d_b) >= 1 and not candidates.has(c):
				candidates.append(c)

	return candidates

func _generate_trial_configuration(
	start_id: int,
	boss_id: int,
	rooms: Array = [],
	connections: Array = [],
	candidate_conns: Array = [],
	depth_map: Dictionary = {},
	grid: CellGrid = null,
	num_pairs: int = 1,
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var trial_keys: Array = []
	var trial_locks: Array = []

	var shuffled_conns: Array = candidate_conns.duplicate()
	# Barajado determinista
	for i in range(shuffled_conns.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = shuffled_conns[i]
		shuffled_conns[i] = shuffled_conns[j]
		shuffled_conns[j] = tmp

	var used_conn_ids: Dictionary = {}
	var used_key_rooms: Dictionary = { start_id: true } # Evitar colocar la llave en Start para mayor riqueza de gameplay
	var key_counter: int = 1

	for conn in shuffled_conns:
		if trial_locks.size() >= num_pairs:
			break
		if used_conn_ids.has(conn.id):
			continue

		var d_a: int = int(depth_map.get(conn.room_a_id, 0))
		var d_b: int = int(depth_map.get(conn.room_b_id, 0))
		var lock_depth: int = maxi(d_a, d_b)

		# Buscar salas candidatas para la llave: depth < lock_depth
		var candidate_key_rooms: Array = []
		for r in rooms:
			if r.id == start_id or r.id == boss_id or used_key_rooms.has(r.id):
				continue
			var r_depth: int = int(depth_map.get(r.id, 999))
			if r_depth < lock_depth:
				candidate_key_rooms.append(r)

		if candidate_key_rooms.is_empty():
			# Fallback: permitir salas de igual profundidad si son distintas
			for r in rooms:
				if r.id == start_id or r.id == boss_id or used_key_rooms.has(r.id):
					continue
				if r.id != conn.room_a_id and r.id != conn.room_b_id:
					candidate_key_rooms.append(r)

		if candidate_key_rooms.is_empty():
			continue

		# Seleccionar sala de llave deterministamente
		var chosen_room: RoomData = candidate_key_rooms[rng.randi_range(0, candidate_key_rooms.size() - 1)]
		used_key_rooms[chosen_room.id] = true
		used_conn_ids[conn.id] = true

		var key_pos: Vector2i = chosen_room.get_walkable_point(grid) if grid != null else chosen_room.get_center()
		var key_obj = _KeyDataScript.new(key_counter, StringName("key_%d" % key_counter), chosen_room.id, key_pos)
		trial_keys.append(key_obj)

		var lock_obj = _LockDataScript.new(key_counter, conn.id, conn.room_a_id, conn.room_b_id, key_counter)
		trial_locks.append(lock_obj)

		key_counter += 1

	return {
		"keys": trial_keys,
		"locks": trial_locks
	}
