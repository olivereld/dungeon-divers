class_name CompositionStrategy
extends RefCounted

## Estrategia de Composición Espacial.
## Evalúa y calcula candidatos de colocación respetando las reglas de la gramática
## y la progresión de MissionGraph sin mutar RoomData ni el CellGrid.
## Produce un RoomPlacementPlan inmutable de solo lectura.

const RoomPlacementPlan = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const RoomData = preload("res://src/dungeon_generator/core/data/room_data.gd")
const DungeonGraph = preload("res://src/dungeon_generator/core/data/dungeon_graph.gd")
const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")

const REGION_START: StringName = &"region_start"
const REGION_MAIN_PATH: StringName = &"region_main_path"
const REGION_BRANCH: StringName = &"region_branch"
const REGION_BOSS: StringName = &"region_boss"
const REGION_OPTIONAL: StringName = &"region_optional"

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

	# Mapa local de id a RoomData para acceso rápido
	var room_by_id: Dictionary = {}
	var room_by_node_id: Dictionary = {}
	for r in rooms:
		if r != null:
			room_by_id[r.id] = r
			if r.mission_node_id >= 0:
				room_by_node_id[r.mission_node_id] = r

	# Determinar orden de procesamiento respetando el orden topológico si existe
	var ordered_rooms: Array[RoomData] = []
	if mission_graph != null:
		var topo_order: Array[int] = mission_graph.get_topological_order()
		for node_id in topo_order:
			if room_by_node_id.has(node_id):
				ordered_rooms.append(room_by_node_id[node_id])
		# Agregar salas que no tengan nodo de misión asociado
		for r in rooms:
			if not ordered_rooms.has(r):
				ordered_rooms.append(r)
	else:
		ordered_rooms = rooms.duplicate()

	# Seguimiento local de decisiones tomadas (room_id -> Rect2i)
	var placed_rects: Dictionary = {}

	for room in ordered_rooms:
		var size: Vector2i = room.rect.size
		var region: StringName = _classify_region(room, mission_graph)
		var priority: int = _determine_priority(room, region)

		var best_pos: Vector2i
		if placed_rects.is_empty() or room.room_type == RoomData.RoomType.START:
			best_pos = _place_initial_room(size, bounds)
		else:
			best_pos = _find_best_position(
				room,
				size,
				placed_rects,
				room_by_id,
				mission_graph,
				bounds,
				preferred_distance,
				candidate_count,
				distance_jitter
			)

		placed_rects[room.id] = Rect2i(best_pos, size)
		plan.add_entry(room.id, best_pos, region, priority)

	plan.seal()
	return plan

func _classify_region(room: RoomData, mission_graph: DungeonGraph) -> StringName:
	if room.room_type == RoomData.RoomType.START:
		return REGION_START
	if room.room_type == RoomData.RoomType.BOSS or room.room_type == RoomData.RoomType.GOAL:
		return REGION_BOSS
	if room.room_type == RoomData.RoomType.TREASURE or room.room_type == RoomData.RoomType.PUZZLE:
		return REGION_OPTIONAL

	if mission_graph != null and room.mission_node_id >= 0:
		var successors: Array[int] = mission_graph.get_successors(room.mission_node_id)
		var preds: Array[int] = mission_graph.get_predecessors(room.mission_node_id)
		if successors.is_empty() and not preds.is_empty():
			return REGION_BRANCH
		if preds.size() > 1 or successors.size() > 1:
			return REGION_BRANCH

	return REGION_MAIN_PATH

func _determine_priority(room: RoomData, region: StringName) -> int:
	match region:
		REGION_START:
			return 100
		REGION_BOSS:
			return 90
		REGION_MAIN_PATH:
			return 50
		REGION_BRANCH:
			return 30
		REGION_OPTIONAL:
			return 10
		_:
			return 0

func _place_initial_room(size: Vector2i, bounds: Rect2i) -> Vector2i:
	var center := bounds.position + bounds.size / 2
	var ox: int = _rng.randi_range(-4, 4)
	var oy: int = _rng.randi_range(-4, 4)
	var pos := center - size / 2 + Vector2i(ox, oy)
	return _clamp_to_bounds(pos, size, bounds)

func _find_best_position(
	room: RoomData,
	size: Vector2i,
	placed_rects: Dictionary,
	room_by_id: Dictionary,
	mission_graph: DungeonGraph,
	bounds: Rect2i,
	preferred_distance: float,
	candidate_count: int,
	distance_jitter: float
) -> Vector2i:
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

	var best_pos: Vector2i = Vector2i.ZERO
	var best_score: float = -INF
	var found_valid := false

	for _i in range(candidate_count):
		var dir_idx: int = _rng.randi_range(0, _DIRECTIONS.size() - 1)
		var base_dir: Vector2 = _DIRECTIONS[dir_idx]
		var angle_offset: float = _rng.randf_range(-0.35, 0.35)
		var dir: Vector2 = base_dir.rotated(angle_offset).normalized()
		var dist: float = preferred_distance + _rng.randf_range(-distance_jitter, distance_jitter)

		var target_center: Vector2 = anchor + dir * dist
		var cand_pos := Vector2i(int(target_center.x - size.x / 2.0), int(target_center.y - size.y / 2.0))

		if not _is_cand_valid(cand_pos, size, bounds, placed_rects, 2):
			continue

		var score: float = _score_candidate_pos(cand_pos, size, anchor, neighbor_rects, placed_rects, preferred_distance)
		if score > best_score:
			best_score = score
			best_pos = cand_pos
			found_valid = true

	if found_valid:
		return best_pos

	# Fallback sistemático: búsqueda en espiral alrededor de anchor
	return _fallback_spiral_search(anchor, size, bounds, placed_rects, 2)

func _score_candidate_pos(
	cand_pos: Vector2i,
	size: Vector2i,
	anchor: Vector2,
	neighbor_rects: Array[Rect2i],
	placed_rects: Dictionary,
	preferred_distance: float
) -> float:
	var cand_center := Vector2(cand_pos) + Vector2(size) / 2.0

	var proximity_score: float = 0.0
	if not neighbor_rects.is_empty():
		for nr in neighbor_rects:
			var n_center := Vector2(nr.position + nr.size / 2)
			proximity_score -= abs(cand_center.distance_to(n_center) - preferred_distance)
	else:
		proximity_score -= abs(cand_center.distance_to(anchor) - preferred_distance)

	var min_dist_to_any: float = INF
	for pr in placed_rects.values():
		var p_center := Vector2((pr as Rect2i).position + (pr as Rect2i).size / 2)
		min_dist_to_any = min(min_dist_to_any, cand_center.distance_to(p_center))

	var separation_score: float = 0.0
	if min_dist_to_any != INF:
		separation_score = min_dist_to_any

	var jitter: float = _rng.randf() * 0.01

	return (1.0 * proximity_score) + (0.3 * separation_score) + jitter

func _is_cand_valid(pos: Vector2i, size: Vector2i, bounds: Rect2i, placed_rects: Dictionary, margin: int = 2) -> bool:
	var cand_rect := Rect2i(pos, size)
	if not bounds.encloses(cand_rect):
		return false
	for pr in placed_rects.values():
		var target_rect: Rect2i = (pr as Rect2i).grow(margin) if margin > 0 else (pr as Rect2i)
		if cand_rect.intersects(target_rect):
			return false
	return true

func _fallback_spiral_search(
	anchor: Vector2,
	size: Vector2i,
	bounds: Rect2i,
	placed_rects: Dictionary,
	margin: int = 2
) -> Vector2i:
	for radius in range(4, 50, 2):
		var steps: int = int(TAU * radius / 3.0)
		steps = clampi(steps, 8, 36)
		for s in range(steps):
			var angle: float = (float(s) / float(steps)) * TAU
			var cand_pos := Vector2i(
				int(anchor.x + cos(angle) * radius - size.x / 2.0),
				int(anchor.y + sin(angle) * radius - size.y / 2.0)
			)
			if _is_cand_valid(cand_pos, size, bounds, placed_rects, margin):
				return cand_pos

	# Último recurso: clamp dentro de bounds
	return _clamp_to_bounds(Vector2i(int(anchor.x - size.x / 2.0), int(anchor.y - size.y / 2.0)), size, bounds)

func _clamp_to_bounds(pos: Vector2i, size: Vector2i, bounds: Rect2i) -> Vector2i:
	return Vector2i(
		clampi(pos.x, bounds.position.x, bounds.end.x - size.x),
		clampi(pos.y, bounds.position.y, bounds.end.y - size.y)
	)
