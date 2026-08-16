class_name CellularAutomata
extends RefCounted

## Generador de formas y cuevas orgánicas mediante Autómatas Celulares (B4/S3).
## Modifica regiones específicas de un CellGrid o el mapa completo.

var initial_fill_chance: float = 0.45
var birth_limit: int = 4
var death_limit: int = 3
var iterations: int = 4
var smooth_edges: bool = true

func apply(grid: CellGrid, bounds: Rect2i, rng: RandomNumberGenerator) -> void:
	var clipped := bounds.intersection(grid.get_bounds())
	if clipped.size.x <= 2 or clipped.size.y <= 2:
		return

	# 1. Sembrado aleatorio inicial (muros vs suelos)
	for y in range(clipped.position.y + 1, clipped.end.y - 1):
		for x in range(clipped.position.x + 1, clipped.end.x - 1):
			var pos := Vector2i(x, y)
			if rng.randf() < initial_fill_chance:
				grid.set_cell(pos, CellGrid.CellType.WALL)
			else:
				grid.set_cell(pos, CellGrid.CellType.FLOOR)

	# 2. Pasadas de simulación
	for _it in range(iterations):
		_step(grid, clipped)

	# 3. Suavizado
	if smooth_edges:
		_smooth(grid, clipped)

	# 4. Limpieza y garantía de transpirabilidad interior (mínimo 60% suelo)
	_cleanup_interior(grid, clipped)

func _step(grid: CellGrid, bounds: Rect2i) -> void:
	var temp := grid.duplicate_grid()

	for y in range(bounds.position.y + 1, bounds.end.y - 1):
		for x in range(bounds.position.x + 1, bounds.end.x - 1):
			var pos := Vector2i(x, y)
			var wall_count: int = temp.count_neighbors(pos, CellGrid.CellType.WALL, true)

			if temp.get_cell(pos) == CellGrid.CellType.WALL:
				if wall_count < death_limit:
					grid.set_cell(pos, CellGrid.CellType.FLOOR)
			else:
				if wall_count > birth_limit:
					grid.set_cell(pos, CellGrid.CellType.WALL)

func _smooth(grid: CellGrid, bounds: Rect2i) -> void:
	var temp := grid.duplicate_grid()
	for y in range(bounds.position.y + 1, bounds.end.y - 1):
		for x in range(bounds.position.x + 1, bounds.end.x - 1):
			var pos := Vector2i(x, y)
			var wall_count: int = temp.count_neighbors(pos, CellGrid.CellType.WALL, true)
			if wall_count >= 5:
				grid.set_cell(pos, CellGrid.CellType.WALL)
			elif wall_count <= 2:
				grid.set_cell(pos, CellGrid.CellType.FLOOR)

func _cleanup_interior(grid: CellGrid, bounds: Rect2i) -> void:
	# Asegurar que el centro de la habitación y una cruz central sean transitables
	var center := bounds.position + bounds.size / 2
	grid.set_cell(center, CellGrid.CellType.FLOOR)
	grid.set_cell(center + Vector2i(1, 0), CellGrid.CellType.FLOOR)
	grid.set_cell(center + Vector2i(-1, 0), CellGrid.CellType.FLOOR)
	grid.set_cell(center + Vector2i(0, 1), CellGrid.CellType.FLOOR)
	grid.set_cell(center + Vector2i(0, -1), CellGrid.CellType.FLOOR)

	# Eliminar pilares de muro aislados de 1 celda
	for y in range(bounds.position.y + 1, bounds.end.y - 1):
		for x in range(bounds.position.x + 1, bounds.end.x - 1):
			var pos := Vector2i(x, y)
			if grid.get_cell(pos) == CellGrid.CellType.WALL:
				if grid.count_neighbors(pos, CellGrid.CellType.FLOOR, false) >= 3:
					grid.set_cell(pos, CellGrid.CellType.FLOOR)
