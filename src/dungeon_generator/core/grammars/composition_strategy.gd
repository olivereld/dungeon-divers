class_name CompositionStrategy
extends RefCounted

## Estrategia de Composición Espacial (Spatial Constraints v1).
## Implementa progresión espacial START -> EARLY -> MID -> LATE -> BOSS.
## Separa estrictamente restricciones duras (rechazo inmediato) de puntuación suave (soft scoring).
## Elimina por completo los fallbacks con clamp o fabricación de posiciones inválidas.
## Produce un RoomPlacementPlan inmutable y sellado de solo lectura.

const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")

const REGION_START: StringName = &"region_start"
const REGION_EARLY: StringName = &"region_early"
const REGION_MID: StringName = &"region_mid"
const REGION_LATE: StringName = &"region_late"
const REGION_BOSS: StringName = &"region_boss"
const REGION_BRANCH: StringName = &"region_branch"
const REGION_OPTIONAL: StringName = &"region_optional"
const REGION_MAIN_PATH: StringName = &"region_main_path"

const _DIRECTIONS: Array[Vector2] = [
	Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
	Vector2(0.7071, 0.7071), Vector2(-0.7071, 0.7071),
	Vector2(0.7071, -0.7071), Vector2(-0.7071, -0.7071)
]

var _rng: RandomNumberGenerator

func _init(rng: RandomNumberGenerator = null) -> void:
	if rng != null:
		_rng = rng
	else:
		_rng = RandomNumberGenerator.new()

## Genera un plan de colocación espacial completo y sellado para las habitaciones dadas.
## No muta las instancias de RoomData.
func create_placement_plan(
	rooms: Array[RoomData],
	mission_graph: DungeonGraph,
	bounds: Rect2i,
	config: SpaceGrammarConfig = null
) -> RoomPlacementPlan:
	var plan := RoomPlacementPlan.new()
	if rooms.is_empty():
		plan.seal()
		return plan

	var preferred_distance: float = config.mission_aware_preferred_distance if config != null else 12.0
	var candidate_count: int = config.mission_aware_candidate_count if config != null else 15
	var distance_jitter: float = config.mission_aware_distance_jitter if config != null else 4.0
	var min_separation: int = config.min_room_separation if config != null else 2
	var min_edge_dist: float = config.min_mission_edge_distance if config != null else 6.0
	var progression_strength: float = config.progression_strength if config != null else 1.0
	var density_strength: float = config.density_strength if config != null else 0.5

	# Dirección global de progresión del dungeon (determinista)
	var progression_dir := Vector2.ZERO
	if config != null and config.preferred_progression_direction != Vector2.ZERO:
		progression_dir = config.preferred_progression_direction.normalized()
	else:
		var dir_idx: int = _rng.randi_range(0, _DIRECTIONS.size() - 1)
		progression_dir = _DIRECTIONS[dir_idx]

	# Alcance máximo de progresión espacial dentro de los bounds
	var max_progression_span: float = minf(float(bounds.size.x), float(bounds.size.y)) * 0.65

	# Indexar salas y calcular orden topológico
	var room_by_id: Dictionary = {}
	var room_by_node_id: Dictionary = {}
	for r in rooms:
		if r != null:
			room_by_id[r.id] = r
			if r.mission_node_id >= 0:
				room_by_node_id[r.mission_node_id] = r

	var ordered_rooms: Array[RoomData] = []
	var node_progression_factors: Dictionary = {} # room_id -> float (0.0 a 1.0)
	if mission_graph != null:
		var topo_order: Array[int] = mission_graph.get_topological_order()
		var total_nodes: int = topo_order.size()
		for idx in range(total_nodes):
			var node_id: int = topo_order[idx]
			if room_by_node_id.has(node_id):
				var r: RoomData = room_by_node_id[node_id]
				ordered_rooms.append(r)
				var factor: float = float(idx) / float(maxi(1, total_nodes - 1))
				node_progression_factors[r.id] = factor
		for r in rooms:
			if not ordered_rooms.has(r):
				ordered_rooms.append(r)
				node_progression_factors[r.id] = 0.5
	else:
		ordered_rooms = rooms.duplicate()
		for idx in range(ordered_rooms.size()):
			var factor: float = float(idx) / float(maxi(1, ordered_rooms.size() - 1))
			node_progression_factors[ordered_rooms[idx].id] = factor

	# Seguimiento local de posiciones decididas (room_id -> Rect2i)
	var placed_rects: Dictionary = {}
	var start_center := Vector2(bounds.position + bounds.size / 2)

	for room in ordered_rooms:
		var size: Vector2i = room.rect.size
		var prog_factor: float = float(node_progression_factors.get(room.id, 0.5))
		var region: StringName = _classify_progression_region(room, prog_factor, mission_graph)
		var priority: int = _determine_priority(room, region)

		# Objetivo espacial para este paso de progresión
		var prog_target: Vector2 = start_center + progression_dir * (prog_factor * max_progression_span)
		# Variación ortogonal suave para evitar alineación recta artificial
		var perp_dir := Vector2(-progression_dir.y, progression_dir.x)
		var lateral_offset: float = sin(prog_factor * PI * 1.5) * 6.0
		prog_target += perp_dir * lateral_offset

		var best_pos: Vector2i = Vector2i.MIN
		if placed_rects.is_empty() or room.room_type == RoomData.RoomType.START:
			best_pos = _place_start_room(size, bounds, progression_dir)
			if best_pos != Vector2i.MIN:
				start_center = Vector2(best_pos) + Vector2(size) / 2.0
		else:
			best_pos = _find_best_position(
				room,
				size,
				placed_rects,
				room_by_id,
				mission_graph,
				bounds,
				start_center,
				prog_target,
				prog_factor,
				progression_dir,
				preferred_distance,
				candidate_count,
				distance_jitter,
				min_separation,
				min_edge_dist,
				progression_strength,
				density_strength
			)

		# Restricción Dura: Si no se pudo encontrar una posición válida sin colisión, NO se añade al plan
		if best_pos != Vector2i.MIN:
			placed_rects[room.id] = Rect2i(best_pos, size)
			plan.add_entry(room.id, best_pos, region, priority)
		else:
			push_warning("[CompositionStrategy] Failed to find valid placement for room %d (type=%s). Refusing invalid placement." % [
				room.id, room.room_type
			])

	plan.seal()
	return plan

func _classify_progression_region(room: RoomData, prog_factor: float, mission_graph: DungeonGraph) -> StringName:
	if room.room_type == RoomData.RoomType.START:
		return REGION_START
	if room.room_type == RoomData.RoomType.BOSS or room.room_type == RoomData.RoomType.GOAL:
		return REGION_BOSS

	# Detectar ramas secundarias
	if mission_graph != null and room.mission_node_id >= 0:
		var successors: Array[int] = mission_graph.get_successors(room.mission_node_id)
		var preds: Array[int] = mission_graph.get_predecessors(room.mission_node_id)
		if successors.is_empty() and not preds.is_empty():
			return REGION_BRANCH

	# Progresión espacial en la ruta principal
	if prog_factor <= 0.33:
		return REGION_EARLY
	elif prog_factor <= 0.67:
		return REGION_MID
	else:
		return REGION_LATE

func _determine_priority(room: RoomData, region: StringName) -> int:
	match region:
		REGION_START:
			return 100
		REGION_BOSS:
			return 90
		REGION_LATE:
			return 60
		REGION_MID:
			return 50
		REGION_EARLY:
			return 40
		REGION_BRANCH, REGION_OPTIONAL:
			return 20
		_:
			return 10

## Coloca la sala START validando estrictamente que quepa en bounds sin usar clamp.
## Si la sala no cabe en los límites, retorna Vector2i.MIN para producir un fallo explícito.
func _place_start_room(size: Vector2i, bounds: Rect2i, progression_dir: Vector2) -> Vector2i:
	if size.x > bounds.size.x or size.y > bounds.size.y:
		return Vector2i.MIN

	var max_x: int = bounds.end.x - size.x
	var max_y: int = bounds.end.y - size.y
	if max_x < bounds.position.x or max_y < bounds.position.y:
		return Vector2i.MIN

	var center := bounds.position + bounds.size / 2
	var offset: Vector2 = -progression_dir * 8.0

	# Evaluar candidatos de posición alrededor del centro desplazado opuesto a la progresión
	for attempt in range(16):
		var ox: int = 0
		var oy: int = 0
		if attempt > 0:
			var damp: float = 1.0 - float(attempt) / 16.0
			ox = _rng.randi_range(-4, 4) + int(offset.x * damp)
			oy = _rng.randi_range(-4, 4) + int(offset.y * damp)
		else:
			ox = int(offset.x)
			oy = int(offset.y)

		var cand := center - size / 2 + Vector2i(ox, oy)
		if bounds.encloses(Rect2i(cand, size)):
			return cand

	# Fallback en el centro exacto si cabe
	var fallback_center := center - size / 2
	if bounds.encloses(Rect2i(fallback_center, size)):
		return fallback_center

	return Vector2i.MIN

func _find_best_position(
	room: RoomData,
	size: Vector2i,
	placed_rects: Dictionary,
	room_by_id: Dictionary,
	mission_graph: DungeonGraph,
	bounds: Rect2i,
	start_center: Vector2,
	prog_target: Vector2,
	prog_factor: float,
	progression_dir: Vector2,
	preferred_distance: float,
	candidate_count: int,
	distance_jitter: float,
	min_separation: int,
	min_edge_dist: float,
	progression_strength: float,
	density_strength: float
) -> Vector2i:
	# Recopilar rectángulos y centros de vecinos de misión ya colocados
	var neighbor_rects: Array[Rect2i] = []
	if mission_graph != null and room.mission_node_id >= 0:
		var neighbor_ids: Array[int] = mission_graph.get_neighbors(room.mission_node_id)
		for other_id in placed_rects:
			var other_room: RoomData = room_by_id.get(other_id)
			if other_room != null and other_room.mission_node_id in neighbor_ids:
				neighbor_rects.append(placed_rects[other_id])

	var anchor: Vector2
	if not neighbor_rects.is_empty():
		var sum := Vector2.ZERO
		for nr in neighbor_rects:
			sum += Vector2(nr.position + nr.size / 2)
		anchor = sum / neighbor_rects.size()
	else:
		var sum := Vector2.ZERO
		for pr in placed_rects.values():
			sum += Vector2((pr as Rect2i).position + (pr as Rect2i).size / 2)
		anchor = sum / placed_rects.size()

	# Dirección orientada hacia el target de progresión
	var to_prog: Vector2 = (prog_target - anchor).normalized()
	if to_prog.is_zero_approx():
		to_prog = Vector2(1, 0)

	var best_pos: Vector2i = Vector2i.MIN
	var best_score: float = -INF

	# 1. Búsqueda primaria de candidatos
	var attempts: int = candidate_count * 2
	for _i in range(attempts):
		var dir: Vector2
		var roll: float = _rng.randf()
		if roll < 0.45:
			# Sesgo hacia la progresión con jitter angular
			var angle_jitter: float = _rng.randf_range(-0.6, 0.6)
			dir = to_prog.rotated(angle_jitter).normalized()
		else:
			# Exploración en 8 direcciones
			var dir_idx: int = _rng.randi_range(0, _DIRECTIONS.size() - 1)
			var angle_jitter: float = _rng.randf_range(-0.3, 0.3)
			dir = _DIRECTIONS[dir_idx].rotated(angle_jitter).normalized()

		var dist: float = preferred_distance + _rng.randf_range(-distance_jitter, distance_jitter)
		var target_center: Vector2 = anchor + dir * dist
		var cand_pos := Vector2i(int(target_center.x - size.x / 2.0), int(target_center.y - size.y / 2.0))

		# RESTRICCIÓN DURA: Descarte inmediato si no satisface todas las condiciones
		if not _passes_hard_constraints(cand_pos, size, bounds, placed_rects, neighbor_rects, min_separation, min_edge_dist, start_center, room.room_type):
			continue

		# SOFT SCORING: Puntuación multivariada
		var score: float = _score_candidate(
			cand_pos,
			size,
			bounds,
			anchor,
			start_center,
			prog_target,
			prog_factor,
			progression_dir,
			neighbor_rects,
			placed_rects,
			preferred_distance,
			progression_strength,
			density_strength
		)

		if score > best_score:
			best_score = score
			best_pos = cand_pos

	if best_pos != Vector2i.MIN:
		return best_pos

	# 2. Búsqueda expandida determinista (estrictamente filtrada por restricciones duras)
	return _expanded_valid_candidate_search(
		room,
		size,
		anchor,
		bounds,
		placed_rects,
		neighbor_rects,
		min_separation,
		min_edge_dist,
		start_center,
		prog_target,
		prog_factor,
		progression_dir,
		preferred_distance,
		progression_strength,
		density_strength
	)

## Evaluación de Restricciones Duras (Hard Constraints).
## Si alguna condición falla, el candidato es rechazado inmediatamente.
## min_mission_edge_distance se mantiene como hard constraint.
## max_mission_edge_distance NO es un hard constraint (se penaliza suavemente en scoring).
func _passes_hard_constraints(
	pos: Vector2i,
	size: Vector2i,
	bounds: Rect2i,
	placed_rects: Dictionary,
	neighbor_rects: Array[Rect2i],
	min_separation: int,
	min_edge_dist: float,
	start_center: Vector2,
	room_type: StringName
) -> bool:
	var cand_rect := Rect2i(pos, size)
	var cand_center := Vector2(pos) + Vector2(size) / 2.0

	# 1. Contención estricta dentro de los límites
	if not bounds.encloses(cand_rect):
		return false

	# 2. Separación mínima contra TODAS las salas colocadas (cero colisiones AABB con margen)
	for pr in placed_rects.values():
		var target_rect: Rect2i = (pr as Rect2i).grow(min_separation) if min_separation > 0 else (pr as Rect2i)
		if cand_rect.intersects(target_rect):
			return false

	# 3. Restricción dura de distancia mínima para vecinos de misión obligatorios
	if not neighbor_rects.is_empty():
		for nr in neighbor_rects:
			var n_center := Vector2(nr.position + nr.size / 2)
			var d: float = cand_center.distance_to(n_center)
			if d < min_edge_dist:
				return false

	# 4. Regla de progresión para el BOSS: debe estar separado del START
	if room_type == RoomData.RoomType.BOSS or room_type == RoomData.RoomType.GOAL:
		if cand_center.distance_to(start_center) < (min_edge_dist * 1.8):
			return false

	return true

## Evaluación de Puntuación Suave (Soft Scoring).
## Evalúa calidad espacial entre candidatos que ya superaron todas las restricciones duras.
func _score_candidate(
	cand_pos: Vector2i,
	size: Vector2i,
	bounds: Rect2i,
	anchor: Vector2,
	start_center: Vector2,
	prog_target: Vector2,
	prog_factor: float,
	progression_dir: Vector2,
	neighbor_rects: Array[Rect2i],
	placed_rects: Dictionary,
	preferred_distance: float,
	progression_strength: float,
	density_strength: float
) -> float:
	var cand_center := Vector2(cand_pos) + Vector2(size) / 2.0

	# (a) Proximidad a los vecinos de misión y penalización suave de distancias excesivas
	var neighbor_score: float = 0.0
	var excessive_edge_penalty: float = 0.0
	if not neighbor_rects.is_empty():
		for nr in neighbor_rects:
			var n_center := Vector2(nr.position + nr.size / 2)
			var d: float = cand_center.distance_to(n_center)
			neighbor_score -= abs(d - preferred_distance)
			if d > preferred_distance * 1.5:
				excessive_edge_penalty += (d - preferred_distance * 1.5) * 1.2
	else:
		var d: float = cand_center.distance_to(anchor)
		neighbor_score -= abs(d - preferred_distance)
		if d > preferred_distance * 1.5:
			excessive_edge_penalty += (d - preferred_distance * 1.5) * 1.2

	# (b) Progresión espacial hacia el target global y alineación direccional
	var progression_dist_score: float = -cand_center.distance_to(prog_target) * 0.4
	var from_start: Vector2 = cand_center - start_center
	var dir_alignment: float = 0.0
	if not from_start.is_zero_approx() and not progression_dir.is_zero_approx():
		dir_alignment = from_start.normalized().dot(progression_dir) * 4.0 * prog_factor

	var progression_score: float = progression_dist_score + dir_alignment

	# (c) Separación saludable de salas (respiración) y densidad local
	var min_dist_to_any: float = INF
	var close_rooms_count: int = 0
	var clustering_metric: float = 0.0

	for pr in placed_rects.values():
		var p_center := Vector2((pr as Rect2i).position + (pr as Rect2i).size / 2)
		var d: float = cand_center.distance_to(p_center)
		min_dist_to_any = min(min_dist_to_any, d)
		if d < 18.0:
			close_rooms_count += 1
		clustering_metric += 1.0 / maxf(d, 1.0)

	var separation_score: float = 0.0
	if min_dist_to_any != INF:
		separation_score = min_dist_to_any * 0.35

	# (d) Penalización por aglomeración excesiva (clustering)
	var excessive_clustering_penalty: float = 0.0
	if close_rooms_count > 2:
		excessive_clustering_penalty = (close_rooms_count - 2) * 5.0 * density_strength
	excessive_clustering_penalty += clustering_metric * 2.0 * density_strength

	# (e) Penalización por distancia excesiva (isla desconectada respecto a cualquier sala)
	var excessive_distance_penalty: float = 0.0
	if min_dist_to_any > preferred_distance * 2.2:
		excessive_distance_penalty = (min_dist_to_any - preferred_distance * 2.2) * 1.5

	# (f) Forma global: preferencia suave hacia el centro de bounds para compacidad
	var bounds_center := Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	var global_shape_score: float = -cand_center.distance_to(bounds_center) * 0.06

	# (g) Jitter determinista para desempates
	var jitter: float = _rng.randf() * 0.05

	const W_NEIGHBOR := 1.0
	const W_SEPARATION := 0.3

	var score: float = (
		(W_NEIGHBOR * neighbor_score)
		+ (progression_strength * progression_score)
		+ (W_SEPARATION * separation_score)
		+ global_shape_score
		- excessive_edge_penalty
		- excessive_clustering_penalty
		- excessive_distance_penalty
		+ jitter
	)

	return score

## Búsqueda expandida determinista cuando la búsqueda primaria no encontró candidatos.
## Aplica estrictamente las restricciones duras. Si ninguna posición califica, retorna Vector2i.MIN.
func _expanded_valid_candidate_search(
	room: RoomData,
	size: Vector2i,
	anchor: Vector2,
	bounds: Rect2i,
	placed_rects: Dictionary,
	neighbor_rects: Array[Rect2i],
	min_separation: int,
	min_edge_dist: float,
	start_center: Vector2,
	prog_target: Vector2,
	prog_factor: float,
	progression_dir: Vector2,
	preferred_distance: float,
	progression_strength: float,
	density_strength: float
) -> Vector2i:
	var best_pos: Vector2i = Vector2i.MIN
	var best_score: float = -INF

	# Buscar en anillos radiales deterministas alrededor del ancla
	var max_search_radius: int = maxi(int(preferred_distance * 2.8), 40)
	for radius in range(int(min_edge_dist), max_search_radius, 2):
		var steps: int = int(TAU * radius / 3.0)
		steps = clampi(steps, 8, 36)
		for s in range(steps):
			var angle: float = (float(s) / float(steps)) * TAU
			var cand_pos := Vector2i(
				int(anchor.x + cos(angle) * radius - size.x / 2.0),
				int(anchor.y + sin(angle) * radius - size.y / 2.0)
			)

			if not _passes_hard_constraints(cand_pos, size, bounds, placed_rects, neighbor_rects, min_separation, min_edge_dist, start_center, room.room_type):
				continue

			var score: float = _score_candidate(
				cand_pos,
				size,
				bounds,
				anchor,
				start_center,
				prog_target,
				prog_factor,
				progression_dir,
				neighbor_rects,
				placed_rects,
				preferred_distance,
				progression_strength,
				density_strength
			)

			if score > best_score:
				best_score = score
				best_pos = cand_pos

		if best_pos != Vector2i.MIN:
			return best_pos

	# Si incluso la búsqueda expandida falla, retorna Vector2i.MIN para fallar explícitamente.
	return Vector2i.MIN
