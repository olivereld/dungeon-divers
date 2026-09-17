extends SceneTree

const _ChunkCoordScript = preload("res://src/world_generator/chunks/chunk_coord.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkDataScript = preload("res://src/world_generator/chunks/chunk_data.gd")
const _ChunkGenContextScript = preload("res://src/world_generator/chunks/chunk_generation_context.gd")

func _init() -> void:
	print("--- Running Test: Chunk Primitives & Context (Bloque 2) ---")

	# -------------------------------------------------------------------------
	# 1. Test ChunkCoord
	# -------------------------------------------------------------------------
	var size := 16
	assert(_ChunkCoordScript.world_to_chunk(Vector2i(0, 0), size) == Vector2i(0, 0), "Origin to chunk")
	assert(_ChunkCoordScript.world_to_chunk(Vector2i(15, 15), size) == Vector2i(0, 0), "Max inside chunk (0,0)")
	assert(_ChunkCoordScript.world_to_chunk(Vector2i(16, 0), size) == Vector2i(1, 0), "Chunk (1,0) start")
	assert(_ChunkCoordScript.world_to_chunk(Vector2i(-1, 0), size) == Vector2i(-1, 0), "Negative X to chunk -1")
	assert(_ChunkCoordScript.world_to_chunk(Vector2i(-16, -16), size) == Vector2i(-1, -1), "Negative coords floor")
	assert(_ChunkCoordScript.world_to_chunk(Vector2i(-17, -1), size) == Vector2i(-2, -1), "Floori negative coords")

	var origin := _ChunkCoordScript.chunk_to_world_origin(Vector2i(3, -2), size)
	assert(origin == Vector2i(48, -32), "chunk_to_world_origin for (3, -2)")

	var core := _ChunkCoordScript.get_core_bounds(Vector2i(2, 1), size)
	assert(core == Rect2i(32, 16, 16, 16), "core_bounds calculation")

	var gen_b := _ChunkCoordScript.get_generation_bounds(Vector2i(2, 1), size, 2)
	assert(gen_b == Rect2i(30, 14, 20, 20), "generation_bounds calculation with margin 2")
	print("PASS: 1. ChunkCoord conversions and bounds verified")

	# -------------------------------------------------------------------------
	# 2. Test ChunkConfig & ChunkData
	# -------------------------------------------------------------------------
	var config := _ChunkConfigScript.new(16, 1)
	assert(config.chunk_size == 16, "ChunkConfig chunk_size default")
	assert(config.generation_margin == 1, "ChunkConfig generation_margin")
	assert(config.vegetation_margin == 4, "ChunkConfig vegetation_margin")

	var c_data := _ChunkDataScript.new(Vector2i(1, 1), core, gen_b)
	assert(c_data is WorldResult, "ChunkData must inherit from WorldResult for full polymorphism")
	assert(c_data.coord == Vector2i(1, 1), "ChunkData coord")
	assert(c_data.core_bounds == core, "ChunkData core_bounds")
	print("PASS: 2. ChunkConfig & ChunkData verified")

	# -------------------------------------------------------------------------
	# 3. Test ChunkGenerationContext Polymorphism
	# -------------------------------------------------------------------------
	var seed_val := 424242
	var profile := TaigaWorldProfile.new()
	var chunk_ctx := _ChunkGenContextScript.new(seed_val, profile, Vector2i(0, 0), config)

	assert(chunk_ctx is WorldGenerationContext, "ChunkGenerationContext must inherit from WorldGenerationContext")
	assert(chunk_ctx.is_chunk_context() == true, "is_chunk_context must be true")
	assert(chunk_ctx.get_core_bounds() == Rect2i(0, 0, 16, 16), "Chunk (0,0) core_bounds")

	# Effective margin is max(1, 4) = 4 -> gen_bounds is [-4, -4, 24, 24]
	var exp_gen := Rect2i(-4, -4, 24, 24)
	assert(chunk_ctx.get_generation_bounds() == exp_gen, "Chunk (0,0) generation_bounds with halo")

	# Check that all cells in generation_bounds are preallocated
	for y in range(exp_gen.position.y, exp_gen.end.y):
		for x in range(exp_gen.position.x, exp_gen.end.x):
			assert(chunk_ctx.has_cell(Vector2i(x, y)), "Cell (%d, %d) must be preallocated" % [x, y])

	# Check that cells outside generation_bounds are not allocated
	assert(not chunk_ctx.has_cell(Vector2i(25, 25)), "Cell outside generation_bounds must not exist")
	print("PASS: 3. ChunkGenerationContext structure and preallocation verified")

	# -------------------------------------------------------------------------
	# 4. Test Execution of Stages on ChunkGenerationContext
	# -------------------------------------------------------------------------
	var terrain_stage := TerrainStage.new()
	terrain_stage.execute(chunk_ctx)

	# Verify heights in core and halo
	var cell_origin: WorldCell = chunk_ctx.get_cell(Vector2i(0, 0))
	assert(cell_origin != null, "Cell (0,0) must exist")
	assert(cell_origin.height != 0.0, "Cell height must be computed")
	assert(cell_origin.slope >= 0.0, "Cell slope must be computed")

	var halo_cell: WorldCell = chunk_ctx.get_cell(Vector2i(-2, -2))
	assert(halo_cell != null, "Halo cell (-2,-2) must exist")
	assert(halo_cell.height != 0.0, "Halo cell height must be computed")

	var ecology_stage := EcologyStage.new()
	ecology_stage.execute(chunk_ctx)
	assert(cell_origin.moisture >= 0.0 and cell_origin.moisture <= 1.0, "Moisture must be in range")
	assert(cell_origin.forest_density >= 0.0 and cell_origin.forest_density <= 1.0, "Forest density in range")

	var nav_stage := NavigationStage.new()
	nav_stage.execute(chunk_ctx)
	assert(cell_origin.slope_category in [0, 1, 2, 3], "Slope category must be classified")

	var veg_stage := VegetationStage.new()
	veg_stage.execute(chunk_ctx)

	# Verify that all generated vegetation in result.vegetation is strictly inside core_bounds
	for item in chunk_ctx.result.vegetation:
		var pos_2d := Vector2(item.position.x, item.position.z)
		var cell_coord := Vector2i(int(floor(pos_2d.x)), int(floor(pos_2d.y)))
		assert(chunk_ctx.core_bounds.has_point(cell_coord), "Vegetation item at %s must be inside core_bounds %s" % [str(pos_2d), str(chunk_ctx.core_bounds)])

	print("PASS: 4. Stages executed seamlessly on ChunkGenerationContext")

	# -------------------------------------------------------------------------
	# 5. Test Vegetation Order-Independence (Chunk A -> B vs B -> A)
	# -------------------------------------------------------------------------
	# Run A then B
	var ctx_a1 := _ChunkGenContextScript.new(seed_val, profile, Vector2i(0, 0), config)
	var ctx_b1 := _ChunkGenContextScript.new(seed_val, profile, Vector2i(1, 0), config)

	terrain_stage.execute(ctx_a1)
	ecology_stage.execute(ctx_a1)
	nav_stage.execute(ctx_a1)
	veg_stage.execute(ctx_a1)

	terrain_stage.execute(ctx_b1)
	ecology_stage.execute(ctx_b1)
	nav_stage.execute(ctx_b1)
	veg_stage.execute(ctx_b1)

	# Run B then A (inverted order)
	var ctx_b2 := _ChunkGenContextScript.new(seed_val, profile, Vector2i(1, 0), config)
	var ctx_a2 := _ChunkGenContextScript.new(seed_val, profile, Vector2i(0, 0), config)

	terrain_stage.execute(ctx_b2)
	ecology_stage.execute(ctx_b2)
	nav_stage.execute(ctx_b2)
	veg_stage.execute(ctx_b2)

	terrain_stage.execute(ctx_a2)
	ecology_stage.execute(ctx_a2)
	nav_stage.execute(ctx_a2)
	veg_stage.execute(ctx_a2)

	# Verify Chunk A vegetation matches 100% regardless of generation order
	assert(ctx_a1.result.vegetation.size() == ctx_a2.result.vegetation.size(), "Chunk A tree count must match across execution orders: %d vs %d" % [ctx_a1.result.vegetation.size(), ctx_a2.result.vegetation.size()])
	for idx in range(ctx_a1.result.vegetation.size()):
		var v1 = ctx_a1.result.vegetation[idx]
		var v2 = ctx_a2.result.vegetation[idx]
		assert(v1.type == v2.type, "Vegetation type match at %d" % idx)
		assert(v1.position.is_equal_approx(v2.position), "Vegetation position match at %d: %s vs %s" % [idx, str(v1.position), str(v2.position)])
		assert(is_equal_approx(v1.rotation_y, v2.rotation_y), "Rotation match at %d" % idx)

	# Verify Chunk B vegetation matches 100% regardless of generation order
	assert(ctx_b1.result.vegetation.size() == ctx_b2.result.vegetation.size(), "Chunk B tree count must match across execution orders: %d vs %d" % [ctx_b1.result.vegetation.size(), ctx_b2.result.vegetation.size()])
	for idx in range(ctx_b1.result.vegetation.size()):
		var v1 = ctx_b1.result.vegetation[idx]
		var v2 = ctx_b2.result.vegetation[idx]
		assert(v1.type == v2.type, "Vegetation type match at %d" % idx)
		assert(v1.position.is_equal_approx(v2.position), "Vegetation position match at %d: %s vs %s" % [idx, str(v1.position), str(v2.position)])

	print("PASS: 5. Vegetation is 100% deterministic and order-independent (A->B == B->A)")

	# -------------------------------------------------------------------------
	# 6. Test trim_to_core
	# -------------------------------------------------------------------------
	var chunk_data: ChunkData = ctx_a1.get_chunk_data()
	assert(chunk_data.cells.size() == exp_gen.size.x * exp_gen.size.y, "Cells before trim has halo: %d" % chunk_data.cells.size())
	chunk_data.trim_to_core()
	assert(chunk_data.cells.size() == 16 * 16, "Cells after trim has exactly 16*16 = 256 cells: %d" % chunk_data.cells.size())
	for pos in chunk_data.cells:
		assert(chunk_data.core_bounds.has_point(pos), "All remaining cells must be inside core_bounds")
	print("PASS: 6. trim_to_core removes halo correctly")

	print("\n>>> ALL TESTS IN BLOQUE 2 PASSED SUCCESSFULLY! <<<")
	quit(0)
