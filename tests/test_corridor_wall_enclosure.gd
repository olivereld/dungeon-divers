extends SceneTree

## Test unitario para Task 2: Separación y Delimitación de Paredes en Corredores (Fase Reforced).
## Valida que cuando un corredor corre paralelo a una sala no conectada, se extraiga el bucle de pared
## divisorio entre el suelo de la sala (FLOOR) y el suelo del corredor (CORRIDOR) a menos que esté en WallOpeningManifest.

func _init() -> void:
	print("--- Running test_corridor_wall_enclosure ---")
	var grid := CellGrid.new(20, 20)
	var room := RoomData.new(0, Rect2i(2, 2, 6, 6), &"room0")
	grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)

	# Corredor paralelo en x=8 (directamente adyacente a room0 en x=7)
	for y in range(2, 8):
		grid.set_cell(Vector2i(8, y), CellGrid.CellType.CORRIDOR)

	var extractor = preload("res://src/wall_mesh_generator/core/continuous_wall_extractor.gd")
	var loops = extractor.extract_wall_loops(grid, 2.0, null)
	assert(loops.size() >= 1, "Must extract closed wall loops separating room from adjacent parallel corridor")

	# Verificar que entre x=7 (room0) y x=8 (corridor) exista una arista de pared divisoria activa
	var found_dividing_wall := false
	for loop in loops:
		for v in loop.vertices:
			# Las coordenadas en X=8 (en metros = 8 * 2.0 = 16.0) corresponden a la frontera entre room y corredor
			if is_equal_approx(v.x, 16.0) and v.z >= 4.0 and v.z <= 16.0:
				found_dividing_wall = true
				break

	assert(found_dividing_wall, "A dividing wall edge must exist between room floor and parallel corridor floor")
	print("  [OK] Wall loops and dividing boundary between room and corridor verified")

	# Test 2: OrthogonalCorridorPlanner evita invadir o rozar paredes de salas ajenas
	var planner = preload("res://src/dungeon_generator/core/algorithms/orthogonal_corridor_planner.gd")
	var room_map: Dictionary = {0: room}
	var is_valid_near_room = planner.is_cell_valid_for_corridor(grid, room_map, 1, 2, Vector2i(7, 4))
	assert(is_valid_near_room == false, "Cell inside room0 must be rejected for connection between room1 and room2")

	print("[PASS] test_corridor_wall_enclosure completed successfully!")
	quit(0)
