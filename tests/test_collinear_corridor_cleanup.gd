extends SceneTree

const _CorridorPrunerScript = preload("res://src/dungeon_generator/core/algorithms/corridor_pruner.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

func _init() -> void:
	print("========================================================")
	print("   TEST: COLLINEAR CORRIDOR DEAD-END CLEANUP & CONNECT  ")
	print("========================================================")

	# Caso 1: Dos pasillos verticales separados por 1 celda WALL
	# (1, 0) = CORRIDOR
	# (1, 1) = WALL
	# (1, 2) = CORRIDOR
	var grid1 := _CellGridScript.new(3, 3, _CellGridScript.CellType.WALL)
	grid1.set_cell(Vector2i(1, 0), _CellGridScript.CellType.CORRIDOR)
	grid1.set_cell(Vector2i(1, 1), _CellGridScript.CellType.WALL)
	grid1.set_cell(Vector2i(1, 2), _CellGridScript.CellType.CORRIDOR)

	var conns1 = _CorridorPrunerScript.connect_or_prune_collinear_stubs(grid1)
	assert(conns1 == 1, "Debe haber conectado la celda intermedia")
	assert(grid1.get_cell(Vector2i(1, 1)) == _CellGridScript.CellType.CORRIDOR, "Celda (1, 1) debe ser ahora CORRIDOR")
	print("✔ Caso 1: Pasillos colineales verticales conectados con éxito.")

	# Caso 2: Dos pasillos horizontales separados por 1 celda WALL
	var grid2 := _CellGridScript.new(3, 3, _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(0, 1), _CellGridScript.CellType.CORRIDOR)
	grid2.set_cell(Vector2i(1, 1), _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(2, 1), _CellGridScript.CellType.CORRIDOR)

	var conns2 = _CorridorPrunerScript.connect_or_prune_collinear_stubs(grid2)
	assert(conns2 == 1, "Debe conectar la celda horizontal")
	assert(grid2.get_cell(Vector2i(1, 1)) == _CellGridScript.CellType.CORRIDOR, "Celda (1, 1) debe ser CORRIDOR")
	print("✔ Caso 2: Pasillos colineales horizontales conectados con éxito.")

	# Caso 3: Muro divisorio entre dos salas distintas (NO debe perforarse)
	var grid3 := _CellGridScript.new(3, 3, _CellGridScript.CellType.WALL)
	grid3.set_cell(Vector2i(1, 0), _CellGridScript.CellType.FLOOR)
	grid3.set_room_owner(Vector2i(1, 0), 1)
	grid3.set_cell(Vector2i(1, 1), _CellGridScript.CellType.WALL)
	grid3.set_cell(Vector2i(1, 2), _CellGridScript.CellType.FLOOR)
	grid3.set_room_owner(Vector2i(1, 2), 2)

	var conns3 = _CorridorPrunerScript.connect_or_prune_collinear_stubs(grid3)
	assert(conns3 == 0, "No debe perforar muros entre dos habitaciones distintas")
	assert(grid3.get_cell(Vector2i(1, 1)) == _CellGridScript.CellType.WALL, "Celda divisoria debe permanecer WALL")
	print("✔ Caso 3: Muro legítimo entre salas protegido con éxito.")

	print("\nTODOS LOS TESTS DE CORREDORES COLINEALES PASARON AL 100%.")
	quit(0)
