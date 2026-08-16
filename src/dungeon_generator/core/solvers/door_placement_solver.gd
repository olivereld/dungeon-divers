class_name DoorPlacementSolver
extends RefCounted

## Cerebro arquitectónico y topológico para la colocación de puertas.
## Valida que una puerta SOLO se coloque si existe un marco de muros opuestos (cuello de botella de 1 celda)
## que permita bloquear físicamente el paso. Descarta posiciones abiertas o ambiguas.

## Valida si una posición específica tiene la estructura física de un vano/marco de puerta válido.
func is_valid_doorway(grid: CellGrid, pos: Vector2i) -> bool:
	if not grid.is_in_bounds(pos):
		return false

	var cell: CellGrid.CellType = grid.get_cell(pos)
	# Solo puede colocarse sobre un pasillo o umbral transitable (no sobre muro ni spawn/goal)
	if cell != CellGrid.CellType.CORRIDOR and cell != CellGrid.CellType.DOOR:
		return false

	var left: CellGrid.CellType = grid.get_cell(pos + Vector2i(-1, 0))
	var right: CellGrid.CellType = grid.get_cell(pos + Vector2i(1, 0))
	var up: CellGrid.CellType = grid.get_cell(pos + Vector2i(0, -1))
	var down: CellGrid.CellType = grid.get_cell(pos + Vector2i(0, 1))

	var is_left_wall: bool = (left == CellGrid.CellType.WALL or not grid.is_in_bounds(pos + Vector2i(-1, 0)))
	var is_right_wall: bool = (right == CellGrid.CellType.WALL or not grid.is_in_bounds(pos + Vector2i(1, 0)))
	var is_up_wall: bool = (up == CellGrid.CellType.WALL or not grid.is_in_bounds(pos + Vector2i(0, -1)))
	var is_down_wall: bool = (down == CellGrid.CellType.WALL or not grid.is_in_bounds(pos + Vector2i(0, 1)))

	var is_up_walkable: bool = grid.is_walkable(pos + Vector2i(0, -1))
	var is_down_walkable: bool = grid.is_walkable(pos + Vector2i(0, 1))
	var is_left_walkable: bool = grid.is_walkable(pos + Vector2i(-1, 0))
	var is_right_walkable: bool = grid.is_walkable(pos + Vector2i(1, 0))

	# Caso 1: Pasillo Norte-Sur (Muros a Izquierda y Derecha, camino libre Arriba y Abajo)
	var valid_vertical_passage: bool = is_left_wall and is_right_wall and is_up_walkable and is_down_walkable

	# Caso 2: Pasillo Este-Oeste (Muros Arriba y Abajo, camino libre a Izquierda y Derecha)
	var valid_horizontal_passage: bool = is_up_wall and is_down_wall and is_left_walkable and is_right_walkable

	# Debe cumplir estrictamente uno de los dos casos. Si no tiene muros en ambos lados opuestos, NO ES UNA PUERTA VÁLIDA.
	return valid_vertical_passage or valid_horizontal_passage

## Evalúa todas las conexiones y coloca puertas únicamente donde exista coherencia arquitectónica.
func place_doors(grid: CellGrid, rooms: Array[RoomData]) -> void:
	var placed_doors: Array[Vector2i] = []

	for room in rooms:
		var valid_room_doors: Array[Vector2i] = []

		# Evaluar cada punto de conexión registrado en el perímetro de la habitación
		for pt in room.connections:
			if not grid.is_in_bounds(pt):
				continue

			# 1. Comprobar si el punto directo es un vano válido
			if is_valid_doorway(grid, pt):
				if _can_place_door_near(pt, placed_doors):
					valid_room_doors.append(pt)
					placed_doors.append(pt)
			else:
				# 2. Si el punto exacto no tiene muros (ej. Esquina o pasillo ancho), buscar en vecinos inmediatos del perímetro
				var candidates: Array[Vector2i] = grid.get_neighbors_4(pt)
				for cand in candidates:
					# Verificar que esté en el borde del rectángulo de la habitación
					if room.expanded(1).has_point(cand) and is_valid_doorway(grid, cand):
						if _can_place_door_near(cand, placed_doors):
							valid_room_doors.append(cand)
							placed_doors.append(cand)
							break

		# Aplicar las puertas válidas encontradas
		for door_pos in valid_room_doors:
			grid.set_cell(door_pos, CellGrid.CellType.DOOR)

## Encuentra el mejor umbral para colocar una LOCKED_DOOR en una habitación puzzle.
func place_locked_door(grid: CellGrid, room: RoomData, item_id: String) -> bool:
	# 1. Buscar entre las puertas ya existentes de la habitación
	for pt in room.connections:
		if grid.is_in_bounds(pt) and grid.get_cell(pt) == CellGrid.CellType.DOOR:
			grid.set_cell(pt, CellGrid.CellType.LOCKED_DOOR)
			grid.set_metadata(pt, "required_item", item_id)
			return true

	# 2. Buscar cualquier vano válido en el perímetro expandido de la sala
	var outer_bounds: Rect2i = room.expanded(1)
	for y in range(outer_bounds.position.y, outer_bounds.end.y):
		for x in range(outer_bounds.position.x, outer_bounds.end.x):
			var p := Vector2i(x, y)
			if (p.x == outer_bounds.position.x or p.x == outer_bounds.end.x - 1 or p.y == outer_bounds.position.y or p.y == outer_bounds.end.y - 1):
				if is_valid_doorway(grid, p):
					grid.set_cell(p, CellGrid.CellType.LOCKED_DOOR)
					grid.set_metadata(p, "required_item", item_id)
					return true

	# 3. Fallback: Si no hay un vano con muros laterales, colocar en el primer punto de conexión
	for pt in room.connections:
		if grid.is_in_bounds(pt) and grid.is_walkable(pt):
			grid.set_cell(pt, CellGrid.CellType.LOCKED_DOOR)
			grid.set_metadata(pt, "required_item", item_id)
			return true

	return false

## Evita colocar puertas duplicadas pegadas (distancia mínima de 2 celdas entre puertas)
func _can_place_door_near(pos: Vector2i, existing: Array[Vector2i], min_dist: int = 2) -> bool:
	for ex in existing:
		var dist: int = absi(pos.x - ex.x) + absi(pos.y - ex.y)
		if dist < min_dist:
			return false
	return true
