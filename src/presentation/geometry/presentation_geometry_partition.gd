class_name PresentationGeometryPartition
extends RefCounted

## Particionador de geometría para la capa de presentación.
## Segmenta las celdas de un CellGrid en particiones locales por sala (PresentationRoomGeometry)
## y celdas de corredores, asignando a cada una su perfil arquitectónico resuelto.
## 100% de solo lectura e inmutable sobre CellGrid.

const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")

var rooms_geometry: Dictionary = {} # room_id -> PresentationRoomGeometry
var corridor_floor_cells: Array[Vector2i] = []
var corridor_wall_cells: Array[Vector2i] = []
var room_id_by_cell: Dictionary = {} # Vector2i -> int (room_id)

func build_partition(
	grid: CellGrid,
	room_contexts: Array, # Array[PresentationRoomContext]
	semantic_result: DungeonSemanticResult
) -> void:
	rooms_geometry.clear()
	corridor_floor_cells.clear()
	corridor_wall_cells.clear()
	room_id_by_cell.clear()

	if grid == null or room_contexts.is_empty():
		return

	# 1. Mapear contextos por room_id
	var context_by_id: Dictionary = {}
	for ctx in room_contexts:
		if ctx is _PresentationRoomContextScript:
			context_by_id[ctx.room_id] = ctx

	# 2. Asignar celdas a cada sala según su Rect2i
	for room in semantic_result.rooms:
		var r_id: int = room.id
		var ctx: _PresentationRoomContextScript = context_by_id.get(r_id, null)
		var prof = ctx.profile if ctx != null else null

		var r_floor: Array[Vector2i] = []
		var r_wall: Array[Vector2i] = []
		var r_doors: Array[Vector2i] = []

		var r_rect: Rect2i = room.rect

		for y in range(r_rect.position.y, r_rect.end.y):
			for x in range(r_rect.position.x, r_rect.end.x):
				var pos := Vector2i(x, y)
				if grid.is_in_bounds(pos):
					if grid.is_walkable(pos):
						r_floor.append(pos)
						room_id_by_cell[pos] = r_id
					elif grid.is_solid(pos):
						r_wall.append(pos)

		# Registrar puertas asociadas
		if semantic_result.door_pairs != null:
			for dp in semantic_result.door_pairs:
				if dp != null:
					if dp.door_a != null and dp.door_a.room_id == r_id:
						if not r_doors.has(dp.door_a.position):
							r_doors.append(dp.door_a.position)
					if dp.door_b != null and dp.door_b.room_id == r_id:
						if not r_doors.has(dp.door_b.position):
							r_doors.append(dp.door_b.position)

		var r_geom := _PresentationRoomGeometryScript.new(
			r_id, r_rect, r_floor, r_wall, r_doors, prof
		)
		rooms_geometry[r_id] = r_geom

	# 3. Detectar celdas de corredores (suelo transitable que no pertenece a ninguna sala)
	for y in range(grid.height):
		for x in range(grid.width):
			var pos := Vector2i(x, y)
			if grid.is_walkable(pos) and not room_id_by_cell.has(pos):
				corridor_floor_cells.append(pos)

func get_room_geometry(room_id: int) -> _PresentationRoomGeometryScript:
	return rooms_geometry.get(room_id, null)

func get_rooms() -> Array:
	return rooms_geometry.values()

func get_room_id_at(position: Vector2i) -> int:
	return room_id_by_cell.get(position, -1)

func is_room_cell(position: Vector2i) -> bool:
	return room_id_by_cell.has(position)
