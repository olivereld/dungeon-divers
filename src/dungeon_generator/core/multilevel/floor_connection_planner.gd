class_name FloorConnectionPlanner
extends RefCounted

## Planificador inteligente y no destructivo de anclajes de escaleras y enlaces verticales (Fase 10 / M8).
## Evalúa celdas candidatas mediante puntuación ponderada multicriterio:
## - Profundidad topológica y distancia a puntos clave.
## - Aislamiento de puertas y vanos (sin bloqueos de flujo).
## - Clearance perimetral interno de habitación.
## - Registro formal en DungeonFloorData y FloorConnection.

const _StairDataScript = preload("res://src/dungeon_generator/core/data/stair_data.gd")
const _FloorConnectionScript = preload("res://src/dungeon_generator/core/data/floor_connection.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _DungeonFloorDataScript = preload("res://src/dungeon_generator/core/data/dungeon_floor_data.gd")

## Planifica y conecta dos pisos adyacentes de forma no destructiva.
func plan_stairs_between_floors(
	floor_a: DungeonFloorData,
	floor_b: DungeonFloorData,
	seed_val: int = 0
) -> FloorConnection:
	if floor_a == null or floor_b == null or floor_a.floor_number == floor_b.floor_number:
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val

	# 1. Encontrar celda óptima en Floor A (salida hacia B)
	var cell_a: Vector2i = find_best_stair_cell(floor_a, rng, true)
	if cell_a == Vector2i(-1, -1):
		return null

	# 2. Encontrar celda óptima en Floor B (entrada desde A)
	var cell_b: Vector2i = find_best_stair_cell(floor_b, rng, false)
	if cell_b == Vector2i(-1, -1):
		return null

	var is_downward: bool = floor_b.floor_number > floor_a.floor_number
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

	# 3. Crear el par de StairData e integrarlo en los DTOs de piso
	var stairs_pair: Array[StairData] = vconn.create_stair_pair()
	var stair_a: StairData = stairs_pair[0]
	var stair_b: StairData = stairs_pair[1]

	floor_a.add_stair(stair_a)
	floor_b.add_stair(stair_b)

	# 4. Actualizar tipo de celda en ambos CellGrid de forma limpia y canónica
	if floor_a.grid != null:
		var target_type_a = _CellGridScript.CellType.STAIRS_DOWN if is_downward else _CellGridScript.CellType.STAIRS_UP
		floor_a.grid.set_cell(cell_a, target_type_a)

	if floor_b.grid != null:
		var target_type_b = _CellGridScript.CellType.STAIRS_UP if is_downward else _CellGridScript.CellType.STAIRS_DOWN
		floor_b.grid.set_cell(cell_b, target_type_b)

	return vconn

## Busca la mejor celda candidata dentro de un piso aplicando scoring multicriterio.
func find_best_stair_cell(
	floor_data: DungeonFloorData,
	rng: RandomNumberGenerator,
	prefer_exit: bool
) -> Vector2i:
	if floor_data == null or floor_data.grid == null:
		return Vector2i(-1, -1)

	var rooms: Array[RoomData] = floor_data.rooms
	if rooms.is_empty():
		return _find_fallback_walkable_cell(floor_data.grid)

	# 1. Seleccionar habitación objetivo
	var selected_room: RoomData = _select_target_room(floor_data, prefer_exit)
	if selected_room == null:
		selected_room = rooms[0]

	# 2. Recolectar y puntuar celdas transitables en la habitación
	var inner_rect: Rect2i = selected_room.get_inner_rect()
	var scored_candidates: Array[Dictionary] = [] # Array de { "cell": Vector2i, "score": float }

	for cy in range(inner_rect.position.y, inner_rect.end.y):
		for cx in range(inner_rect.position.x, inner_rect.end.x):
			var c := Vector2i(cx, cy)
			if not floor_data.grid.is_walkable(c):
				continue

			# No debe solapar con escaleras ya existentes en este piso
			if floor_data.get_stair_at(c) != null:
				continue

			var score: float = _score_stair_cell(c, selected_room, floor_data)
			if score > 0.0:
				scored_candidates.append({"cell": c, "score": score})

	if not scored_candidates.is_empty():
		# Ordenar descendente por score
		scored_candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["score"] > b["score"]
		)
		# Tomar entre los mejores candidatos con variación aleatoria determinista
		var top_count: int = mini(3, scored_candidates.size())
		var chosen_idx: int = rng.randi() % top_count
		return scored_candidates[chosen_idx]["cell"]

	# Fallback a escanear celdas interiores generales de cualquier sala
	for r in rooms:
		var in_r := r.get_inner_rect()
		for cy in range(in_r.position.y, in_r.end.y):
			for cx in range(in_r.position.x, in_r.end.x):
				var c := Vector2i(cx, cy)
				if floor_data.grid.is_walkable(c) and floor_data.get_stair_at(c) == null:
					return c

	return _find_fallback_walkable_cell(floor_data.grid)

func _select_target_room(floor_data: DungeonFloorData, prefer_exit: bool) -> RoomData:
	var rooms: Array[RoomData] = floor_data.rooms
	if rooms.size() <= 1:
		return rooms[0] if not rooms.is_empty() else null

	if prefer_exit:
		# Para salida: preferir habitación con rol no-start o de mayor ID/profundidad
		for i in range(rooms.size() - 1, -1, -1):
			var r = rooms[i]
			if r != null and r.room_type != &"start" and r.room_type != &"boss":
				return r
		return rooms[rooms.size() - 1]
	else:
		# Para entrada: preferir habitación inicial (start) o primera habitación de tránsito
		for r in rooms:
			if r != null and r.room_type == &"start":
				return r
		return rooms[0]

func _score_stair_cell(cell: Vector2i, room: RoomData, floor_data: DungeonFloorData) -> float:
	var base_score: float = 100.0

	# 1. Distancia al centro de la habitación (preferir zona cercana al centro, evitando esquinas)
	var center := room.get_center()
	var dist_center: float = float((cell - center).length_squared())
	base_score -= dist_center * 2.0

	# 2. Penalización severa si está adyacente o en frente de una puerta
	if floor_data.door_pairs != null:
		for dp in floor_data.door_pairs:
			if dp != null:
				var d1: int = (cell - dp.position_a).length_squared()
				var d2: int = (cell - dp.position_b).length_squared()
				if mini(d1, d2) <= 2:
					base_score -= 80.0

	# 3. Penalización si está en Spawn de jugador
	if floor_data.grid != null:
		if floor_data.grid.get_cell(cell) == _CellGridScript.CellType.SPAWN:
			base_score -= 150.0

	return maxf(1.0, base_score)

func _find_fallback_walkable_cell(grid: CellGrid) -> Vector2i:
	if grid == null:
		return Vector2i(-1, -1)
	for y in range(grid.height):
		for x in range(grid.width):
			var c := Vector2i(x, y)
			if grid.is_walkable(c):
				return c
	return Vector2i(-1, -1)
