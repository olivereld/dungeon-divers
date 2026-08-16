extends SceneTree

func _init() -> void:
	print("--- Running test_door_placement_solver ---")
	var solver_script = preload("res://src/dungeon_generator/core/solvers/door_placement_solver.gd")
	var solver = solver_script.new()

	# Grid de prueba 10x10
	var grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)

	# 1. Caso Válido Vertical: Flanqueado por muros a Izquierda (2,3) y Derecha (4,3), camino libre Arriba (3,2) y Abajo (3,4)
	grid.set_cell(Vector2i(3, 3), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(3, 2), CellGrid.CellType.FLOOR)
	grid.set_cell(Vector2i(3, 4), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(2, 3), CellGrid.CellType.WALL)
	grid.set_cell(Vector2i(4, 3), CellGrid.CellType.WALL)
	assert(solver.is_valid_doorway(grid, Vector2i(3, 3)) == true, "Position (3,3) must be a valid vertical doorway")

	# 2. Caso Inválido: En espacio abierto (sin muros a los lados)
	grid.set_cell(Vector2i(2, 3), CellGrid.CellType.FLOOR) # Quitamos el muro izquierdo
	assert(solver.is_valid_doorway(grid, Vector2i(3, 3)) == false, "Open position must be discarded as doorway")

	# 3. Caso Inválido: Puerta pegada a otra puerta
	var existing: Array[Vector2i] = [Vector2i(3, 3)]
	assert(solver._can_place_door_near(Vector2i(3, 4), existing) == false, "Adjacent door must be rejected")
	assert(solver._can_place_door_near(Vector2i(3, 6), existing) == true, "Distant door must be accepted")

	print("[PASS] test_door_placement_solver succeeded.")
	quit(0)
