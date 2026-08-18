class_name DoorResolver
extends RefCounted

## Resolvedor arquitectónico determinista de puertas y umbrales (Fase 6).
## Transforma pares de entradas (EntrancePair) y corredores tallados (CorridorPath) en puertas lógicas (CellType.DOOR).
## Implementa el flujo atómico Resolve ALL -> Validate ALL -> Commit ALL.

const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const _DoorResolutionResultScript = preload("res://src/dungeon_generator/core/solvers/door_resolution_result.gd")
const _DoorTransitionValidatorScript = preload("res://src/dungeon_generator/core/validation/door_transition_validator.gd")
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")

## Resuelve y coloca atómicamente todas las puertas del intento de generación.
static func resolve_doors(
	grid: CellGrid,
	rooms: Array[RoomData],
	entrance_pairs: Array,
	corridor_paths: Array,
	connections: Array,
	config: DungeonConfig = null
) -> DoorResolutionResult:
	var result = _DoorResolutionResultScript.new()

	if connections.is_empty():
		result.is_valid = true
		return result

	var conn_map: Dictionary = {}
	var has_required_conns: bool = false
	for c in connections:
		if c != null:
			conn_map[c.id] = c
			if c.is_required:
				has_required_conns = true

	# Si existen conexiones obligatorias pero no hay ningún entrance_pair, fallar inmediatamente
	if entrance_pairs.is_empty():
		if has_required_conns:
			result.add_failure(-1, "MISSING_ENTRANCE_PAIRS")
			return result
		else:
			result.is_valid = true
			return result

	var path_map: Dictionary = {}
	for p in corridor_paths:
		if p != null:
			path_map[p.connection_id] = p

	# --- PASO 1: RESOLVE ALL (Construir candidatos a DoorPair) ---
	var candidate_pairs: Array = []
	var seen_conn_ids: Dictionary = {}

	for ep in entrance_pairs:
		if ep == null or ep.entrance_a == null or ep.entrance_b == null:
			continue

		var conn_id: int = ep.connection_id
		var conn = conn_map.get(conn_id, null)
		if conn == null:
			result.add_failure(conn_id, "ORPHAN_ENTRANCE_PAIR_NO_CONNECTION")
			continue

		var is_required: bool = conn.is_required if ("is_required" in conn) else true

		# 1. Validar correspondencia exacta de identidades EntrancePair ↔ RoomConnection
		var ent_a = ep.entrance_a
		var ent_b = ep.entrance_b

		if ent_a.room_id != conn.room_a_id or ent_b.room_id != conn.room_b_id:
			if is_required:
				result.add_failure(conn_id, "ENTRANCE_ROOM_MISMATCH")
			else:
				result.add_rejection(conn_id, "ENTRANCE_ROOM_MISMATCH")
			continue

		# 2. Detectar duplicados de DoorPair por conexión
		if seen_conn_ids.has(conn_id):
			if is_required:
				result.add_failure(conn_id, "DUPLICATE_DOOR_PAIR")
			else:
				result.add_rejection(conn_id, "DUPLICATE_DOOR_PAIR")
			continue
		seen_conn_ids[conn_id] = true

		# 3. Comprobar que exista un CorridorPath para esta conexión
		var path = path_map.get(conn_id, null)
		if path == null:
			if is_required:
				result.add_failure(conn_id, "NO_CORRIDOR_PATH_FOR_CONNECTION")
			else:
				result.add_rejection(conn_id, "NO_CORRIDOR_PATH_FOR_OPTIONAL")
			continue

		# 4. Verificar que el corredor alcance el outer_cell de ambas entradas y correspondan a los extremos del centerline
		if not path.carved_cells.has(ent_a.outer_cell) or not path.carved_cells.has(ent_b.outer_cell):
			if is_required:
				result.add_failure(conn_id, "CORRIDOR_DOES_NOT_REACH_ENTRANCE")
			else:
				result.add_rejection(conn_id, "CORRIDOR_DOES_NOT_REACH_ENTRANCE")
			continue

		if not path.centerline_cells.is_empty():
			var p_start: Vector2i = path.centerline_cells[0]
			var p_end: Vector2i = path.centerline_cells[-1]
			var is_a_endpoint: bool = (ent_a.outer_cell == p_start or ent_a.outer_cell == p_end)
			var is_b_endpoint: bool = (ent_b.outer_cell == p_start or ent_b.outer_cell == p_end)
			var endpoints_valid: bool = false

			if path.centerline_cells.size() == 1:
				endpoints_valid = (ent_a.outer_cell == p_start and ent_b.outer_cell == p_start)
			else:
				endpoints_valid = is_a_endpoint and is_b_endpoint and (ent_a.outer_cell != ent_b.outer_cell)

			if not endpoints_valid:
				if is_required:
					result.add_failure(conn_id, "DOOR_NOT_AT_CORRIDOR_ENDPOINT")
				else:
					result.add_rejection(conn_id, "DOOR_NOT_AT_CORRIDOR_ENDPOINT")
				continue

		var door_a = _DoorPlacementScript.new(
			conn_id,
			ent_a.room_id,
			ent_a.boundary_cell,
			ent_a.side,
			ent_a.inner_cell,
			ent_a.outer_cell
		)

		var door_b = _DoorPlacementScript.new(
			conn_id,
			ent_b.room_id,
			ent_b.boundary_cell,
			ent_b.side,
			ent_b.inner_cell,
			ent_b.outer_cell
		)

		var room_a = null
		var room_b = null
		for r in rooms:
			if r != null:
				if r.id == conn.room_a_id: room_a = r
				elif r.id == conn.room_b_id: room_b = r

		_apply_door_policy(door_a, door_b, room_a, room_b, path, config, conn_id)

		var dp = _DoorPairScript.new(conn_id, door_a, door_b)
		candidate_pairs.append(dp)

	# Verificar que toda conexión aceptada tenga exactamente 1 DoorPair
	for conn_id in path_map.keys():
		if not seen_conn_ids.has(conn_id):
			var conn = conn_map.get(conn_id, null)
			var is_req: bool = conn.is_required if (conn != null and "is_required" in conn) else true
			if is_req:
				result.add_failure(conn_id, "MISSING_DOOR_PAIR")
			else:
				result.add_rejection(conn_id, "MISSING_DOOR_PAIR")

	# Si alguna conexión obligatoria falló en la etapa de resolución inicial
	if not result.is_valid:
		return result

	# --- PASO 2: VALIDATE ALL (Validación global de transiciones y conflictos) ---
	var val_res := _DoorTransitionValidatorScript.validate_global(
		grid,
		candidate_pairs,
		connections,
		rooms
	)

	if not val_res["is_valid"]:
		var reason: String = val_res.get("reason", "GLOBAL_VALIDATION_FAILED")
		var fallback_id: int = -1
		if not candidate_pairs.is_empty() and candidate_pairs[0] != null:
			fallback_id = candidate_pairs[0].connection_id
		var failed_id: int = int(val_res.get("connection_id", fallback_id))
		push_warning("[DoorResolver] Failed global validation: %s (conn_id: %d, details: %s)" % [reason, failed_id, str(val_res)])
		result.add_failure(failed_id, reason, val_res)
		return result # Cero mutación en CellGrid

	# --- PASO 3: COMMIT ALL (Commit atómico de todas las puertas al CellGrid) ---
	for dp in candidate_pairs:
		grid.set_cell(dp.door_a.position, CellGrid.CellType.DOOR)
		grid.set_cell(dp.door_b.position, CellGrid.CellType.DOOR)

		result.add_door_pair(dp, {
			"connection_id": dp.connection_id,
			"door_a_pos": str(dp.door_a.position),
			"door_b_pos": str(dp.door_b.position),
			"status": "VALID"
		})

	return result

static func _apply_door_policy(
	door_a: _DoorPlacementScript,
	door_b: _DoorPlacementScript,
	room_a: RoomData,
	room_b: RoomData,
	path: RefCounted,
	config: DungeonConfig,
	conn_id: int
) -> void:
	if config == null:
		return

	var base_seed: int = config.seed if config.seed != 0 else 1337
	var conn_seed: int = _DungeonSeedFactoryScript.derive_seed(base_seed, 0, &"door_policy_conn_%d" % conn_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = conn_seed

	var pri_a: int = _get_room_priority(room_a)
	var pri_b: int = _get_room_priority(room_b)
	var corr_len: int = path.centerline_cells.size() if (path != null and "centerline_cells" in path) else 0

	# 1. Pasillo Ultra-Corto (<= threshold, default 3): Máximo 1 puerta física
	if corr_len <= config.short_corridor_single_door_threshold:
		if pri_a >= 4 or pri_b >= 4:
			# Boss o Tesoro siempre exigen puerta física cerrada
			if pri_a >= pri_b:
				door_a.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
				door_b.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
			else:
				door_b.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
				door_a.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
		elif rng.randf() < config.door_open_passage_chance:
			door_a.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
			door_b.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
		else:
			if pri_a > pri_b:
				door_a.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
				door_b.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
			elif pri_b > pri_a:
				door_b.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
				door_a.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
			else:
				if rng.randf() < 0.5:
					door_a.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
					door_b.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
				else:
					door_b.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
					door_a.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
		return

	# 2. Pasillo Largo (>= min_corridor_length_for_double_doors)
	if corr_len >= config.min_corridor_length_for_double_doors and rng.randf() < config.door_double_door_chance:
		door_a.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
		door_b.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
		return

	# 3. Pasillo Estándar
	if pri_a >= 4 or pri_b >= 4:
		if pri_a >= pri_b:
			door_a.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
			door_b.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
		else:
			door_b.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
			door_a.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
	elif rng.randf() < config.door_open_passage_chance:
		door_a.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
		door_b.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
	else:
		if pri_a > pri_b:
			door_a.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
			door_b.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
		elif pri_b > pri_a:
			door_b.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
			door_a.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
		else:
			if rng.randf() < 0.5:
				door_a.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
				door_b.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE
			else:
				door_b.door_type = _DoorTypeScript.DoorType.CLOSED_DOOR
				door_a.door_type = _DoorTypeScript.DoorType.OPEN_PASSAGE

static func _get_room_priority(room: RoomData) -> int:
	if room == null:
		return 0
	match room.room_type:
		&"boss": return 5
		&"treasure": return 4
		&"puzzle": return 3
		&"normal": return 2
		&"start": return 1
		_: return 2
