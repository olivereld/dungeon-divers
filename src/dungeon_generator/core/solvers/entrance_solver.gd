class_name EntranceSolver
extends RefCounted

## Solver arquitectónico y geométrico de entradas de habitación (Fase 4).
## Resuelve pares de entradas físicas lógicas (EntrancePair) a partir de RoomConnections topológicas.
## 100% determinista, desacoplado del renderer, sin A*, sin mutación de CellGrid y sin puertas físicas.

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _EntrancePairScript = preload("res://src/dungeon_generator/core/data/entrance_pair.gd")
const _EntranceCandidateScript = preload("res://src/dungeon_generator/core/solvers/entrance_candidate.gd")
const _EntranceResolutionResultScript = preload("res://src/dungeon_generator/core/solvers/entrance_resolution_result.gd")

## Resuelve las entradas para un conjunto de habitaciones y conexiones topológicas.
static func resolve(
	rooms: Array[RoomData],
	connections: Array,
	grid: CellGrid,
	config: DungeonConfig = null,
	corridor_plan = null
) -> EntranceResolutionResult:
	var result = _EntranceResolutionResultScript.new()

	if rooms.is_empty() or connections.is_empty():
		result.is_valid = true
		return result

	var cfg := config
	if cfg == null:
		cfg = DungeonConfig.new()

	var corner_margin: int = cfg.corner_margin if "corner_margin" in cfg else 1
	var min_spacing: int = cfg.minimum_entrance_spacing if "minimum_entrance_spacing" in cfg else 2

	# 1. Mapear habitaciones por ID para acceso rápido
	var room_map: Dictionary = {}
	for r in rooms:
		if r != null:
			room_map[r.id] = r

	# 2. Pre-generar candidatos por habitación
	var candidates_by_room: Dictionary = {}
	for r in rooms:
		if r != null:
			candidates_by_room[r.id] = generate_candidates(r, grid, corner_margin)

	# 3. Estructurar y ordenar conexiones por prioridad (consumiendo prioridad semántica del plan si existe)
	var sorted_conns: Array = _sort_connections_by_priority(connections, room_map, candidates_by_room, corridor_plan)

	# 4. Estado de reservas por habitación
	var reserved_positions: Dictionary = {}
	var all_reserved_positions: Dictionary = {} # Vector2i -> bool
	var reserved_sides: Dictionary = {}
	var reserved_approaches: Dictionary = {}
	for r in rooms:
		if r != null:
			reserved_positions[r.id] = []
			reserved_sides[r.id] = {}
			reserved_approaches[r.id] = []

	# 5. Resolver cada conexión
	for conn in sorted_conns:
		if conn == null:
			continue

		var room_a: RoomData = room_map.get(conn.room_a_id, null)
		var room_b: RoomData = room_map.get(conn.room_b_id, null)

		if room_a == null or room_b == null:
			if conn.is_required:
				result.add_failure(conn.id, "ROOM_NOT_FOUND", {"room_a": conn.room_a_id, "room_b": conn.room_b_id})
			else:
				result.add_rejection(conn.id, "ROOM_NOT_FOUND", {"room_a": conn.room_a_id, "room_b": conn.room_b_id})
			continue

		var cands_a: Array[EntranceCandidate] = []
		var raw_cands_a = candidates_by_room.get(conn.room_a_id, [])
		for ca in raw_cands_a:
			cands_a.append(ca)

		var cands_b: Array[EntranceCandidate] = []
		var raw_cands_b = candidates_by_room.get(conn.room_b_id, [])
		for cb in raw_cands_b:
			cands_b.append(cb)

		if cands_a.is_empty() or cands_b.is_empty():
			if conn.is_required:
				result.add_failure(conn.id, "NO_CANDIDATES_AVAILABLE", {"cands_a": cands_a.size(), "cands_b": cands_b.size()})
			else:
				result.add_rejection(conn.id, "NO_CANDIDATES_AVAILABLE", {"cands_a": cands_a.size(), "cands_b": cands_b.size()})
			continue

		# Evaluar todos los pares posibles de candidatos
		var best_pair_candidate: Dictionary = _find_best_candidate_pair(
			cands_a,
			cands_b,
			room_a,
			room_b,
			conn,
			reserved_positions,
			all_reserved_positions,
			reserved_sides,
			reserved_approaches,
			min_spacing,
			cfg
		)

		if best_pair_candidate.is_empty() or best_pair_candidate["is_invalid"]:
			if conn.is_required:
				result.add_failure(conn.id, "NO_VALID_CANDIDATE_PAIR", best_pair_candidate)
			else:
				result.add_rejection(conn.id, "NO_VALID_CANDIDATE_PAIR", best_pair_candidate)
			continue

		# Crear los contratos definitivos de entrada
		var cand_a: EntranceCandidate = best_pair_candidate["cand_a"]
		var cand_b: EntranceCandidate = best_pair_candidate["cand_b"]
		var score: float = best_pair_candidate["score"]

		var ent_a: RoomEntrance = cand_a.to_entrance(conn.id)
		var ent_b: RoomEntrance = cand_b.to_entrance(conn.id)

		var pair = _EntrancePairScript.new(conn.id, ent_a, ent_b, score)
		result.add_pair(pair, {
			"connection_id": conn.id,
			"room_a": conn.room_a_id,
			"room_b": conn.room_b_id,
			"entrance_a_pos": str(ent_a.position),
			"entrance_a_side": _RoomEntranceScript.side_to_string(ent_a.side),
			"entrance_b_pos": str(ent_b.position),
			"entrance_b_side": _RoomEntranceScript.side_to_string(ent_b.side),
			"score": score,
			"status": "VALID"
		})

		# Reservar las posiciones y lados seleccionados
		reserved_positions[conn.room_a_id].append(ent_a.position)
		reserved_positions[conn.room_b_id].append(ent_b.position)
		all_reserved_positions[ent_a.position] = true
		all_reserved_positions[ent_b.position] = true

		reserved_sides[conn.room_a_id][ent_a.side] = reserved_sides[conn.room_a_id].get(ent_a.side, 0) + 1
		reserved_sides[conn.room_b_id][ent_b.side] = reserved_sides[conn.room_b_id].get(ent_b.side, 0) + 1

		reserved_approaches[conn.room_a_id].append(ent_a.outer_cell)
		reserved_approaches[conn.room_b_id].append(ent_b.outer_cell)

	return result

## Genera candidatos perimetrales para una habitación en sus 4 lados cardinales.
static func generate_candidates(room: RoomData, grid: CellGrid, corner_margin: int) -> Array[EntranceCandidate]:
	var candidates: Array[EntranceCandidate] = []
	var r: Rect2i = room.rect

	# NORTH (y = r.position.y - 1)
	var north_y: int = r.position.y - 1
	var min_x_n: int = r.position.x + corner_margin
	var max_x_n: int = r.end.x - 1 - corner_margin
	if min_x_n > max_x_n:
		# En salas pequeñas donde no cabe margen, permitir al menos el centro
		min_x_n = r.position.x + (r.size.x / 2)
		max_x_n = min_x_n

	for x in range(min_x_n, max_x_n + 1):
		var pos := Vector2i(x, north_y)
		var inner := Vector2i(x, r.position.y)
		var outer := Vector2i(x, north_y - 1)
		if _is_candidate_valid(pos, inner, outer, grid):
			candidates.append(_EntranceCandidateScript.new(
				room.id,
				_RoomEntranceScript.NORTH,
				pos,
				inner,
				outer
			))

	# SOUTH (y = r.end.y)
	var south_y: int = r.end.y
	var min_x_s: int = r.position.x + corner_margin
	var max_x_s: int = r.end.x - 1 - corner_margin
	if min_x_s > max_x_s:
		min_x_s = r.position.x + (r.size.x / 2)
		max_x_s = min_x_s

	for x in range(min_x_s, max_x_s + 1):
		var pos := Vector2i(x, south_y)
		var inner := Vector2i(x, r.end.y - 1)
		var outer := Vector2i(x, south_y + 1)
		if _is_candidate_valid(pos, inner, outer, grid):
			candidates.append(_EntranceCandidateScript.new(
				room.id,
				_RoomEntranceScript.SOUTH,
				pos,
				inner,
				outer
			))

	# WEST (x = r.position.x - 1)
	var west_x: int = r.position.x - 1
	var min_y_w: int = r.position.y + corner_margin
	var max_y_w: int = r.end.y - 1 - corner_margin
	if min_y_w > max_y_w:
		min_y_w = r.position.y + (r.size.y / 2)
		max_y_w = min_y_w

	for y in range(min_y_w, max_y_w + 1):
		var pos := Vector2i(west_x, y)
		var inner := Vector2i(r.position.x, y)
		var outer := Vector2i(west_x - 1, y)
		if _is_candidate_valid(pos, inner, outer, grid):
			candidates.append(_EntranceCandidateScript.new(
				room.id,
				_RoomEntranceScript.WEST,
				pos,
				inner,
				outer
			))

	# EAST (x = r.end.x)
	var east_x: int = r.end.x
	var min_y_e: int = r.position.y + corner_margin
	var max_y_e: int = r.end.y - 1 - corner_margin
	if min_y_e > max_y_e:
		min_y_e = r.position.y + (r.size.y / 2)
		max_y_e = min_y_e

	for y in range(min_y_e, max_y_e + 1):
		var pos := Vector2i(east_x, y)
		var inner := Vector2i(r.end.x - 1, y)
		var outer := Vector2i(east_x + 1, y)
		if _is_candidate_valid(pos, inner, outer, grid):
			candidates.append(_EntranceCandidateScript.new(
				room.id,
				_RoomEntranceScript.EAST,
				pos,
				inner,
				outer
			))

	return candidates

static func _is_candidate_valid(pos: Vector2i, inner: Vector2i, outer: Vector2i, grid: CellGrid) -> bool:
	if not grid.is_in_bounds(pos) or not grid.is_in_bounds(inner) or not grid.is_in_bounds(outer):
		return false
	return true

static func _calc_corner_penalty(cand: EntranceCandidate, room: RoomData, base_penalty: float) -> float:
	var r: Rect2i = room.rect
	var p: Vector2i = cand.position
	var dist_to_corner: int = 999

	match cand.side:
		_RoomEntranceScript.NORTH, _RoomEntranceScript.SOUTH:
			var d_left: int = absi(p.x - r.position.x)
			var d_right: int = absi((r.end.x - 1) - p.x)
			dist_to_corner = mini(d_left, d_right)
		_RoomEntranceScript.WEST, _RoomEntranceScript.EAST:
			var d_top: int = absi(p.y - r.position.y)
			var d_bottom: int = absi((r.end.y - 1) - p.y)
			dist_to_corner = mini(d_top, d_bottom)

	if dist_to_corner <= 1:
		return base_penalty
	return 0.0

static func _get_preferred_side(from_center: Vector2i, to_center: Vector2i) -> int:
	var diff := to_center - from_center
	if absi(diff.x) >= absi(diff.y):
		return _RoomEntranceScript.EAST if diff.x > 0 else _RoomEntranceScript.WEST
	else:
		return _RoomEntranceScript.SOUTH if diff.y > 0 else _RoomEntranceScript.NORTH

static func _calc_candidate_unary_cost(
	cand: EntranceCandidate,
	room: RoomData,
	desired_side: int,
	reserved_pos_list: Array,
	reserved_sides_map: Dictionary,
	reserved_apps_list: Array,
	min_spacing: int,
	config: DungeonConfig
) -> float:
	var corner_pen: float = config.entrance_corner_penalty if "entrance_corner_penalty" in config else 5.0
	var same_side_pen: float = config.same_side_door_penalty if "same_side_door_penalty" in config else 30.0
	var proximity_pen: float = config.corridor_door_proximity_penalty if "corridor_door_proximity_penalty" in config else 50.0

	var cost: float = 0.0
	# 1. Orientación cardinal relativa
	if cand.side != desired_side:
		cost += 15.0

	# 2. Proximidad a esquinas
	cost += _calc_corner_penalty(cand, room, corner_pen)

	# 3. Penalización por proximidad en el perímetro de la misma sala
	var pos: Vector2i = cand.position
	for res_pos in reserved_pos_list:
		var manhattan: int = absi(pos.x - res_pos.x) + absi(pos.y - res_pos.y)
		if manhattan < min_spacing:
			cost += 100.0 * float(min_spacing - manhattan)

	# 4. Distribución entre caras
	if config.distribute_room_doors_across_sides:
		var count: int = reserved_sides_map.get(cand.side, 0)
		if count > 0:
			cost += same_side_pen * float(count)

	# 5. Proximidad de aproximaciones
	for prev_app in reserved_apps_list:
		if absi(cand.outer_cell.x - prev_app.x) + absi(cand.outer_cell.y - prev_app.y) <= 1:
			cost += proximity_pen

	return cost

static func _calc_pairwise_cost(
	cand_a: EntranceCandidate,
	cand_b: EntranceCandidate,
	room_a: RoomData,
	room_b: RoomData,
	config: DungeonConfig
) -> float:
	var dist_weight: float = config.entrance_distance_weight if "entrance_distance_weight" in config else 1.0
	var align_weight: float = config.entrance_alignment_weight if "entrance_alignment_weight" in config else 2.0

	# 1. Distancia euclídea entre los puntos de salida exterior
	var dx: float = float(cand_b.outer_cell.x - cand_a.outer_cell.x)
	var dy: float = float(cand_b.outer_cell.y - cand_a.outer_cell.y)
	var dist_cost: float = sqrt(dx * dx + dy * dy) * dist_weight

	# 2. Costo de alineación
	var align_cost: float = 0.0
	var center_delta: Vector2i = room_b.get_center() - room_a.get_center()
	var is_horizontal_dominant: bool = absi(center_delta.x) >= absi(center_delta.y)

	var pos_a: Vector2i = cand_a.position
	var pos_b: Vector2i = cand_b.position
	if is_horizontal_dominant:
		align_cost = absf(float(pos_b.y - pos_a.y)) * align_weight
	else:
		align_cost = absf(float(pos_b.x - pos_a.x)) * align_weight

	# 3. Estimación de Calidad de Forma del Corredor
	var shape_penalty: float = 0.0
	var out_a: Vector2i = cand_a.outer_cell
	var out_b: Vector2i = cand_b.outer_cell
	var dir_a: Vector2i = cand_a.outer_cell - cand_a.position
	var dir_b: Vector2i = cand_b.outer_cell - cand_b.position

	if (out_a.x == out_b.x and dir_a.x == 0 and dir_b.x == 0) or (out_a.y == out_b.y and dir_a.y == 0 and dir_b.y == 0):
		shape_penalty = 0.0
	elif (dir_a.x != 0 and dir_b.y != 0) or (dir_a.y != 0 and dir_b.x != 0):
		shape_penalty = 5.0
	else:
		shape_penalty = 20.0

	return dist_cost + align_cost + shape_penalty

## Función centralizada de puntuación de un par de candidatos (compatibilidad legacy).
static func score_candidate_pair(
	cand_a: EntranceCandidate,
	cand_b: EntranceCandidate,
	room_a: RoomData,
	room_b: RoomData,
	reserved_positions: Dictionary,
	all_reserved_positions: Dictionary,
	reserved_sides: Dictionary,
	reserved_approaches: Dictionary,
	min_spacing: int,
	config: DungeonConfig
) -> float:
	if cand_a.position == cand_b.position:
		return 1e8
	if all_reserved_positions.has(cand_a.position) or all_reserved_positions.has(cand_b.position):
		return 1e8

	var desired_side_a: int = _get_preferred_side(room_a.get_center(), room_b.get_center())
	var desired_side_b: int = _get_preferred_side(room_b.get_center(), room_a.get_center())
	var reserved_a: Array = reserved_positions.get(room_a.id, [])
	var reserved_b: Array = reserved_positions.get(room_b.id, [])
	var sides_a: Dictionary = reserved_sides.get(room_a.id, {})
	var sides_b: Dictionary = reserved_sides.get(room_b.id, {})
	var app_a: Array = reserved_approaches.get(room_a.id, [])
	var app_b: Array = reserved_approaches.get(room_b.id, [])

	var u_a: float = _calc_candidate_unary_cost(cand_a, room_a, desired_side_a, reserved_a, sides_a, app_a, min_spacing, config)
	var u_b: float = _calc_candidate_unary_cost(cand_b, room_b, desired_side_b, reserved_b, sides_b, app_b, min_spacing, config)
	var pair_cost: float = _calc_pairwise_cost(cand_a, cand_b, room_a, room_b, config)
	return u_a + u_b + pair_cost

static func _find_best_candidate_pair(
	cands_a: Array[EntranceCandidate],
	cands_b: Array[EntranceCandidate],
	room_a: RoomData,
	room_b: RoomData,
	conn: RefCounted,
	reserved_positions: Dictionary,
	all_reserved_positions: Dictionary,
	reserved_sides: Dictionary,
	reserved_approaches: Dictionary,
	min_spacing: int,
	config: DungeonConfig
) -> Dictionary:
	var best_score: float = 1e9
	var best_cand_a: EntranceCandidate = null
	var best_cand_b: EntranceCandidate = null
	var found_any := false

	var desired_side_a: int = _get_preferred_side(room_a.get_center(), room_b.get_center())
	var desired_side_b: int = _get_preferred_side(room_b.get_center(), room_a.get_center())
	var reserved_a: Array = reserved_positions.get(room_a.id, [])
	var reserved_b: Array = reserved_positions.get(room_b.id, [])
	var sides_a: Dictionary = reserved_sides.get(room_a.id, {})
	var sides_b: Dictionary = reserved_sides.get(room_b.id, {})
	var app_a: Array = reserved_approaches.get(room_a.id, [])
	var app_b: Array = reserved_approaches.get(room_b.id, [])

	var unary_a: Array[float] = []
	unary_a.resize(cands_a.size())
	for i in range(cands_a.size()):
		var ca := cands_a[i]
		if all_reserved_positions.has(ca.position):
			unary_a[i] = 1e8
		else:
			unary_a[i] = _calc_candidate_unary_cost(ca, room_a, desired_side_a, reserved_a, sides_a, app_a, min_spacing, config)

	var unary_b: Array[float] = []
	unary_b.resize(cands_b.size())
	for j in range(cands_b.size()):
		var cb := cands_b[j]
		if all_reserved_positions.has(cb.position):
			unary_b[j] = 1e8
		else:
			unary_b[j] = _calc_candidate_unary_cost(cb, room_b, desired_side_b, reserved_b, sides_b, app_b, min_spacing, config)

	# Evaluación exhaustiva optimizada con costos unarios precalculados
	for i in range(cands_a.size()):
		var u_a: float = unary_a[i]
		if u_a >= 1e8:
			continue
		var ca: EntranceCandidate = cands_a[i]

		for j in range(cands_b.size()):
			var u_b: float = unary_b[j]
			if u_b >= 1e8:
				continue
			var cb: EntranceCandidate = cands_b[j]

			if ca.position == cb.position:
				continue

			var pairwise_cost: float = _calc_pairwise_cost(ca, cb, room_a, room_b, config)
			var score: float = u_a + u_b + pairwise_cost

			if score >= 1e8:
				continue

			if not found_any or score < best_score:
				best_score = score
				best_cand_a = ca
				best_cand_b = cb
				found_any = true
			elif is_equal_approx(score, best_score):
				if _tie_breaker_a_over_b(ca, cb, best_cand_a, best_cand_b, conn.id):
					best_score = score
					best_cand_a = ca
					best_cand_b = cb

	if not found_any or best_cand_a == null or best_cand_b == null:
		return {"is_invalid": true, "reason": "NO_VALID_PAIRS", "score": 1e9}

	return {
		"is_invalid": false,
		"score": best_score,
		"cand_a": best_cand_a,
		"cand_b": best_cand_b
	}

## Desempate determinista lexicográfico para garantizar reproducibilidad exacta.
static func _tie_breaker_a_over_b(
	cand_a1: EntranceCandidate,
	cand_b1: EntranceCandidate,
	cand_a2: EntranceCandidate,
	cand_b2: EntranceCandidate,
	conn_id: int
) -> bool:
	if cand_a1.position.y != cand_a2.position.y:
		return cand_a1.position.y < cand_a2.position.y
	if cand_a1.position.x != cand_a2.position.x:
		return cand_a1.position.x < cand_a2.position.x
	if cand_b1.position.y != cand_b2.position.y:
		return cand_b1.position.y < cand_b2.position.y
	if cand_b1.position.x != cand_b2.position.x:
		return cand_b1.position.x < cand_b2.position.x
	return (conn_id % 2 == 0)

## Ordena conexiones por prioridad:
## 1. Mandatory/MST primero
## 2. Prioridad semántica de rol (MAIN_PATH > SIDE_PATH > OPTIONAL > SHORTCUT)
## 3. Menor cantidad de candidatos (más restringidas primero)
## 4. Mayor distancia entre centros
## 5. Connection ID estable
static func _sort_connections_by_priority(
	connections: Array,
	room_map: Dictionary,
	candidates_by_room: Dictionary,
	corridor_plan = null
) -> Array:
	var conns := connections.duplicate()
	conns.sort_custom(func(a, b):
		# 1. Mandatory primero
		var req_a: bool = a.is_required if ("is_required" in a) else true
		var req_b: bool = b.is_required if ("is_required" in b) else true
		if req_a != req_b:
			return req_a # true antes que false

		# 2. Prioridad semántica de rol desde CorridorPlan (si está disponible)
		if corridor_plan != null and corridor_plan.has_method("get_request_for_connection"):
			var plan_a = corridor_plan.get_request_for_connection(a.id if ("id" in a) else -1)
			var plan_b = corridor_plan.get_request_for_connection(b.id if ("id" in b) else -1)
			var role_rank := func(r) -> int:
				if r == null or not ("corridor_role" in r):
					return 0
				match r.corridor_role:
					&"main_path": return 3
					&"side_path": return 2
					&"optional": return 1
					_: return 0
			var rank_a: int = role_rank.call(plan_a)
			var rank_b: int = role_rank.call(plan_b)
			if rank_a != rank_b:
				return rank_a > rank_b

		# 3. Restricción de candidatos
		var c_count_a: int = candidates_by_room.get(a.room_a_id, []).size() * candidates_by_room.get(a.room_b_id, []).size()
		var c_count_b: int = candidates_by_room.get(b.room_a_id, []).size() * candidates_by_room.get(b.room_b_id, []).size()
		if c_count_a != c_count_b:
			return c_count_a < c_count_b # Menor número de opciones primero

		# 3. Distancia entre centros (más largas primero)
		var ra1: RoomData = room_map.get(a.room_a_id, null)
		var rb1: RoomData = room_map.get(a.room_b_id, null)
		var ra2: RoomData = room_map.get(b.room_a_id, null)
		var rb2: RoomData = room_map.get(b.room_b_id, null)

		var dist_a: float = 0.0
		var dist_b: float = 0.0
		if ra1 != null and rb1 != null:
			dist_a = float((ra1.get_center() - rb1.get_center()).length_squared())
		if ra2 != null and rb2 != null:
			dist_b = float((ra2.get_center() - rb2.get_center()).length_squared())

		if not is_equal_approx(dist_a, dist_b):
			return dist_a > dist_b

		# 4. Desempate por ID
		var id_a: int = a.id if ("id" in a) else 0
		var id_b: int = b.id if ("id" in b) else 0
		return id_a < id_b
	)
	return conns
