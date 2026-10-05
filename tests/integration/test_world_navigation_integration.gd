extends SceneTree

const _NavCellScript = preload("res://src/world_generator/navigation/world_navigation_cell.gd")
const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Running WorldNavigation Integration Tests")
	print("==================================================")
	_test_nav_chunk_construction()
	print("==================================================")
	print(" ALL WORLD NAVIGATION TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_nav_chunk_construction() -> void:
	print(" -> Testing WorldNavigationChunk packed memory and lookup...")
	var coord := Vector2i(0, 0)
	var bounds := Rect2i(0, 0, 4, 4)
	var cells := {}
	for y in range(4):
		for x in range(4):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 2
			cell.height = 3.5
			cell.is_walkable = (x != 0 or y != 0)
			cells[pos] = cell

	var nav_chunk = _NavChunkScript.from_cells(coord, bounds, cells)
	assert(nav_chunk.chunk_coord == coord, "Coord must match")
	assert(nav_chunk.has_cell(Vector2i(1, 1)), "Inside cell exists")
	assert(not nav_chunk.has_cell(Vector2i(5, 5)), "Outside cell does not exist")
	assert(not nav_chunk.is_walkable(Vector2i(0, 0)), "Cell (0,0) must not be walkable")
	assert(nav_chunk.is_walkable(Vector2i(1, 1)), "Cell (1,1) must be walkable")
	assert(nav_chunk.get_elevation_level(Vector2i(1, 1)) == 2, "Elevation level matches")
	assert(absf(nav_chunk.get_height(Vector2i(1, 1)) - 3.5) < 0.001, "Height matches")

	var nav_cell = nav_chunk.get_cell(Vector2i(1, 1))
	assert(nav_cell != null, "nav_cell must not be null")
	assert(nav_cell.cell == Vector2i(1, 1), "NavCell pos matches")
	assert(nav_cell.walkable == true, "NavCell walkable matches")
	assert(nav_cell.elevation_level == 2, "NavCell elevation matches")
	print("    [PASS] WorldNavigationChunk construction and queries")
