class_name RoomIntegrityCleaner
extends RefCounted

## Algoritmo de limpieza de fragmentos de sala aislados e islas huérfanas tras el tallado de corredores.

const DIRS4: Array[Vector2i] = [
	Vector2i(0, -1), # NORTH
	Vector2i(1, 0),  # EAST
	Vector2i(0, 1),  # SOUTH
	Vector2i(-1, 0)  # WEST
]

## Para cada habitación, comprueba que todas las celdas de tipo FLOOR dentro de room.rect
## estén conectadas al centro de la habitación. Cualquier celda FLOOR desconectada se revierte a WALL.
static func clean_orphaned_room_pockets(
	grid: CellGrid,
	rooms: Array[RoomData]
) -> int:
	if grid == null or rooms.is_empty():
		return 0

	var total_cleaned: int = 0

	for room in rooms:
		if room == null:
			continue

		var center := room.get_center()
		if not grid.is_in_bounds(center):
			continue

		# Si el centro fue cambiado accidentalmente a no transitable, buscar la celda FLOOR más cercana
		var start_node := center
		if grid.get_cell(start_node) != CellGrid.CellType.FLOOR:
			var found_alt := false
			for y in range(room.rect.position.y, room.rect.end.y):
				for x in range(room.rect.position.x, room.rect.end.x):
					var p := Vector2i(x, y)
					if grid.get_cell(p) == CellGrid.CellType.FLOOR:
						start_node = p
						found_alt = true
						break
				if found_alt:
					break
			if not found_alt:
				continue

		# Flood fill dentro de room.rect desde start_node
		var reachable: Dictionary = {start_node: true}
		var queue: Array[Vector2i] = [start_node]

		while not queue.is_empty():
			var curr: Vector2i = queue.pop_front()

			for d in DIRS4:
				var n: Vector2i = curr + d
				if room.rect.has_point(n) and not reachable.has(n):
					var c_type = grid.get_cell(n)
					# Si es FLOOR o DOOR, es transitable dentro del cuerpo de la sala
					if c_type == CellGrid.CellType.FLOOR or c_type == CellGrid.CellType.DOOR:
						reachable[n] = true
						queue.push_back(n)

		# Revertir a WALL cualquier celda FLOOR dentro de room.rect que NO sea alcanzable
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				var pos := Vector2i(x, y)
				if grid.get_cell(pos) == CellGrid.CellType.FLOOR and not reachable.has(pos):
					grid.set_cell(pos, CellGrid.CellType.WALL)
					total_cleaned += 1

	return total_cleaned
