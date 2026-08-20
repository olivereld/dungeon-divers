extends SceneTree

## Test suite para validar los contratos de datos y configuraciones de src/floor_tile_generator.

const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const GeneratedFloorCluster = preload("res://src/floor_tile_generator/data/generated_floor_cluster.gd")
const FloorTileResult = preload("res://src/floor_tile_generator/data/floor_tile_result.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_tile_contracts (Floor Tile Data Contracts) ---")
	print("==================================================================")

	# 1. Validar FloorTileConfig
	var cfg := FloorTileConfig.new()
	assert(cfg.tile_size == 2.0, "Default tile_size must be 2.0")
	assert(cfg.margin == 0.035, "Default margin must be 0.035")
	assert(cfg.collision_mode == FloorTileConfig.CollisionMode.COMPOUND_BOX, "Default collision mode must be COMPOUND_BOX")
	
	var cloned = cfg.duplicate_config()
	assert(cloned.tile_size == 2.0 and cloned.seed == cfg.seed, "duplicate_config must preserve values")
	print("  [OK] FloorTileConfig contract validated.")

	# 2. Validar GeneratedFloorCluster
	var cluster := GeneratedFloorCluster.new(1)
	assert(cluster.cluster_id == 1, "Cluster ID must be 1")
	assert(cluster.mesh == null, "Initial mesh must be null")
	assert(cluster.collision_shapes.is_empty(), "Initial collision shapes must be empty")

	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 0.5, 2.0)
	cluster.add_collision_shape(box, Transform3D.IDENTITY)
	assert(cluster.collision_shapes.size() == 1, "add_collision_shape should register shape")

	var static_body: StaticBody3D = cluster.create_collision_body("TestBody")
	assert(static_body != null and static_body.get_child_count() == 1, "create_collision_body should instantiate children")
	static_body.free()

	var mi: MeshInstance3D = cluster.to_mesh_instance("CustomCluster")
	assert(mi.name == "CustomCluster_1", "to_mesh_instance should name node correctly")
	mi.free()
	print("  [OK] GeneratedFloorCluster contract validated.")

	# 3. Validar FloorTileResult
	var res := FloorTileResult.new()
	assert(res.success == true, "Default success must be true")
	assert(not res.has_errors(), "Should not have errors initially")
	res.add_diagnostic("WARN_EMPTY", "WARN", "Empty cluster warning")
	assert(res.success == true, "Warning should not fail result")
	res.add_diagnostic("FATAL_ERR", "FATAL", "Fatal error")
	assert(res.success == false, "Fatal diagnostic should mark success false")
	assert(res.has_errors() == true, "has_errors should return true")
	print("  [OK] FloorTileResult contract validated.")

	print("==================================================================")
	print("[PASS] test_floor_tile_contracts completado con 100% éxito!")
	print("==================================================================")
	quit(0)
