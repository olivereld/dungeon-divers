class_name SpaceGrammar
extends RefCounted

## Traduce el grafo de misiones en habitaciones físicas (RoomData) posicionadas sin solapamiento
## y distribuidas armónicamente por el espacio disponible de la mazmorra.

const _RoomSpatialSeparatorScript = preload("res://src/dungeon_generator/core/topology/room_spatial_separator.gd")

var _rng: RandomNumberGenerator

var tier_3_count: int = 0
var tier_4_count: int = 0
var _metrics_before_separator: Dictionary = {}
var _metrics_after_separator: Dictionary = {}
var _rooms_before_separator: Array[RoomData] = []

func _init() -> void:
	_rng = RandomNumberGenerator.new()

func generate(mission_graph: DungeonGraph, config: DungeonConfig, random_seed: int = 0) -> Array[RoomData]:
	if random_seed != 0:
		_rng.seed = random_seed
	elif config != null and config.seed != 0:
		_rng.seed = config.seed
	else:
		_rng.seed = 1337

	var rooms: Array[RoomData] = []
	var grid_w: int = config.grid_width if config != null else 64
	var grid_h: int = config.grid_height if config != null else 64
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
		var size: Vector2i = _calculate_room_size(room_type, config, is_forced_large)
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

func _calculate_room_size(type: StringName, config: DungeonConfig, force_large: bool = false) -> Vector2i:
	var diff: float = config.difficulty if config != null else 1.0

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
	var center := bounds.position + bounds.size / 2
	var w: int = room.rect.size.x
	var h: int = room.rect.size.y

	if existing_rooms.is_empty():
		# Habitación inicial (START): cerca del centro o ligeramente desplazada
		var offset_x: int = _rng.randi_range(-4, 4)
		var offset_y: int = _rng.randi_range(-4, 4)
		room.rect.position = center - Vector2i(w / 2, h / 2) + Vector2i(offset_x, offset_y)
		return

	# Estrategia principal: posición aleatoria con intentos limitados
	var placed := false
	for _attempt in range(100):
		var rx: int = _rng.randi_range(bounds.position.x, bounds.end.x - w)
		var ry: int = _rng.randi_range(bounds.position.y, bounds.end.y - h)
		var cand := Rect2i(rx, ry, w, h)
		var collides := false
		for other in existing_rooms:
			if cand.intersects(other.expanded(2)):
				collides = true
				break
		if not collides:
			room.rect = cand
			placed = true
			break

	# Fallback 1: Reducción progresiva de tamaño y búsqueda sin solapamiento
	if not placed:
		tier_3_count += 1
		var shrink_w: int = maxi(5, w - 2)
		var shrink_h: int = maxi(5, h - 2)
		room.rect.size = Vector2i(shrink_w, shrink_h)
		for _attempt in range(150):
			var rx: int = _rng.randi_range(bounds.position.x, bounds.end.x - shrink_w)
			var ry: int = _rng.randi_range(bounds.position.y, bounds.end.y - shrink_h)
			var cand := Rect2i(rx, ry, shrink_w, shrink_h)
			var collides := false
			for other in existing_rooms:
				if cand.intersects(other.expanded(1)):
					collides = true
					break
			if not collides:
				room.rect = cand
				placed = true
				break

	# Fallback 2: Si aún no cabe, escanear toda la rejilla paso a paso
	if not placed:
		tier_4_count += 1
		var step_x: int = 2
		var step_y: int = 2
		for y in range(bounds.position.y, bounds.end.y - room.rect.size.y, step_y):
			for x in range(bounds.position.x, bounds.end.x - room.rect.size.x, step_x):
				var cand := Rect2i(x, y, room.rect.size.x, room.rect.size.y)
				var collides := false
				for other in existing_rooms:
					if cand.intersects(other.expanded(1)):
						collides = true
						break
				if not collides:
					room.rect = cand
					placed = true
					break
			if placed:
				break

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
	else:
		result["nearest_neighbor_mean"] = 0.0
		result["nearest_neighbor_min"] = 0.0
		result["nearest_neighbor_max"] = 0.0
		result["nearest_neighbor_stddev"] = 0.0

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
