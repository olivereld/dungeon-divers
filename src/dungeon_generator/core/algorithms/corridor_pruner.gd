class_name CorridorPruner
extends RefCounted

## Algoritmo de limpieza y podado de stubs ciegos, muescas y alcobas no deseadas en corredores.

const DIRS4: Array[Vector2i] = [
	Vector2i(0, -1), # NORTH
	Vector2i(1, 0),  # EAST
	Vector2i(0, 1),  # SOUTH
	Vector2i(-1, 0)  # WEST
]

## Poda iterativamente todas las celdas de corredor que son fondos de saco ciegos (<= 1 vecino transitable)
## y que no están en la lista de celdas protegidas (entradas, vanos, marcadores de sala).
static func prune_dead_end_stubs(
	grid: CellGrid,
	protected_cells: Array[Vector2i] = [],
	max_iterations: int = 10
) -> int:
	if grid == null:
		return 0

	var protected_set: Dictionary = {}
	for c in protected_cells:
		protected_set[c] = true

	var total_pruned: int = 0
	var changed := true
	var iteration: int = 0

	while changed and iteration < max_iterations:
		changed = false
		iteration += 1
		var to_prune: Array[Vector2i] = []

		for y in range(grid.height):
			for x in range(grid.width):
				var pos := Vector2i(x, y)
				if grid.get_cell(pos) != CellGrid.CellType.CORRIDOR:
					continue

				if protected_set.has(pos):
					continue

				# Contar vecinos transitables ortogonales
				var walkable_neighbors: int = 0
				for d in DIRS4:
					var neighbor: Vector2i = pos + d
					if grid.is_in_bounds(neighbor) and grid.is_walkable(neighbor):
						walkable_neighbors += 1

				# Si tiene <= 1 vecino transitable, es un fondo de saco (stub ciego)
				if walkable_neighbors <= 1:
					to_prune.append(pos)

		for pos in to_prune:
			grid.set_cell(pos, CellGrid.CellType.WALL)
			total_pruned += 1
			changed = true

	return total_pruned

## Detecta y resuelve pasillos colineales separados por exactamente 1 celda WALL,
## unificando la circulación continua y evitando cortes transversales indeseados.
static func connect_or_prune_collinear_stubs(
	grid: CellGrid,
	protected_cells: Array[Vector2i] = []
) -> int:
	if grid == null:
		return 0

	var connections_made: int = 0
	var to_connect: Array[Vector2i] = []

	for y in range(1, grid.height - 1):
		for x in range(1, grid.width - 1):
			var pos := Vector2i(x, y)
			if grid.get_cell(pos) != CellGrid.CellType.WALL:
				continue

			# 1. Alineación Vertical: CORRIDOR / WALL / CORRIDOR
			var north := pos + Vector2i(0, -1)
			var south := pos + Vector2i(0, 1)
			if (
				grid.get_cell(north) == CellGrid.CellType.CORRIDOR
				and grid.get_cell(south) == CellGrid.CellType.CORRIDOR
			):
				to_connect.append(pos)
				continue

			# 2. Alineación Horizontal: CORRIDOR / WALL / CORRIDOR
			var west := pos + Vector2i(-1, 0)
			var east := pos + Vector2i(1, 0)
			if (
				grid.get_cell(west) == CellGrid.CellType.CORRIDOR
				and grid.get_cell(east) == CellGrid.CellType.CORRIDOR
			):
				to_connect.append(pos)
				continue

	for p in to_connect:
		grid.set_cell(p, CellGrid.CellType.CORRIDOR)
		connections_made += 1

	return connections_made
