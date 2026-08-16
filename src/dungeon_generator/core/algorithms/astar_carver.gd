class_name AStarCarver
extends RefCounted

## Tallador inteligente de pasillos mediante AStar2D ponderado.
## Reutiliza pasillos existentes, evita atravesar salas ajenas y crea intersecciones limpias en 'T' e 'Y'.

static func carve_connections(
	grid: CellGrid,
	rooms: Array[RoomData],
	connections: Array[Vector2i],
	config: DungeonConfig = null,
	rng: RandomNumberGenerator = null
) -> void:
	if connections.is_empty() or rooms.size() < 2:
		return

	if rng == null:
		rng = RandomNumberGenerator.new()

	var width: int = grid.width
	var height: int = grid.height
	var astar := AStar2D.new()

	# 1. Registrar todos los puntos en la rejilla AStar con pesos iniciales
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var id: int = _get_id(pos, width)
			astar.add_point(id, Vector2(x, y))

			var cell_type: CellGrid.CellType = grid.get_cell(pos)
			match cell_type:
				CellGrid.CellType.FLOOR:
					# Habitaciones existentes: costo alto para desincentivar atravesarlas innecesariamente
					astar.set_point_weight_scale(id, 35.0)
				CellGrid.CellType.CORRIDOR:
					# Pasillos existentes: costo mínimo para incentivar la reutilización
					astar.set_point_weight_scale(id, 1.0)
				_:
					# Muros/Roca sólida: costo medio-alto
					astar.set_point_weight_scale(id, 15.0)

	# 2. Conectar vecinos ortogonales (4 direcciones)
	for y in range(height):
		for x in range(width):
			var id: int = _get_id(Vector2i(x, y), width)
			if x + 1 < width:
				astar.connect_points(id, _get_id(Vector2i(x + 1, y), width))
			if y + 1 < height:
				astar.connect_points(id, _get_id(Vector2i(x, y + 1), width))

	# 3. Trazar cada conexión entre pares de habitaciones
	for conn in connections:
		var u: int = conn.x
		var v: int = conn.y
		if u < 0 or u >= rooms.size() or v < 0 or v >= rooms.size():
			continue

		var room_a: RoomData = rooms[u]
		var room_b: RoomData = rooms[v]

		var start_pt: Vector2i = room_a.get_nearest_edge_point(room_b.get_center())
		var end_pt: Vector2i = room_b.get_nearest_edge_point(room_a.get_center())

		if not grid.is_in_bounds(start_pt) or not grid.is_in_bounds(end_pt):
			continue

		var start_id: int = _get_id(start_pt, width)
		var end_id: int = _get_id(end_pt, width)

		# Habilitar acceso de bajo costo en los umbrales específicos de inicio y fin
		astar.set_point_weight_scale(start_id, 1.0)
		astar.set_point_weight_scale(end_id, 1.0)

		var path: PackedVector2Array = astar.get_point_path(start_id, end_id)
		var carved_pts: Array[Vector2i] = []
		if path.is_empty():
			# Fallback directo si no hay camino en el grafo A*
			_carve_straight_fallback(grid, start_pt, end_pt)
		else:
			for pt_vec in path:
				var pt := Vector2i(int(pt_vec.x), int(pt_vec.y))
				carved_pts.append(pt)
				if grid.is_in_bounds(pt):
					var current_cell := grid.get_cell(pt)
					if current_cell == CellGrid.CellType.WALL:
						grid.set_cell(pt, CellGrid.CellType.CORRIDOR)
						astar.set_point_weight_scale(_get_id(pt, width), 1.0)

			var c_width: int = config.corridor_width if config != null else 2
			if c_width >= 2:
				_widen_corridor(grid, carved_pts, c_width, start_pt, end_pt, astar, width)

		# Asegurar que los puntos de inicio y fin queden tallados
		if grid.is_in_bounds(start_pt) and grid.get_cell(start_pt) == CellGrid.CellType.WALL:
			grid.set_cell(start_pt, CellGrid.CellType.CORRIDOR)
		if grid.is_in_bounds(end_pt) and grid.get_cell(end_pt) == CellGrid.CellType.WALL:
			grid.set_cell(end_pt, CellGrid.CellType.CORRIDOR)

		# Registrar conexiones para colocación de puertas
		if not room_a.connections.has(start_pt):
			room_a.connections.append(start_pt)
		if not room_b.connections.has(end_pt):
			room_b.connections.append(end_pt)

		if not room_a.connected_room_ids.has(room_b.id):
			room_a.connected_room_ids.append(room_b.id)
		if not room_b.connected_room_ids.has(room_a.id):
			room_b.connected_room_ids.append(room_a.id)

static func _widen_corridor(
	grid: CellGrid,
	path: Array[Vector2i],
	c_width: int,
	start_pt: Vector2i,
	end_pt: Vector2i,
	astar: AStar2D,
	grid_width: int
) -> void:
	if c_width <= 1 or path.size() < 2:
		return

	for i in range(path.size() - 1):
		var curr: Vector2i = path[i]
		var next: Vector2i = path[i + 1]
		# Preservar el cuello de botella de 1 celda en los extremos para el marco de puerta
		if curr == start_pt or curr == end_pt or next == start_pt or next == end_pt:
			continue

		var dir: Vector2i = next - curr
		var perp := Vector2i(-dir.y, dir.x)
		if perp == Vector2i.ZERO:
			continue

		for offset in range(1, c_width):
			var side_pt: Vector2i = curr + perp * offset
			if grid.is_in_bounds(side_pt) and grid.get_cell(side_pt) == CellGrid.CellType.WALL:
				grid.set_cell(side_pt, CellGrid.CellType.CORRIDOR)
				if astar != null:
					astar.set_point_weight_scale(_get_id(side_pt, grid_width), 1.0)

static func _carve_straight_fallback(grid: CellGrid, from: Vector2i, to: Vector2i) -> void:
	var curr := from
	while curr.x != to.x:
		if grid.is_in_bounds(curr) and grid.get_cell(curr) == CellGrid.CellType.WALL:
			grid.set_cell(curr, CellGrid.CellType.CORRIDOR)
		curr.x += 1 if to.x > curr.x else -1

	while curr.y != to.y:
		if grid.is_in_bounds(curr) and grid.get_cell(curr) == CellGrid.CellType.WALL:
			grid.set_cell(curr, CellGrid.CellType.CORRIDOR)
		curr.y += 1 if to.y > curr.y else -1

	if grid.is_in_bounds(to) and grid.get_cell(to) == CellGrid.CellType.WALL:
		grid.set_cell(to, CellGrid.CellType.CORRIDOR)

static func _get_id(pos: Vector2i, grid_width: int) -> int:
	return pos.y * grid_width + pos.x
