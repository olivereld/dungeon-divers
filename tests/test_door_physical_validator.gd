extends SceneTree

## Test unitario para Task 2: Validador Físico de Jambas y Área Libre de Puertas (DoorPhysicalValidator).
## Valida que una puerta física requiera paredes sólidas en ambos lados perpendiculares (jambas)
## y que puertas sin jambas o que bloqueen celdas de área <= 1 sean degradadas a OPEN_PASSAGE.

func _init() -> void:
	print("--- Running test_door_physical_validator ---")
	var ValidatorScript = preload("res://src/dungeon_generator/core/validation/door_physical_validator.gd")
	var RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

	var grid := CellGrid.new(20, 20)

	# Caso 1: Puerta válida con jambas sólidas (muros a ambos lados de la puerta)
	# Entrada NORTH: puerta en (5, 5). Jambas en Oeste (4, 5) y Este (6, 5) son WALL
	grid.set_cell(Vector2i(5, 5), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(4, 5), CellGrid.CellType.WALL)
	grid.set_cell(Vector2i(6, 5), CellGrid.CellType.WALL)

	var is_jamb_valid = ValidatorScript.validate_door_jambs(grid, Vector2i(5, 5), RoomEntranceScript.NORTH)
	assert(is_jamb_valid == true, "Door at (5, 5) with solid lateral walls must have valid jambs")
	print("  [OK] Valid door jambs verified")

	# Caso 2: Puerta inválida en espacio abierto (uno de los lados es transitable)
	grid.set_cell(Vector2i(6, 5), CellGrid.CellType.CORRIDOR) # Espacio abierto a la derecha
	var is_open_air_valid = ValidatorScript.validate_door_jambs(grid, Vector2i(5, 5), RoomEntranceScript.NORTH)
	assert(is_open_air_valid == false, "Door in open air without solid lateral jamb must be invalid")
	print("  [OK] Open-air door rejected by jamb validator")

	# Caso 3: Cálculo de área libre local (local free area)
	# Celda aislada con solo 1 vecino
	var grid2 := CellGrid.new(20, 20)
	grid2.set_cell(Vector2i(10, 10), CellGrid.CellType.CORRIDOR)
	var area_isolated = ValidatorScript.get_local_free_area(grid2, Vector2i(10, 10), 2)
	assert(area_isolated == 1, "Isolated cell must have free area = 1, got %d" % area_isolated)

	# Espacio con varias celdas conectadas
	grid2.set_cell(Vector2i(10, 11), CellGrid.CellType.CORRIDOR)
	grid2.set_cell(Vector2i(10, 12), CellGrid.CellType.CORRIDOR)
	var area_connected = ValidatorScript.get_local_free_area(grid2, Vector2i(10, 10), 2)
	assert(area_connected == 3, "3 connected corridor cells must return free area = 3, got %d" % area_connected)
	print("  [OK] Local free area calculation verified")

	print("[PASS] test_door_physical_validator completed successfully!")
	quit(0)
