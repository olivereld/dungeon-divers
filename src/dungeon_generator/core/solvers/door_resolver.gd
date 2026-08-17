class_name DoorResolver
extends RefCounted

## Resolvedor arquitectónico determinista de puertas y umbrales (Fase 6).
## Transforma pares de entradas (EntrancePair) y corredores tallados (CorridorPath) en puertas lógicas (CellType.DOOR).
## Implementa el flujo atómico Resolve ALL -> Validate ALL -> Commit ALL.

const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")
const _DoorResolutionResultScript = preload("res://src/dungeon_generator/core/solvers/door_resolution_result.gd")
const _DoorTransitionValidatorScript = preload("res://src/dungeon_generator/core/validation/door_transition_validator.gd")

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

		# 4. Verificar que el corredor alcance el outer_cell de ambas entradas
		if not path.carved_cells.has(ent_a.outer_cell) or not path.carved_cells.has(ent_b.outer_cell):
			if is_required:
				result.add_failure(conn_id, "CORRIDOR_DOES_NOT_REACH_ENTRANCE")
			else:
				result.add_rejection(conn_id, "CORRIDOR_DOES_NOT_REACH_ENTRANCE")
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
