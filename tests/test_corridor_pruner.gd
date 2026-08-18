extends SceneTree

## Test unitario para Task 1: Podador de Pockets y Stubs de Corredores (CorridorPruner).
## Valida que las celdas ciegas de corredor (con 3 vecinos sólidos y no protegidas) sean eliminadas (revertidas a WALL).

func _init() -> void:
	print("--- Running test_corridor_pruner ---")
	var PrunerScript = preload("res://src/dungeon_generator/core/algorithms/corridor_pruner.gd")
	assert(PrunerScript != null, "CorridorPruner script must exist")

	var grid := CellGrid.new(20, 20)
	# Crear un corredor principal recto de (2, 5) a (10, 5)
	for x in range(2, 11):
		grid.set_cell(Vector2i(x, 5), CellGrid.CellType.CORRIDOR)

	# Añadir un stub ciego de 1 celda en (5, 4) (vecinos sólidos en Norte, Este, Oeste; solo conectado al Sur con (5,5))
	grid.set_cell(Vector2i(5, 4), CellGrid.CellType.CORRIDOR)

	# Añadir un stub de 2 celdas en (8, 6) y (8, 7)
	grid.set_cell(Vector2i(8, 6), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(8, 7), CellGrid.CellType.CORRIDOR)

	# Celdas protegidas (por ejemplo los extremos del corredor (2, 5) y (10, 5))
	var protected_cells: Array[Vector2i] = [Vector2i(2, 5), Vector2i(10, 5)]

	var pruned_count: int = PrunerScript.prune_dead_end_stubs(grid, protected_cells)
	assert(pruned_count == 3, "Must prune 3 dead-end stub cells (1 at (5,4) and 2 at (8,6)/(8,7)), got %d" % pruned_count)
	assert(grid.get_cell(Vector2i(5, 4)) == CellGrid.CellType.WALL, "Stub (5,4) must be reverted to WALL")
	assert(grid.get_cell(Vector2i(8, 7)) == CellGrid.CellType.WALL, "Stub (8,7) must be reverted to WALL")
	assert(grid.get_cell(Vector2i(8, 6)) == CellGrid.CellType.WALL, "Stub (8,6) must be reverted to WALL")
	assert(grid.get_cell(Vector2i(5, 5)) == CellGrid.CellType.CORRIDOR, "Main corridor line (5,5) must remain intact")
	print("  [OK] Pruning of isolated 1-tile and 2-tile dead-end pockets verified")

	# Caso de celda protegida: stub ciego protegido NO debe ser podado
	grid.set_cell(Vector2i(2, 5), CellGrid.CellType.CORRIDOR)
	var pruned_protected = PrunerScript.prune_dead_end_stubs(grid, [Vector2i(2, 5)])
	assert(grid.get_cell(Vector2i(2, 5)) == CellGrid.CellType.CORRIDOR, "Protected entrance cell must NOT be pruned")
	print("  [OK] Protected entrance cells preserved")

	print("[PASS] test_corridor_pruner completed successfully!")
	quit(0)
