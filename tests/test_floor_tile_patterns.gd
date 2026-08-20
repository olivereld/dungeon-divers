extends SceneTree

## Test suite para validar FloorTilePattern y TileDescriptor (Fase M3).

const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const FloorTilePattern = preload("res://src/floor_tile_generator/patterns/floor_tile_pattern.gd")
const TileDescriptor = preload("res://src/floor_tile_generator/data/tile_descriptor.gd")
const FloorSurfaceCluster = preload("res://src/floor_tile_generator/data/floor_surface_cluster.gd")
const FloorSurfaceResult = preload("res://src/floor_tile_generator/data/floor_surface_result.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_tile_patterns (M3: Tile Patterns) ---")
	print("==================================================================")

	var pattern_gen := FloorTilePattern.new()
	var cfg := FloorTileConfig.new()
	cfg.tile_size = 2.0

	# 1. Probar STYLIZED_STONE (19 sub-losas con cobertura 100% de esquinas)
	cfg.pattern = FloorTileConfig.PatternType.STYLIZED_STONE
	var stone_descs = pattern_gen.generate_descriptors_for_cell(Vector2i(0, 0), cfg, 1337)
	assert(stone_descs.size() == 19, "STYLIZED_STONE should generate 19 stone slab descriptors")
	var d0 = stone_descs[0]
	assert(d0.world_offset == Vector2.ZERO, "World offset must match cell coordinate")
	assert(d0.height >= cfg.height_min and d0.height <= cfg.height_max, "Height within bounds")
	print("  [OK] STYLIZED_STONE pattern verified: %d descriptors." % stone_descs.size())

	# 2. Probar COBBLESTONE (4x4 = 16 adoquines)
	cfg.pattern = FloorTileConfig.PatternType.COBBLESTONE
	var cobble_descs = pattern_gen.generate_descriptors_for_cell(Vector2i(2, 3), cfg, 1337)
	assert(cobble_descs.size() == 16, "COBBLESTONE should generate 16 descriptors")
	var d_cobble = cobble_descs[0]
	assert(d_cobble.world_offset == Vector2(4.0, 6.0), "World offset must be (4.0, 6.0)")
	print("  [OK] COBBLESTONE pattern verified: 16 descriptors.")

	# 3. Probar BRICK pattern
	cfg.pattern = FloorTileConfig.PatternType.BRICK
	var brick_descs = pattern_gen.generate_descriptors_for_cell(Vector2i(1, 1), cfg, 1337)
	assert(brick_descs.size() >= 8, "BRICK pattern should generate at least 8 brick descriptors")
	print("  [OK] BRICK pattern verified: %d descriptors." % brick_descs.size())

	# 4. Probar SMOOTH_SLABS (2x2 = 4 losas)
	cfg.pattern = FloorTileConfig.PatternType.SMOOTH_SLABS
	var smooth_descs = pattern_gen.generate_descriptors_for_cell(Vector2i(0, 0), cfg, 1337)
	assert(smooth_descs.size() == 4, "SMOOTH_SLABS should generate 4 descriptors")
	print("  [OK] SMOOTH_SLABS pattern verified: 4 descriptors.")

	# 5. Probar RUINED_TILES (Fracturas poligonales orgánicas)
	cfg.pattern = FloorTileConfig.PatternType.RUINED_TILES
	var ruined_descs = pattern_gen.generate_descriptors_for_cell(Vector2i(0, 0), cfg, 1337)
	assert(ruined_descs.size() >= 6, "RUINED_TILES should generate fractured descriptors")
	print("  [OK] RUINED_TILES pattern verified: %d polygonal shards." % ruined_descs.size())

	# 6. Validar DTOs FloorSurfaceCluster y FloorSurfaceResult
	var cluster = FloorSurfaceCluster.new(5)
	cluster.descriptors = stone_descs
	assert(cluster.cluster_id == 5 and cluster.descriptors.size() == 19, "Cluster DTO verified")

	var res = FloorSurfaceResult.new()
	res.clusters.append(cluster)
	assert(res.success and res.clusters.size() == 1, "Result DTO verified")
	print("  [OK] FloorSurfaceCluster & FloorSurfaceResult DTOs verified.")

	print("==================================================================")
	print("[PASS] test_floor_tile_patterns completado con 100% éxito!")
	print("==================================================================")
	quit(0)
