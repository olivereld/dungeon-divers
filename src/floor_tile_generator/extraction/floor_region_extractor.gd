class_name FloorRegionExtractor
extends RefCounted

## Extrae componentes conexas de celdas transitables de un CellGrid para formar regiones/clusters de suelo.
## Utiliza un flood-fill ortogonal (4-vecinos) determinista en modo de solo lectura sobre el CellGrid.

const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

## Retorna un arreglo de regiones, donde cada región es un Array[Vector2i] con las celdas transitables conexas.
func extract_regions(grid) -> Array:
	var regions: Array = []
	if grid == null:
		return regions

	var width: int = grid.width
	var height: int = grid.height
	var total_cells: int = width * height

	var visited := PackedByteArray()
	visited.resize(total_cells)
	visited.fill(0)

	var offsets: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(-1, 0),
		Vector2i(0, 1),
		Vector2i(0, -1)
	]

	for y in range(height):
		for x in range(width):
			var idx: int = y * width + x
			if visited[idx] == 1:
				continue

			var start_pos := Vector2i(x, y)
			if not grid.is_walkable(start_pos):
				visited[idx] = 1
				continue

			# Iniciar Flood Fill (BFS) para esta componente conexa
			var region: Array[Vector2i] = []
			var queue: Array[Vector2i] = [start_pos]
			visited[idx] = 1

			var head: int = 0
			while head < queue.size():
				var current: Vector2i = queue[head]
				head += 1
				region.append(current)

				for off in offsets:
					var neighbor: Vector2i = current + off
					if not grid.is_in_bounds(neighbor):
						continue

					var n_idx: int = neighbor.y * width + neighbor.x
					if visited[n_idx] == 1:
						continue

					if grid.is_walkable(neighbor):
						visited[n_idx] = 1
						queue.append(neighbor)
					else:
						# No marcar aún como visitado si no es walkable, pero no lo añadimos a la cola
						pass

			if not region.is_empty():
				regions.append(region)

	return regions
