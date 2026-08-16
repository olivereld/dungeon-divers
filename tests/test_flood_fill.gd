extends SceneTree

func _init() -> void:
	print("--- Running test_flood_fill ---")
	var grid := CellGrid.new(30, 30, CellGrid.CellType.WALL)

	# Crear dos habitaciones aisladas
	grid.fill_rect(Rect2i(2, 2, 5, 5), CellGrid.CellType.FLOOR)
	grid.fill_rect(Rect2i(15, 15, 5, 5), CellGrid.CellType.FLOOR)

	var flood := FloodFill.new()
	var regions := flood.find_all_regions(grid)
	assert(regions.size() == 2, "Should find exactly 2 disconnected regions")

	assert(not flood.are_connected(grid, Vector2i(3, 3), Vector2i(16, 16)), "Rooms should not be connected yet")

	# Reparar conectividad
	var bridges := flood.ensure_connectivity(grid)
	assert(bridges > 0, "At least 1 bridge should be carved")

	var new_regions := flood.find_all_regions(grid)
	assert(new_regions.size() == 1, "All cells should now belong to 1 connected component")
	assert(flood.are_connected(grid, Vector2i(3, 3), Vector2i(16, 16)), "Rooms must be connected after bridge")

	print("[PASS] test_flood_fill succeeded.")
	quit(0)
