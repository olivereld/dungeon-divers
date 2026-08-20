extends SceneTree

## Test suite para validar FloorTileClusterBuilder y FloorCollisionBuilder.

const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const FloorTileClusterBuilder = preload("res://src/floor_tile_generator/geometry/floor_tile_cluster_builder.gd")
const GeneratedFloorCluster = preload("res://src/floor_tile_generator/data/generated_floor_cluster.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_tile_cluster_builder (Clusters & Collisions) ---")
	print("==================================================================")

	var cluster_builder := FloorTileClusterBuilder.new()
	var cfg := FloorTileConfig.new()
	cfg.tile_size = 2.0
	cfg.collision_mode = FloorTileConfig.CollisionMode.COMPOUND_BOX

	# 1. Cluster vacío
	var empty_cluster = cluster_builder.build_cluster(0, [], cfg, 100)
	assert(empty_cluster.cells.is_empty(), "Empty cells list")
	assert(empty_cluster.collision_shapes.is_empty(), "No collision shapes for empty cluster")
	print("  [OK] Empty cluster handled correctly.")

	# 2. Cluster 2x2 (4 celdas) con COMPOUND_BOX (debe generar 2 tiras de 2x1)
	var cells_2x2: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(1, 1)
	]
	var cluster_2x2 = cluster_builder.build_cluster(1, cells_2x2, cfg, 42)
	assert(cluster_2x2.cluster_id == 1, "Cluster ID preserved")
	assert(cluster_2x2.mesh != null, "Mesh generated")
	assert(cluster_2x2.collision_shapes.size() == 2, "2x2 grid should generate 2 horizontal strip boxes")

	var static_body = cluster_2x2.create_collision_body("TestFloorBody")
	assert(static_body.get_child_count() == 2, "StaticBody3D must contain 2 CollisionShape3D children")
	var shape1: BoxShape3D = cluster_2x2.collision_shapes[0] as BoxShape3D
	assert(shape1.size.x == 4.0 and shape1.size.z == 2.0, "Strip box dimensions must be 4.0m x 2.0m")
	static_body.free()
	print("  [OK] 2x2 cluster generated: mesh + 2 optimized horizontal strip colliders.")

	# 3. Cluster con modo SIMPLE_BOX
	cfg.collision_mode = FloorTileConfig.CollisionMode.SIMPLE_BOX
	var cluster_simple = cluster_builder.build_cluster(2, cells_2x2, cfg, 42)
	assert(cluster_simple.collision_shapes.size() == 1, "SIMPLE_BOX must produce exactly 1 bounding BoxShape3D")
	var simple_shape: BoxShape3D = cluster_simple.collision_shapes[0] as BoxShape3D
	assert(simple_shape.size.x == 4.0 and simple_shape.size.z == 4.0, "Bounding box size must cover 4.0m x 4.0m")
	print("  [OK] SIMPLE_BOX collision mode verified.")

	# 4. Cluster con modo NONE
	cfg.collision_mode = FloorTileConfig.CollisionMode.NONE
	var cluster_none = cluster_builder.build_cluster(3, cells_2x2, cfg, 42)
	assert(cluster_none.collision_shapes.is_empty(), "CollisionMode.NONE must produce 0 collision shapes")
	print("  [OK] CollisionMode.NONE verified.")

	print("==================================================================")
	print("[PASS] test_floor_tile_cluster_builder completado con 100% éxito!")
	print("==================================================================")
	quit(0)
