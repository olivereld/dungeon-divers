extends SceneTree

func _init() -> void:
	print("--- Running test_cell_grid ---")
	var grid := CellGrid.new(32, 32, CellGrid.CellType.WALL)

	# Test dimensions and defaults
	assert(grid.width == 32, "Grid width should be 32")
	assert(grid.height == 32, "Grid height should be 32")
	assert(grid.get_cell(Vector2i(0, 0)) == CellGrid.CellType.WALL, "Default cell should be WALL")
	assert(grid.get_cell(Vector2i(-1, 0)) == CellGrid.CellType.VOID, "Out of bounds should be VOID")

	# Test set/get
	grid.set_cell(Vector2i(5, 5), CellGrid.CellType.FLOOR)
	assert(grid.get_cell(Vector2i(5, 5)) == CellGrid.CellType.FLOOR, "Cell (5,5) should be FLOOR")
	assert(grid.is_walkable(Vector2i(5, 5)), "FLOOR should be walkable")
	assert(not grid.is_walkable(Vector2i(0, 0)), "WALL should not be walkable")

	# Test neighbors
	var n4 := grid.get_neighbors_4(Vector2i(0, 0))
	assert(n4.size() == 2, "Corner (0,0) should have 2 4-neighbors")
	var n8 := grid.get_neighbors_8(Vector2i(5, 5))
	assert(n8.size() == 8, "Inner cell (5,5) should have 8 8-neighbors")

	# Test metadata
	grid.set_metadata(Vector2i(5, 5), "test_key", 123)
	assert(grid.get_metadata(Vector2i(5, 5), "test_key") == 123, "Metadata should store and retrieve values")

	# Test fill rect
	grid.fill_rect(Rect2i(10, 10, 5, 5), CellGrid.CellType.FLOOR)
	var floor_cells := grid.find_cells_of_type(CellGrid.CellType.FLOOR)
	assert(floor_cells.size() == 26, "Should have 1 + 25 = 26 floor cells")

	# Test duplicate
	var clone := grid.duplicate_grid()
	assert(clone.get_cell(Vector2i(5, 5)) == CellGrid.CellType.FLOOR, "Cloned cell should match")
	clone.set_cell(Vector2i(5, 5), CellGrid.CellType.WALL)
	assert(grid.get_cell(Vector2i(5, 5)) == CellGrid.CellType.FLOOR, "Original grid should be unaffected")

	print("[PASS] test_cell_grid succeeded.")
	quit(0)
