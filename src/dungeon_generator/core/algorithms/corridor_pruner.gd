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
