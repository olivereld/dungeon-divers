class_name SpaceGrammar
extends RefCounted

## Traduce el grafo de misiones en habitaciones físicas (RoomData) posicionadas sin solapamiento
## y distribuidas armónicamente por el espacio disponible de la mazmorra.

const _RoomSpatialSeparatorScript = preload("res://src/dungeon_generator/core/topology/room_spatial_separator.gd")
const SpaceGrammarConfig = preload("res://src/dungeon_generator/config/space_grammar_config.gd")

const _DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
]

var _rng: RandomNumberGenerator
var rng: RandomNumberGenerator
var mission_graph: DungeonGraph
var config: SpaceGrammarConfig

var tier_3_count: int = 0
var tier_4_count: int = 0
var _metrics_before_separator: Dictionary = {}
var _metrics_after_separator: Dictionary = {}
var _rooms_before_separator: Array[RoomData] = []

func _init(p_config: SpaceGrammarConfig = null) -> void:
	_rng = RandomNumberGenerator.new()
	rng = _rng
	config = p_config if p_config != null else SpaceGrammarConfig.new()

func generate(p_mission_graph: DungeonGraph, p_config = null, random_seed: int = 0) -> Array[RoomData]:
	mission_graph = p_mission_graph
	rng = _rng

	if p_config is SpaceGrammarConfig:
		config = p_config
	elif p_config is DungeonConfig:
		if p_config.space_grammar_config != null:
			config = p_config.space_grammar_config
		else:
			config = SpaceGrammarConfig.new()
			config.use_mission_aware_placement = p_config.use_mission_aware_placement
			config.mission_aware_preferred_distance = p_config.mission_aware_preferred_distance
			config.mission_aware_candidate_count = p_config.mission_aware_candidate_count
			config.mission_aware_distance_jitter = p_config.mission_aware_distance_jitter
	elif config == null:
		config = SpaceGrammarConfig.new()

	if random_seed != 0:
		_rng.seed = random_seed
	elif p_config is DungeonConfig and p_config.seed != 0:
		_rng.seed = p_config.seed
	else:
		_rng.seed = 1337

	var rooms: Array[RoomData] = []
	var grid_w: int = p_config.grid_width if (p_config is DungeonConfig and p_config != null) else 64
	var grid_h: int = p_config.grid_height if (p_config is DungeonConfig and p_config != null) else 64
	var grid_bounds := Rect2i(3, 3, grid_w - 6, grid_h - 6)

	var node_ids: Array[int] = mission_graph.get_topological_order()
	if node_ids.is_empty() and not mission_graph.get_all_node_ids().is_empty():
		push_warning("[SpaceGrammar] MISSION_GRAPH_CYCLE: Mission graph is not a valid DAG.")
		return []

	var node_to_room: Dictionary = {} # node_id -> RoomData

	var large_count: int = 0

	tier_3_count = 0
	tier_4_count = 0

	for i in range(node_ids.size()):
		var node_id: int = node_ids[i]
		var node_data: Dictionary = mission_graph.get_node_data(node_id)
		var m_node: MissionNode = MissionNode.from_dictionary(node_data)

		var room_type: StringName = m_node.room_type_hint
		if m_node.action == MissionNode.ActionType.BOSS:
			room_type = &"boss"
		elif m_node.action == MissionNode.ActionType.START:
			room_type = &"start"
		elif m_node.action == MissionNode.ActionType.GOAL or m_node.action == MissionNode.ActionType.PASSAGE_DOWN:
			room_type = &"goal"
		elif room_type == &"":
			room_type = &"explore"

		var remaining_rooms: int = node_ids.size() - i
		var needed_large: int = 2 - large_count
		var is_forced_large: bool = (room_type == &"boss") or (remaining_rooms <= needed_large) or (room_type == &"combat" and large_count < 2)
		var dungeon_cfg: DungeonConfig = p_config if p_config is DungeonConfig else null
		var size: Vector2i = _calculate_room_size(room_type, dungeon_cfg, is_forced_large)
		if size.x >= 11 or size.y >= 11 or (size.x * size.y >= 100):
			large_count += 1

		var room := RoomData.new(rooms.size(), Rect2i(0, 0, size.x, size.y), room_type)
		room.mission_node_id = node_id
		room.is_required = not bool(m_node.is_optional)
		
		# Blindar el mapping: verificar identidad entre MissionNode y RoomData
		assert(room.mission_node_id == node_id, "MissionNode ID %d does not match RoomData mission_node_id %d" % [node_id, room.mission_node_id])
		if m_node.action == MissionNode.ActionType.BOSS:
			assert(room.room_type == &"boss", "MissionNode BOSS action does not map to boss room_type")

		# Posicionamiento con distribución espacial amplia
		_place_room(room, rooms, grid_bounds)

		node_to_room[node_id] = room
		rooms.append(room)

	print("[SpaceGrammar] Tier distribution: tier3=%d tier4=%d total=%d" % [tier_3_count, tier_4_count, rooms.size()])

	# Medir antes del separator
	_metrics_before_separator = _compute_spatial_metrics_dict(rooms)
	_rooms_before_separator = rooms.duplicate()

	# Consolidar separación espacial AABB con padding mínimo de 2 celdas
	rooms = _RoomSpatialSeparatorScript.separate_rooms(rooms, grid_bounds, _rng, 2)

	# Medir después del separator
	_metrics_after_separator = _compute_spatial_metrics_dict(rooms)

	return rooms

func _calculate_room_size(type: StringName, d_config: DungeonConfig, force_large: bool = false) -> Vector2i:
	var diff: float = d_config.difficulty if d_config != null else 1.0

	if force_large or type == &"boss":
		var lw: int = _rng.randi_range(11, maxi(11, int(14 * minf(diff, 1.5))))
		var lh: int = _rng.randi_range(11, maxi(11, int(14 * minf(diff, 1.5))))
		return Vector2i(lw, lh)

	match type:
		&"start", &"goal":
			# Small (6x6 .. 7x7)
			return Vector2i(_rng.randi_range(6, 7), _rng.randi_range(6, 7))
		&"treasure":
			# Small (5x5 .. 7x7)
			return Vector2i(_rng.randi_range(5, 7), _rng.randi_range(5, 7))
		&"puzzle":
			# Small to Medium (6x6 .. 8x8)
			return Vector2i(_rng.randi_range(6, 8), _rng.randi_range(6, 8))
		&"combat", &"explore":
			var roll: float = _rng.randf()
			if roll < 0.45:
				# Small (6..7)
				return Vector2i(_rng.randi_range(6, 7), _rng.randi_range(6, 7))
			elif roll < 0.85:
				# Medium (8..10)
				return Vector2i(_rng.randi_range(8, 10), _rng.randi_range(8, 10))
			else:
				# Large (11..13)
				return Vector2i(_rng.randi_range(11, 13), _rng.randi_range(11, 13))
		_:
			return Vector2i(_rng.randi_range(6, 9), _rng.randi_range(6, 9))

func _place_room(room: RoomData, existing_rooms: Array[RoomData], bounds: Rect2i) -> void:
	if room.room_type == RoomData.RoomType.START:
		_place_start_room(room, bounds)
		return

	if config.use_mission_aware_placement:
		var placed := _try_mission_aware_placement(room, existing_rooms, bounds)
		if placed:
			return
		# Intentional fallthrough to existing code if mission-aware placement fails.

	_place_room_legacy(room, existing_rooms, bounds)

func _place_start_room(room: RoomData, bounds: Rect2i) -> void:
	var center := bounds.position + bounds.size / 2
	var w: int = room.rect.size.x
	var h: int = room.rect.size.y
	var offset_x: int = rng.randi_range(-4, 4)
	var offset_y: int = rng.randi_range(-4, 4)
	room.rect.position = center - Vector2i(w / 2, h / 2) + Vector2i(offset_x, offset_y)
	room.is_placed = true

func _place_room_legacy(room: RoomData, existing_rooms: Array[RoomData], bounds: Rect2i) -> void:
	var center := bounds.position + bounds.size / 2
	var w: int = room.rect.size.x
	var h: int = room.rect.size.y

	if existing_rooms.is_empty():
		# Habitación inicial (START): cerca del centro o ligeramente desplazada
		var offset_x: int = rng.randi_range(-4, 4)
		var offset_y: int = rng.randi_range(-4, 4)
		room.rect.position = center - Vector2i(w / 2, h / 2) + Vector2i(offset_x, offset_y)
		room.is_placed = true
		return

	# Estrategia principal: posición aleatoria con intentos limitados
	var placed := false
	for _attempt in range(100):
		var rx: int = rng.randi_range(bounds.position.x, bounds.end.x - w)
		var ry: int = rng.randi_range(bounds.position.y, bounds.end.y - h)
		var cand_pos := Vector2i(rx, ry)
		var cand_size := Vector2i(w, h)
		if _is_position_valid(cand_pos, cand_size, bounds, existing_rooms, 2):
			room.rect = Rect2i(cand_pos, cand_size)
			room.is_placed = true
			placed = true
			break

	# Fallback 1: Reducción progresiva de tamaño y búsqueda sin solapamiento
	if not placed:
		tier_3_count += 1
		var shrink_w: int = maxi(5, w - 2)
		var shrink_h: int = maxi(5, h - 2)
		room.rect.size = Vector2i(shrink_w, shrink_h)
		for _attempt in range(150):
			var rx: int = rng.randi_range(bounds.position.x, bounds.end.x - shrink_w)
			var ry: int = rng.randi_range(bounds.position.y, bounds.end.y - shrink_h)
			var cand_pos := Vector2i(rx, ry)
			var cand_size := Vector2i(shrink_w, shrink_h)
			if _is_position_valid(cand_pos, cand_size, bounds, existing_rooms, 1):
				room.rect = Rect2i(cand_pos, cand_size)
				room.is_placed = true
				placed = true
				break

	# Fallback 2: Si aún no cabe, escanear toda la rejilla paso a paso
	if not placed:
		tier_4_count += 1
		var step_x: int = 2
		var step_y: int = 2
		for y in range(bounds.position.y, bounds.end.y - room.rect.size.y, step_y):
			for x in range(bounds.position.x, bounds.end.x - room.rect.size.x, step_x):
				var cand_pos := Vector2i(x, y)
				if _is_position_valid(cand_pos, room.rect.size, bounds, existing_rooms, 1):
					room.rect = Rect2i(cand_pos, room.rect.size)
					room.is_placed = true
					placed = true
					break
			if placed:
				break

func _get_placed_neighbors(room: RoomData, existing_rooms: Array[RoomData]) -> Array[RoomData]:
	var neighbor_ids: Array = mission_graph.get_neighbors(room.mission_node_id)
	var placed: Array[RoomData] = []
	for other in existing_rooms:
		if other.mission_node_id in neighbor_ids and other.is_placed:
			placed.append(other)
	return placed

func _try_mission_aware_placement(
	room: RoomData,
	existing_rooms: Array[RoomData],
	bounds: Rect2i
) -> bool:
	var placed_neighbors := _get_placed_neighbors(room, existing_rooms)
	if placed_neighbors.is_empty(): return false # No spatial anchor, fall back.

	var anchor: Vector2 = _compute_anchor(placed_neighbors)
	var best_candidate: Vector2i = Vector2i.ZERO
	var best_score: float = -INF
	var found_valid: bool = false

	for i in range(config.mission_aware_candidate_count):
		var dir: Vector2i = _DIRECTIONS[rng.randi_range(0, _DIRECTIONS.size() - 1)]
		var distance: float = config.mission_aware_preferred_distance + \
			rng.randf_range(-config.mission_aware_distance_jitter, config.mission_aware_distance_jitter)

		var raw_pos: Vector2 = anchor + Vector2(dir) * distance
		var candidate := Vector2i(round(raw_pos.x), round(raw_pos.y))
		candidate -= room.rect.size / 2

		if not _is_position_valid(candidate, room.rect.size, bounds, existing_rooms):
			continue

		var score := _score_candidate(candidate, room, placed_neighbors, existing_rooms)
		if score > best_score:
			best_score = score
			best_candidate = candidate
			found_valid = true

	if not found_valid: return false
	room.rect.position = best_candidate
	room.is_placed = true
	return true

func _compute_anchor(placed_neighbors: Array[RoomData]) -> Vector2:
	var sum := Vector2.ZERO
	for n in placed_neighbors:
		sum += Vector2(n.get_center())
	return sum / placed_neighbors.size()

func _score_candidate(
	candidate_pos: Vector2i,
	room: RoomData,
	placed_neighbors: Array[RoomData],
	existing_rooms: Array[RoomData]
) -> float:
	var candidate_center := Vector2(candidate_pos) + Vector2(room.rect.size) / 2.0

	var proximity_score := 0.0
	for n in placed_neighbors:
		proximity_score -= abs(candidate_center.distance_to(Vector2(n.get_center())) - config.mission_aware_preferred_distance)

	var min_distance_to_any: float = INF
	for other in existing_rooms:
		if not other.is_placed: continue
		min_distance_to_any = min(min_distance_to_any, candidate_center.distance_to(Vector2(other.get_center())))

	var separation_score: float = 0.0
	if min_distance_to_any != INF:
		separation_score = min_distance_to_any

	var jitter_score: float = rng.randf() * 0.01

	const W_PROXIMITY := 1.0
	const W_SEPARATION := 0.3

	return (W_PROXIMITY * proximity_score) + (W_SEPARATION * separation_score) + jitter_score

func _is_position_valid(pos: Vector2i, size: Vector2i, bounds: Rect2i, existing_rooms: Array[RoomData], margin: int = 2) -> bool:
	if not bounds.encloses(Rect2i(pos, size)):
		return false
	return not _has_overlap(pos, size, existing_rooms, margin)

func _has_overlap(pos: Vector2i, size: Vector2i, existing_rooms: Array[RoomData], margin: int = 2) -> bool:
	var candidate_rect := Rect2i(pos, size)
	for other in existing_rooms:
		if other.is_placed:
			var target_rect: Rect2i = other.expanded(margin) if margin > 0 else other.rect
			if candidate_rect.intersects(target_rect):
				return true
	return false

func _compute_spatial_metrics_dict(rooms: Array[RoomData]) -> Dictionary:
	var result: Dictionary = {}

	if rooms.is_empty():
		result["start_to_centroid_distance"] = 0.0
		result["spatial_angular_uniformity"] = 0.0
		result["spatial_radial_distance_variance"] = 0.0
		result["spatial_radiality_provisional"] = 0.0
		result["spatial_average_center_distance"] = 0.0
		result["spatial_minimum_center_distance"] = 0.0
		result["spatial_bbox_width"] = 0
		result["spatial_bbox_height"] = 0
		result["spatial_bbox_area"] = 0
		result["spatial_bbox_min_x"] = 0
		result["spatial_bbox_max_x"] = 0
		result["spatial_bbox_min_y"] = 0
		result["spatial_bbox_max_y"] = 0
		return result

	# Bounding box
	var min_x: int = 999999
	var max_x: int = -999999
	var min_y: int = 999999
	var max_y: int = -999999
	for r in rooms:
		min_x = mini(min_x, r.rect.position.x)
		max_x = maxi(max_x, r.rect.end.x)
		min_y = mini(min_y, r.rect.position.y)
		max_y = maxi(max_y, r.rect.end.y)
	result["spatial_bbox_min_x"] = min_x
	result["spatial_bbox_max_x"] = max_x
	result["spatial_bbox_min_y"] = min_y
	result["spatial_bbox_max_y"] = max_y
	result["spatial_bbox_width"] = max_x - min_x
	result["spatial_bbox_height"] = max_y - min_y
	result["spatial_bbox_area"] = result["spatial_bbox_width"] * result["spatial_bbox_height"]

	# Centers
	var centers: Array[Vector2i] = []
	var start_center: Vector2i
	var start_found: bool = false
	for r in rooms:
		centers.append(r.get_center())
		if not start_found and r.room_type == &"start":
			start_center = r.get_center()
			start_found = true

	if not start_found:
		start_center = centers[0]

	# Pairwise distances (mean, min, max, stddev)
	var distances: Array[float] = []
	var min_dist: float = 1e9
	for i in range(centers.size()):
		for j in range(i + 1, centers.size()):
			var d: float = centers[i].distance_to(centers[j])
			distances.append(d)
			if d < min_dist:
				min_dist = d

	if distances.size() > 0:
		var s: float = _sum_array(distances)
		var mean_p: float = s / float(distances.size())
		var min_p: float = distances[0]
		var max_p: float = distances[0]
		for d in distances:
			if d < min_p: min_p = d
			if d > max_p: max_p = d
		var var_p: float = 0.0
		for d in distances:
			var_p += (d - mean_p) * (d - mean_p)
		var_p /= float(distances.size())

		result["pairwise_spacing_mean"] = mean_p
		result["pairwise_spacing_min"] = min_p
		result["pairwise_spacing_max"] = max_p
		result["pairwise_spacing_stddev"] = sqrt(var_p)
		result["spatial_average_center_distance"] = mean_p
		result["spatial_minimum_center_distance"] = min_p
	else:
		result["pairwise_spacing_mean"] = 0.0
		result["pairwise_spacing_min"] = 0.0
		result["pairwise_spacing_max"] = 0.0
		result["pairwise_spacing_stddev"] = 0.0
		result["spatial_average_center_distance"] = 0.0
		result["spatial_minimum_center_distance"] = 0.0

	# Nearest neighbor (mean, min, max, stddev)
	var nn_distances: Array[float] = []
	for i in range(centers.size()):
		var nn: float = 1e9
		for j in range(centers.size()):
			if i == j: continue
			var d: float = centers[i].distance_to(centers[j])
			if d < nn: nn = d
		nn_distances.append(nn)

	if nn_distances.size() > 0:
		var s_nn: float = _sum_array(nn_distances)
		var mean_nn: float = s_nn / float(nn_distances.size())
		var min_nn: float = nn_distances[0]
		var max_nn: float = nn_distances[0]
		for d in nn_distances:
			if d < min_nn: min_nn = d
			if d > max_nn: max_nn = d
		var var_nn: float = 0.0
		for d in nn_distances:
			var_nn += (d - mean_nn) * (d - mean_nn)
		var_nn /= float(nn_distances.size())

		result["nearest_neighbor_mean"] = mean_nn
		result["nearest_neighbor_min"] = min_nn
		result["nearest_neighbor_max"] = max_nn
		result["nearest_neighbor_stddev"] = sqrt(var_nn)
		result["nearest_neighbor_cv"] = sqrt(var_nn) / mean_nn if mean_nn > 0 else 0.0
	else:
		result["nearest_neighbor_mean"] = 0.0
		result["nearest_neighbor_min"] = 0.0
		result["nearest_neighbor_max"] = 0.0
		result["nearest_neighbor_stddev"] = 0.0
		result["nearest_neighbor_cv"] = 0.0

	# Start centrality
	var centroid: Vector2i = _compute_centroid(centers)
	result["start_to_centroid_distance"] = start_center.distance_to(centroid)

	# Angular uniformity around START
	var angles: Array[float] = []
	for c in centers:
		if c == start_center:
			continue
		angles.append(atan2(float(c.y - start_center.y), float(c.x - start_center.x)))

	if angles.size() > 0:
		var sum_cos: float = 0.0
		var sum_sin: float = 0.0
		for a in angles:
			sum_cos += cos(a)
			sum_sin += sin(a)
		var mean_resultant: float = sqrt(sum_cos * sum_cos + sum_sin * sum_sin) / float(angles.size())
		result["spatial_angular_uniformity"] = 1.0 - mean_resultant
	else:
		result["spatial_angular_uniformity"] = 0.0

	# Radial distance variance
	var radial_dists: Array[float] = []
	for c in centers:
		if c == start_center:
			continue
		radial_dists.append(start_center.distance_to(c))

	if radial_dists.size() > 0:
		var mean_r: float = float(_sum_array(radial_dists)) / float(radial_dists.size())
		var var_r: float = 0.0
		for d in radial_dists:
			var_r += (d - mean_r) * (d - mean_r)
		var_r /= float(radial_dists.size())
		result["spatial_radial_distance_variance"] = var_r
	else:
		result["spatial_radial_distance_variance"] = 0.0

	# Provisional radiality — DIAGNOSTIC ONLY, NOT A CANONICAL METRIC.
	# Normalizes three spatial measurements and averages them. Mixed magnitudes
	# with arbitrary thresholds. Do NOT use for baseline decisions or comparisons.
	# Only for quick inspection until a definitive composite is defined later.
	var c_norm: float = minf(result["start_to_centroid_distance"] / 20.0, 1.0)
	var a_norm: float = result["spatial_angular_uniformity"]
	var v_norm: float = minf(result["spatial_radial_distance_variance"] / 100.0, 1.0)
	result["spatial_radiality_provisional"] = (c_norm + a_norm + v_norm) / 3.0

	return result

func _compute_centroid(points: Array[Vector2i]) -> Vector2i:
	if points.is_empty():
		return Vector2i(0, 0)
	var sx: int = 0
	var sy: int = 0
	for p in points:
		sx += p.x
		sy += p.y
	return Vector2i(sx / points.size(), sy / points.size())

static func _sum_array(arr: Array) -> float:
	var s: float = 0.0
	for v in arr:
		s += float(v)
	return s
