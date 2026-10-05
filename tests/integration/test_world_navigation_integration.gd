extends SceneTree

const _NavCellScript = preload("res://src/world_generator/navigation/world_navigation_cell.gd")
const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _NavGridScript = preload("res://src/world_generator/navigation/world_navigation_grid.gd")
const _ChunkManagerScript = preload("res://src/world_generator/chunks/chunk_manager.gd")
const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")

func _init() -> void:
	print("==================================================")
	print(" Running WorldNavigation Integration Tests")
	print("==================================================")
	_test_nav_chunk_construction()
	_test_pipeline_navigation_stage()
	_test_world_navigation_grid()
	_test_chunk_manager_navigation_sync()
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

func _test_pipeline_navigation_stage() -> void:
	print(" -> Testing WorldNavigationStage within WorldPipeline chunk generation...")
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new()
	var coord := Vector2i(0, 0)
	var chunk_data: ChunkData = _WorldPipelineScript.generate_chunk(12345, coord, profile, config, null)
	assert(chunk_data != null, "ChunkData must not be null")
	assert("navigation_chunk" in chunk_data, "ChunkData must have navigation_chunk property")
	assert(chunk_data.navigation_chunk != null, "navigation_chunk must be generated")
	assert(chunk_data.navigation_chunk.chunk_coord == coord, "nav_chunk coord must match")
	assert(chunk_data.navigation_chunk.core_bounds == chunk_data.core_bounds, "nav_chunk bounds must equal core_bounds")

	# Verify seam cells are NOT included in navigation_chunk
	for seam_pos in chunk_data.seam_cells.keys():
		assert(not chunk_data.navigation_chunk.has_cell(seam_pos), "Seam cell must not be in navigation_chunk")

	print("    [PASS] WorldNavigationStage execution and seam exclusion")

func _test_world_navigation_grid() -> void:
	print(" -> Testing WorldNavigationGrid cross-chunk queries and availability...")
	var grid = _NavGridScript.new(1.0, 16, Vector3.ZERO)

	var cell_a := Vector2i(15, 5) # Inside Chunk (0, 0)
	var cell_b := Vector2i(16, 5) # Inside Chunk (1, 0)

	assert(grid.get_cell_availability(cell_a) == _NavGridScript.Availability.UNAVAILABLE, "Unregistered chunk must be UNAVAILABLE")
	assert(not grid.has_cell(cell_a), "Unregistered cell has_cell is false")

	# Create two adjacent navigation chunks
	var cells_00 := {}
	for y in range(16):
		for x in range(16):
			var pos := Vector2i(x, y)
			var c = _WorldCellScript.new(pos)
			c.elevation_level = 1
			c.height = 1.0
			c.is_walkable = true
			cells_00[pos] = c
	var chunk_00 = _NavChunkScript.from_cells(Vector2i(0, 0), Rect2i(0, 0, 16, 16), cells_00)

	var cells_10 := {}
	for y in range(16):
		for x in range(16):
			var pos := Vector2i(16 + x, y)
			var c = _WorldCellScript.new(pos)
			c.elevation_level = 1
			c.height = 1.0
			c.is_walkable = (x != 0 or y != 0) # (16, 0) unwalkable, (16, 5) walkable
			cells_10[pos] = c
	var chunk_10 = _NavChunkScript.from_cells(Vector2i(1, 0), Rect2i(16, 0, 16, 16), cells_10)

	var registered_signal_coords: Array[Vector2i] = []
	grid.chunk_registered.connect(func(c: Vector2i): registered_signal_coords.append(c))

	grid.register_chunk(chunk_00)
	assert(grid.has_chunk(Vector2i(0, 0)), "Chunk (0, 0) is registered")
	assert(grid.get_cell_availability(cell_a) == _NavGridScript.Availability.READY, "Cell A is now READY")
	assert(grid.get_cell_availability(cell_b) == _NavGridScript.Availability.UNAVAILABLE, "Cell B is still UNAVAILABLE")

	grid.register_chunk(chunk_10)
	assert(registered_signal_coords.size() == 2, "Two chunk_registered signals fired")
	assert(grid.get_cell_availability(cell_b) == _NavGridScript.Availability.READY, "Cell B is now READY")

	# Cross-chunk queries
	assert(grid.is_walkable(cell_a), "Cell A walkable")
	assert(grid.is_walkable(cell_b), "Cell B walkable across seam")
	assert(not grid.is_walkable(Vector2i(16, 0)), "Cell (16, 0) unwalkable")

	# Spatial conversion
	var w_pos := grid.cell_to_world(Vector2i(16, 5))
	assert(grid.world_to_cell(w_pos) == Vector2i(16, 5), "cell_to_world <-> world_to_cell roundtrip")

	# Lower support primitive
	var support = grid.find_lower_support(cell_b, 4)
	assert(support["found"] == true, "Support found on cell_b")
	assert(support["elevation_level"] == 1, "Support elevation matches")

	# Unregister
	grid.unregister_chunk(Vector2i(1, 0))
	assert(grid.get_cell_availability(cell_b) == _NavGridScript.Availability.UNAVAILABLE, "Cell B becomes UNAVAILABLE after unregister")

	print("    [PASS] WorldNavigationGrid cross-chunk queries and availability")

func _test_chunk_manager_navigation_sync() -> void:
	print(" -> Testing WorldChunkManager and ChunkWorld publishing to WorldNavigationGrid...")
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new()
	var manager = _ChunkManagerScript.new(12345, profile, config)

	assert("navigation_grid" in manager, "WorldChunkManager must have navigation_grid member")
	assert(manager.navigation_grid != null, "WorldChunkManager must instantiate navigation_grid")

	# Synchronous load
	var coord := Vector2i(0, 0)
	var chunk_data = manager.load_chunk(coord)
	assert(chunk_data != null, "ChunkData loaded")
	assert(manager.navigation_grid.has_chunk(coord), "NavigationGrid must have registered chunk on load")

	# Unload
	manager.unload_chunk(coord)
	assert(not manager.navigation_grid.has_chunk(coord), "NavigationGrid must unregister chunk on unload")

	# ChunkWorld coordinator test
	var world = _ChunkWorldScript.new()
	world.initialize(12345, profile, config)
	assert("navigation_grid" in world, "ChunkWorld must have navigation_grid member")
	assert(world.navigation_grid != null, "ChunkWorld must expose navigation_grid")
	world.queue_free()

	print("    [PASS] WorldChunkManager and ChunkWorld navigation lifecycle sync")
