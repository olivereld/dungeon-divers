class_name DungeonDistanceField
extends RefCounted

## Calculador canónico de campo de distancias de una sola pasada (Fase 10).
## Ejecuta un único BFS determinista desde el punto inicial (Spawn/Entrance) sobre todas las celdas
## transitables del CellGrid y produce un mapa de distancias canónico reutilizable sin recalcular BFS redundantes.

const DIRS4: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0)
]

## Calcula el campo de distancias desde start_pos sobre toda la cuadrícula transitable.
## Retorna un Dictionary: Vector2i -> int (distancia en pasos).
static func compute_distance_field(grid: CellGrid, start_pos: Vector2i) -> Dictionary:
	var field: Dictionary = {}
	if grid == null or not grid.is_in_bounds(start_pos):
		return field

	if not grid.is_walkable(start_pos):
		return field

	field[start_pos] = 0
	var queue: Array[Vector2i] = [start_pos]

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		var curr_dist: int = int(field[curr])

		for d in DIRS4:
			var n: Vector2i = curr + d
			if grid.is_in_bounds(n) and grid.is_walkable(n) and not field.has(n):
				field[n] = curr_dist + 1
				queue.push_back(n)

	return field

## Verifica formalmente que el 100% de las celdas transitables del CellGrid sean alcanzables desde start_pos.
static func verify_100_percent_reachable(grid: CellGrid, start_pos: Vector2i) -> Dictionary:
	var field := compute_distance_field(grid, start_pos)
	var unreachable_cells: Array[Vector2i] = []
	var total_walkable: int = 0

	var w: int = grid.get_width()
	var h: int = grid.get_height()

	for y in range(h):
		for x in range(w):
			var pos := Vector2i(x, y)
			if grid.is_walkable(pos):
				total_walkable += 1
				if not field.has(pos):
					unreachable_cells.append(pos)

	return {
		"is_100_percent_reachable": unreachable_cells.is_empty(),
		"total_walkable_cells": total_walkable,
		"reachable_cells_count": field.size(),
		"unreachable_cells": unreachable_cells,
		"max_distance": _get_max_distance(field)
	}

static func _get_max_distance(field: Dictionary) -> int:
	var max_d: int = 0
	for d in field.values():
		if int(d) > max_d:
			max_d = int(d)
	return max_d
