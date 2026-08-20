extends SceneTree

## Test suite para validar los modos de colisión de FloorCollisionBuilder (Fase M5).

const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const FloorCollisionBuilder = preload("res://src/floor_tile_generator/collision/floor_collision_builder.gd")
const FloorSurfaceCluster = preload("res://src/floor_tile_generator/data/floor_surface_cluster.gd")
const FloorSurfaceMeshBuilder = preload("res://src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd")
const FloorTilePattern = preload("res://src/floor_tile_generator/patterns/floor_tile_pattern.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_collision_modes (M5: Collision Modes) ---")
	print("==================================================================")

	var collision_builder := FloorCollisionBuilder.new()
	var mesh_builder := FloorSurfaceMeshBuilder.new()
	var pattern_gen := FloorTilePattern.new()
	var cfg := FloorTileConfig.new()
	cfg.tile_size = 2.0

	var cells_l: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1)
	]

	# 1. Modo NONE
	cfg.collision_mode = FloorTileConfig.CollisionMode.NONE
	var c_none = FloorSurfaceCluster.new(1)
	collision_builder.build_collision_for_cluster(c_none, cells_l, cfg)
	assert(c_none.collision_shapes.is_empty(), "CollisionMode.NONE must produce 0 shapes")
	print("  [OK] CollisionMode.NONE verified.")

	# 2. Modo BOX
	cfg.collision_mode = FloorTileConfig.CollisionMode.BOX
	var c_box = FloorSurfaceCluster.new(2)
	collision_builder.build_collision_for_cluster(c_box, cells_l, cfg)
	assert(c_box.collision_shapes.size() == 1, "CollisionMode.BOX must produce 1 shape")
	var b_shape: BoxShape3D = c_box.collision_shapes[0] as BoxShape3D
	assert(b_shape != null and b_shape.size.x == 4.0 and b_shape.size.z == 4.0, "Bounding box covers (0,0) to (1,1)")
	print("  [OK] CollisionMode.BOX verified: 1 BoxShape3D.")

	# 3. Modo COMPOUND_BOX
	cfg.collision_mode = FloorTileConfig.CollisionMode.COMPOUND_BOX
	var c_compound = FloorSurfaceCluster.new(3)
	collision_builder.build_collision_for_cluster(c_compound, cells_l, cfg)
	assert(c_compound.collision_shapes.size() == 2, "L-shape has 2 rows -> 2 strip boxes")
	print("  [OK] CollisionMode.COMPOUND_BOX verified: 2 strip boxes.")

	# 4. Modo CONCAVE_TRIMESH
	cfg.collision_mode = FloorTileConfig.CollisionMode.CONCAVE_TRIMESH
	var c_trimesh = FloorSurfaceCluster.new(4)
	c_trimesh.cells = [Vector2i(0, 0)]
	c_trimesh.descriptors = pattern_gen.generate_descriptors_for_cell(Vector2i(0, 0), cfg, 100)
	c_trimesh.mesh = mesh_builder.build_cluster_mesh(c_trimesh, cfg)

	collision_builder.build_collision_for_cluster(c_trimesh, c_trimesh.cells, cfg)
	assert(c_trimesh.collision_shapes.size() == 1, "CONCAVE_TRIMESH should produce 1 shape")
	assert(c_trimesh.collision_shapes[0] is ConcavePolygonShape3D, "Shape must be ConcavePolygonShape3D")
	print("  [OK] CollisionMode.CONCAVE_TRIMESH verified: ConcavePolygonShape3D.")

	print("==================================================================")
	print("[PASS] test_floor_collision_modes completado con 100% éxito!")
	print("==================================================================")
	quit(0)
