extends SceneTree

## Test unitario para Task 3: Limpiador de Bolsillos e Islas Huérfanas de Sala (RoomIntegrityCleaner).
## Valida que fragmentos o muescas de sala que quedan aislados fuera del núcleo principal de la habitación
## (por ejemplo tras el corte de un corredor) sean detectados y revertidos a WALL.

func _init() -> void:
	print("--- Running test_room_integrity_cleaner ---")
	var CleanerScript = preload("res://src/dungeon_generator/core/repair/room_integrity_cleaner.gd")
	assert(CleanerScript != null, "RoomIntegrityCleaner script must exist")

	var grid := CellGrid.new(20, 20, CellGrid.CellType.WALL)
	var room := RoomData.new(0, Rect2i(4, 4, 8, 8), &"test_room")

	# Llenar la sala principal de suelo (4..11, 4..11)
	grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)

	# Simular un corredor o pared cortando una fila en y=10 (dejando la fila y=11 aislada con 2 celdas en (4,11) y (5,11))
	for x in range(4, 12):
		grid.set_cell(Vector2i(x, 10), CellGrid.CellType.WALL)

	# Dejar solo 2 celdas huérfanas en la esquina inferior (4, 11) y (5, 11)
	grid.set_cell(Vector2i(4, 11), CellGrid.CellType.FLOOR)
	grid.set_cell(Vector2i(5, 11), CellGrid.CellType.FLOOR)
	for x in range(6, 12):
		grid.set_cell(Vector2i(x, 11), CellGrid.CellType.WALL)

	var cleaned_count: int = CleanerScript.clean_orphaned_room_pockets(grid, [room])
	assert(cleaned_count == 2, "Must clean 2 orphaned floor cells, got %d" % cleaned_count)
	assert(grid.get_cell(Vector2i(4, 11)) == CellGrid.CellType.WALL, "Orphan (4,11) must be reverted to WALL")
	assert(grid.get_cell(Vector2i(5, 11)) == CellGrid.CellType.WALL, "Orphan (5,11) must be reverted to WALL")
	assert(grid.get_cell(room.get_center()) == CellGrid.CellType.FLOOR, "Main room core must remain intact")
	print("  [OK] Orphaned room pockets successfully cleaned")

	print("[PASS] test_room_integrity_cleaner completed successfully!")
	quit(0)
