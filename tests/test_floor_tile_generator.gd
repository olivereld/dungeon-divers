extends SceneTree

## Test suite para validar la generación de baldosas de suelo estilizadas (FloorTileGeometryBuilder).

const FloorTileGeometryBuilder = preload("res://src/wall_mesh_generator/core/floor_tile_geometry_builder.gd")
const WallMeshConfig = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const WallMeshBuilder = preload("res://src/wall_mesh_generator/core/wall_mesh_builder.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_tile_generator (Stylized Floor Tiles) ---")
	print("==================================================================")

	var builder := FloorTileGeometryBuilder.new()

	# 1. Probar baldosa individual (2.0m x 2.0m)
	var single_tile: ArrayMesh = builder.build_floor_tile_mesh(2.0, 1337)
	assert(single_tile != null, "Single tile mesh must be generated")
	assert(single_tile.get_surface_count() == 2, "Must have 2 surfaces (FloorSlabs and FloorMortar)")
	assert(single_tile.surface_get_name(0) == "FloorSlabs", "Surface 0 must be FloorSlabs")
	assert(single_tile.surface_get_name(1) == "FloorMortar", "Surface 1 must be FloorMortar")

	var aabb: AABB = single_tile.get_aabb()
	assert(aabb.size.x > 1.8 and aabb.size.z > 1.8, "AABB width/depth must cover ~2.0m tile")
	assert(aabb.size.y > 0.04 and aabb.size.y < 0.15, "AABB height must be ~0.08m (slabs thickness)")
	print("  [OK] Single stylized stone tile generated: 2 surfaces, AABB=(%.2f, %.2f, %.2f)m" % [aabb.size.x, aabb.size.y, aabb.size.z])

	# 2. Probar cuadrícula continua 3x3 (6.0m x 6.0m)
	var grid_mesh: ArrayMesh = builder.build_floor_grid_mesh(3, 3, 2.0, 42)
	assert(grid_mesh != null, "Grid mesh must be generated")
	assert(grid_mesh.get_surface_count() == 2, "Must have 2 surfaces")
	var grid_aabb: AABB = grid_mesh.get_aabb()
	assert(grid_aabb.size.x > 5.8 and grid_aabb.size.z > 5.8, "3x3 grid must cover ~6.0m area")
	print("  [OK] 3x3 continuous floor grid generated: AABB=(%.2f, %.2f, %.2f)m" % [grid_aabb.size.x, grid_aabb.size.y, grid_aabb.size.z])

	# 3. Probar integración con WallMeshBuilder
	var wall_builder := WallMeshBuilder.new()
	var cfg := WallMeshConfig.new()
	cfg.piece_type = WallMeshConfig.PieceType.FLOOR_TILE
	cfg.cube_size = 2.0
	cfg.seed = 999

	var manifest = wall_builder.build_brick_manifest(cfg)
	assert(not manifest.is_empty(), "Manifest for floor tile must not be empty")
	var built_mesh: ArrayMesh = wall_builder.build_partial_mesh(cfg, manifest, manifest.size())
	assert(built_mesh != null and built_mesh.get_surface_count() == 2, "WallMeshBuilder must build floor tile properly")
	print("  [OK] WallMeshBuilder integration verified")

	print("==================================================================")
	print("[PASS] test_floor_tile_generator completado con 100% éxito!")
	print("==================================================================")
	quit(0)
