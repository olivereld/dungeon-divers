class_name StairPlanner
extends RefCounted

## Planificador no destructivo de escaleras y enlaces verticales (Fase 10).
## Selecciona ubicaciones óptimas y seguras para escaleras entre pisos adyacentes
## garantizando que no se bloqueen vanos, puertas ni el camino crítico.

const _StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const _FloorConnectionScript = preload("res://src/dungeon_generator/core/data/floor_connection.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

## Planifica y conecta dos pisos adyacentes mediante un enlace vertical (FloorConnection).
func plan_stairs_between_floors(
	floor_a: DungeonFloorData,
	floor_b: DungeonFloorData,
	seed_val: int = 0
) -> FloorConnection:
	if floor_a == null or floor_b == null or floor_a.floor_number == floor_b.floor_number:
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# 1. Encontrar celda válida en Floor A (Preferir habitación final o no-spawn)
	var cell_a: Vector2i = _find_stair_candidate_cell(floor_a, rng, true)
	if cell_a == Vector2i(-1, -1):
		return null

	# 2. Encontrar celda válida en Floor B (Preferir habitación inicial de Floor B)
	var cell_b: Vector2i = _find_stair_candidate_cell(floor_b, rng, false)
	if cell_b == Vector2i(-1, -1):
		return null

	var is_downward: bool = floor_b.floor_number < floor_a.floor_number
	var conn_id: String = "vconn_f%d_f%d" % [floor_a.floor_number, floor_b.floor_number]
	var stair_a_id: String = "stair_f%d_%s" % [floor_a.floor_number, "down" if is_downward else "up"]
	var stair_b_id: String = "stair_f%d_%s" % [floor_b.floor_number, "up" if is_downward else "down"]

	var vconn: FloorConnection = _FloorConnectionScript.new(
		conn_id,
		floor_a.floor_number,
		floor_b.floor_number,
		stair_a_id,
		stair_b_id,
		cell_a,
		cell_b
	)

	# 3. Crear el par de StairData e integrarlo en ambos pisos
	var stairs_pair: Array[StairData] = vconn.create_stair_pair()
	var stair_a: StairData = stairs_pair[0]
	var stair_b: StairData = stairs_pair[1]

	floor_a.add_stair(stair_a)
	floor_b.add_stair(stair_b)

	# 4. Actualizar tipo de celda en ambos CellGrid de forma no destructiva
	if floor_a.grid != null:
		var target_type_a = _CellGridScript.CellType.STAIRS_DOWN if is_downward else _CellGridScript.CellType.STAIRS_UP
		floor_a.grid.set_cell(cell_a, target_type_a)

	if floor_b.grid != null:
		var target_type_b = _CellGridScript.CellType.STAIRS_UP if is_downward else _CellGridScript.CellType.STAIRS_DOWN
		floor_b.grid.set_cell(cell_b, target_type_b)

	return vconn

## Busca una celda transitable segura dentro de una habitación seleccionada.
func _find_stair_candidate_cell(
	floor_data: DungeonFloorData,
	rng: RandomNumberGenerator,
	prefer_exit_room: bool
) -> Vector2i:
	if floor_data == null or floor_data.grid == null:
		return Vector2i(-1, -1)

	var rooms: Array[RoomData] = floor_data.rooms
	if rooms.is_empty():
		# Fallback a escanear celdas transitables del grid
		return _find_first_walkable_cell(floor_data.grid)

	# Seleccionar habitación candidata
	var selected_room: RoomData = null
	if prefer_exit_room and rooms.size() > 1:
		selected_room = rooms[rooms.size() - 1]
	else:
		selected_room = rooms[0]

	# Buscar celda interior aleatoria con margen de 1 respecto a los bordes
	var inner_rect: Rect2i = selected_room.get_inner_rect()
	var candidate_cells: Array[Vector2i] = []

	for cy in range(inner_rect.position.y, inner_rect.end.y):
		for cx in range(inner_rect.position.x, inner_rect.end.x):
			var c := Vector2i(cx, cy)
			if floor_data.grid.is_walkable(c):
				# Verificar que no coincida con una escalera existente
				if floor_data.get_stair_at(c) == null:
					candidate_cells.append(c)

	if not candidate_cells.is_empty():
		return candidate_cells[rng.randi() % candidate_cells.size()]

	return _find_first_walkable_cell(floor_data.grid)

func _find_first_walkable_cell(grid: CellGrid) -> Vector2i:
	if grid == null:
		return Vector2i(-1, -1)
	for y in range(grid.height):
		for x in range(grid.width):
			var c := Vector2i(x, y)
			if grid.is_walkable(c):
				return c
	return Vector2i(-1, -1)
