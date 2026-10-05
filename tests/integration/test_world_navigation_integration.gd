extends SceneTree

const _NavCellScript = preload("res://src/world_generator/navigation/world_navigation_cell.gd")
const _NavChunkScript = preload("res://src/world_generator/navigation/world_navigation_chunk.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")

func _init() -> void:
	print("==================================================")
	print(" Running WorldNavigation Integration Tests")
	print("==================================================")
	_test_nav_chunk_construction()
	_test_pipeline_navigation_stage()
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
