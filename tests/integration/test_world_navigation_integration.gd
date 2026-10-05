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
const _RulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _RequestScript = preload("res://src/gameplay/movement/movement_request.gd")
const _ResultScript = preload("res://src/gameplay/movement/movement_result.gd")
const _ComponentScript = preload("res://src/gameplay/movement/movement_component.gd")

func _init() -> void:
	print("==================================================")
	print(" Running WorldNavigation Integration Tests")
	print("==================================================")
	_test_nav_chunk_construction()
	_test_pipeline_navigation_stage()
	_test_world_navigation_grid()
	_test_chunk_manager_navigation_sync()
	_test_movement_rules_navigation_grid()
	_test_movement_component_unavailable_retry()
	_test_full_pipeline_cross_chunk_integration()
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

func _test_movement_rules_navigation_grid() -> void:
	print(" -> Testing MovementRules against WorldNavigationGrid...")
	var grid = _NavGridScript.new(1.0, 16, Vector3.ZERO)
	var rules = _RulesScript.new()
	var profile = _ProfileScript.new()
	profile.max_step_up = 1
	profile.max_step_down = 1
	profile.can_fall = true
	profile.max_fall_height = 4

	var cells := {}
	# From (5, 5): Level 3, Walkable
	var c_from = _WorldCellScript.new(Vector2i(5, 5))
	c_from.elevation_level = 3
	c_from.height = 3.0
	c_from.is_walkable = true
	cells[Vector2i(5, 5)] = c_from

	# Walk: (6, 5): Level 3
	var c_walk = _WorldCellScript.new(Vector2i(6, 5))
	c_walk.elevation_level = 3
	c_walk.height = 3.0
	c_walk.is_walkable = true
	cells[Vector2i(6, 5)] = c_walk

	# Step up: (5, 6): Level 4 (delta = +1)
	var c_up = _WorldCellScript.new(Vector2i(5, 6))
	c_up.elevation_level = 4
	c_up.height = 4.0
	c_up.is_walkable = true
	cells[Vector2i(5, 6)] = c_up

	# Fall: (5, 4): Level 1 (delta = -2, exceeds max_step_down=1, <= max_fall=4)
	var c_fall = _WorldCellScript.new(Vector2i(5, 4))
	c_fall.elevation_level = 1
	c_fall.height = 1.0
	c_fall.is_walkable = true
	cells[Vector2i(5, 4)] = c_fall

	# Fall too high: (4, 5): Level -3 (delta = -6 > 4)
	var c_abyss = _WorldCellScript.new(Vector2i(4, 5))
	c_abyss.elevation_level = -3
	c_abyss.height = -3.0
	c_abyss.is_walkable = true
	cells[Vector2i(4, 5)] = c_abyss

	# Border cell for unavailable test: (15, 5) -> (16, 5)
	var c_border = _WorldCellScript.new(Vector2i(15, 5))
	c_border.elevation_level = 3
	c_border.height = 3.0
	c_border.is_walkable = true
	cells[Vector2i(15, 5)] = c_border

	var chunk = _NavChunkScript.from_cells(Vector2i(0, 0), Rect2i(0, 0, 16, 16), cells)
	grid.register_chunk(chunk)

	# 1. Test UNAVAILABLE chunk/cell (direction (1, 0) into unregistered chunk (1, 0))
	var res_unavail = rules.validate_transition(Vector2i(15, 5), Vector2i(16, 5), grid, profile)
	assert(not res_unavail.accepted, "Unavailable target rejected")
	assert(res_unavail.reason == _ResultScript.REASON_CHUNK_UNAVAILABLE, "Reason is CHUNK_UNAVAILABLE")

	# 2. Test WALK
	var res_walk = rules.validate_transition(Vector2i(5, 5), Vector2i(6, 5), grid, profile)
	assert(res_walk.accepted, "Walk accepted")
	assert(res_walk.transition_type == _ResultScript.TransitionType.WALK, "Transition is WALK")

	# 3. Test STEP_UP
	var res_up = rules.validate_transition(Vector2i(5, 5), Vector2i(5, 6), grid, profile)
	assert(res_up.accepted, "Step up accepted")
	assert(res_up.transition_type == _ResultScript.TransitionType.STEP_UP, "Transition is STEP_UP")

	# 4. Test FALL
	var res_fall = rules.validate_transition(Vector2i(5, 5), Vector2i(5, 4), grid, profile)
	assert(res_fall.accepted, "Fall accepted")
	assert(res_fall.transition_type == _ResultScript.TransitionType.FALL, "Transition is FALL")

	# 5. Test FALL_TOO_HIGH
	var res_high = rules.validate_transition(Vector2i(5, 5), Vector2i(4, 5), grid, profile)
	assert(not res_high.accepted, "Abyss fall rejected")
	assert(res_high.reason == _ResultScript.REASON_FALL_TOO_HIGH, "Reason is FALL_TOO_HIGH")

	print("    [PASS] MovementRules against WorldNavigationGrid")

func _test_movement_component_unavailable_retry() -> void:
	print(" -> Testing MovementComponent reactive waiting for UNAVAILABLE chunks...")
	var grid = _NavGridScript.new(1.0, 16, Vector3.ZERO)
	var comp = _ComponentScript.new()
	comp.setup(grid, null, null, Vector2i(15, 0))

	# Chunk (0, 0) registered
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
	grid.register_chunk(chunk_00)

	# Attempt to step from (15, 0) into unregistered Chunk (1, 0) at (16, 0)
	var req := _RequestScript.new(Vector2i(1, 0), &"player")
	var res = comp.request_movement(req)
	assert(not res.accepted, "Move towards unavailable chunk rejected")
	assert(res.reason == _ResultScript.REASON_CHUNK_UNAVAILABLE, "Reason is CHUNK_UNAVAILABLE")
	assert("pending_unavailable_request" in comp, "MovementComponent must have pending_unavailable_request property")
	assert(comp.pending_unavailable_request == req, "Request is stored in pending_unavailable_request")
	assert(not comp.is_moving, "Component is not moving while waiting")

	# Register Chunk (1, 0)
	var cells_10 := {}
	for y in range(16):
		for x in range(16):
			var pos := Vector2i(16 + x, y)
			var c = _WorldCellScript.new(pos)
			c.elevation_level = 1
			c.height = 1.0
			c.is_walkable = true
			cells_10[pos] = c
	var chunk_10 = _NavChunkScript.from_cells(Vector2i(1, 0), Rect2i(16, 0, 16, 16), cells_10)

	# When chunk is registered, MovementComponent must reactively retry and start moving
	grid.register_chunk(chunk_10)
	assert(comp.is_moving, "Component started moving reactively upon chunk registration")
	assert(comp.target_cell == Vector2i(16, 0), "Target cell is (16, 0)")
	assert(comp.pending_unavailable_request == null, "Pending request cleared")

	# Complete transition
	comp.process_movement(1.0)
	assert(comp.current_cell == Vector2i(16, 0), "Transition completed into new chunk")

	print("    [PASS] MovementComponent reactive wait and retry")

func _test_full_pipeline_cross_chunk_integration() -> void:
	print(" -> Testing end-to-end multi-chunk pipeline integration with real terrain...")
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new()
	var manager = _ChunkManagerScript.new(4242, profile, config)

	# Generate 2 adjacent chunks: (0, 0) and (1, 0)
	var c0 = manager.load_chunk(Vector2i(0, 0))
	var c1 = manager.load_chunk(Vector2i(1, 0))
	assert(c0 != null and c1 != null, "Chunks generated")
	assert(manager.navigation_grid.has_chunk(Vector2i(0, 0)), "Chunk 0,0 registered")
	assert(manager.navigation_grid.has_chunk(Vector2i(1, 0)), "Chunk 1,0 registered")

	# Find boundary transition between (0, 0) and (1, 0)
	var boundary_x := 15
	var target_x := 16
	var found_valid_transition := false

	var rules = _RulesScript.new()
	var m_profile = _ProfileScript.new()

	for y in range(16):
		var from_c := Vector2i(boundary_x, y)
		var to_c := Vector2i(target_x, y)
		var res = rules.validate_transition(from_c, to_c, manager.navigation_grid, m_profile)
		if res.accepted:
			found_valid_transition = true
			break

	assert(found_valid_transition, "Real terrain must have at least one valid boundary transition across adjacent chunks")

	# Performance benchmark
	print(" -> Benchmarking WorldNavigationStage overhead...")
	var t0 := Time.get_ticks_usec()
	for i in range(10):
		_WorldPipelineScript.generate_chunk(1000 + i, Vector2i(i, 0), profile, config, null)
	var t_total_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var avg_ms := t_total_ms / 10.0
	print("    Average chunk generation time with WorldNavigation: %.2f ms" % avg_ms)
	assert(avg_ms < 50.0, "Chunk generation should remain fast (< 50ms average in test runner)")

	print("    [PASS] full pipeline multi-chunk integration and performance")
