class_name SpaceGrammar
extends RefCounted

## Traduce el grafo de misiones en habitaciones físicas (RoomData) posicionadas sin solapamiento
## y distribuidas armónicamente por el espacio disponible de la mazmorra.

var _rng: RandomNumberGenerator

func _init() -> void:
	_rng = RandomNumberGenerator.new()

func generate(mission_graph: DungeonGraph, config: DungeonConfig, random_seed: int = 0) -> Array[RoomData]:
	if random_seed != 0:
		_rng.seed = random_seed
	elif config != null and config.use_fixed_seed:
		_rng.seed = config.seed
	else:
		_rng.randomize()

	var rooms: Array[RoomData] = []
	var grid_w: int = config.grid_width if config != null else 64
	var grid_h: int = config.grid_height if config != null else 64
	var grid_bounds := Rect2i(3, 3, grid_w - 6, grid_h - 6)

	var node_ids: Array[int] = mission_graph.get_topological_order()
	if node_ids.is_empty():
		node_ids = mission_graph.get_all_node_ids()

	var node_to_room: Dictionary = {} # node_id -> RoomData

	for node_id in node_ids:
		var node_data: Dictionary = mission_graph.get_node_data(node_id)
		var m_node: MissionNode = MissionNode.from_dictionary(node_data)

		var room_type: StringName = m_node.room_type_hint
		if room_type == &"":
			room_type = &"explore"

		var size: Vector2i = _calculate_room_size(room_type, config)
		var room := RoomData.new(rooms.size(), Rect2i(0, 0, size.x, size.y), room_type)
		room.mission_node_id = node_id
		room.is_required = not m_node.is_optional

		# Posicionamiento con distribución espacial amplia
		_place_room(room, rooms, grid_bounds)

		node_to_room[node_id] = room
		rooms.append(room)

	# Registrar conexiones entre habitaciones a partir de las aristas del grafo
	for node_id in node_ids:
		var room_a: RoomData = node_to_room[node_id]
		for succ_id in mission_graph.get_successors(node_id):
			if node_to_room.has(succ_id):
				var room_b: RoomData = node_to_room[succ_id]
				if not room_a.connected_room_ids.has(room_b.id):
					room_a.connected_room_ids.append(room_b.id)
				if not room_b.connected_room_ids.has(room_a.id):
					room_b.connected_room_ids.append(room_a.id)

	return rooms

func _calculate_room_size(type: StringName, config: DungeonConfig) -> Vector2i:
	var diff: float = config.difficulty if config != null else 1.0
	var min_w: int = 6
	var max_w: int = 10
	var min_h: int = 6
	var max_h: int = 10

	match type:
		&"start":
			min_w = 6; max_w = 8
			min_h = 6; max_h = 8
		&"goal":
			min_w = 6; max_w = 8
			min_h = 6; max_h = 8
		&"boss":
			min_w = int(10 * minf(diff, 1.5)); max_w = int(14 * minf(diff, 1.5))
			min_h = int(10 * minf(diff, 1.5)); max_h = int(14 * minf(diff, 1.5))
		&"combat":
			min_w = 7; max_w = 11
			min_h = 7; max_h = 11
		&"treasure":
			min_w = 5; max_w = 7
			min_h = 5; max_h = 7
		&"puzzle":
			min_w = 6; max_w = 9
			min_h = 6; max_h = 9
		&"explore":
			min_w = 7; max_w = 11
			min_h = 7; max_h = 11

	var w: int = _rng.randi_range(min_w, max_w)
	var h: int = _rng.randi_range(min_h, max_h)
	return Vector2i(w, h)

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

	var max_dim: float = float(mini(bounds.size.x, bounds.size.y))
	var room_idx: int = existing_rooms.size()

	# Radio inicial dinámico para expandir la mazmorra de forma progresiva y balanceada
	var min_initial_radius: float = clampf(max_dim * 0.12 * float(room_idx), 6.0, max_dim * 0.42)
	var max_radius: float = max_dim * 0.48

	var placed := false
	var start_angle: float = _rng.randf_range(0.0, TAU)
	var angle_step: float = 0.25
	var radius_step: float = 2.0
	var current_radius: float = min_initial_radius

	# Margen de 3 celdas entre habitaciones para que los muros y corredores no se peguen
	var margin: int = 3

	while current_radius < max_radius and not placed:
		var current_angle: float = start_angle
		var angle_end: float = start_angle + TAU

		while current_angle < angle_end and not placed:
			var candidate_x: int = int(center.x + cos(current_angle) * current_radius) - w / 2
			var candidate_y: int = int(center.y + sin(current_angle) * current_radius) - h / 2
			var candidate_rect := Rect2i(candidate_x, candidate_y, w, h)

			if bounds.encloses(candidate_rect):
				var collides := false
				for other in existing_rooms:
					if candidate_rect.intersects(other.expanded(margin)):
						collides = true
						break
				if not collides:
					room.rect = candidate_rect
					placed = true
					break

			current_angle += angle_step
		current_radius += radius_step

	# Fallback 1: Si no cupo con el radio grande, buscar en cualquier parte de bounds con margen
	if not placed:
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

	# Fallback 2: Reducción progresiva de tamaño y búsqueda exhaustiva sin solapamiento
	if not placed:
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

	# Fallback 3: Si aún no cabe, escanear toda la rejilla paso a paso para hallar el primer hueco libre
	if not placed:
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
