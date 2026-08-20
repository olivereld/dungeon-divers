extends SceneTree

## Test suite para validar FloorSurfaceMeshBuilder (Fase M4).

const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const FloorTilePattern = preload("res://src/floor_tile_generator/patterns/floor_tile_pattern.gd")
const FloorSurfaceCluster = preload("res://src/floor_tile_generator/data/floor_surface_cluster.gd")
const FloorSurfaceMeshBuilder = preload("res://src/floor_tile_generator/geometry/floor_surface_mesh_builder.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_surface_mesh_builder (M4: Mesh Builder) ---")
	print("==================================================================")

	var mesh_builder := FloorSurfaceMeshBuilder.new()
	var pattern_gen := FloorTilePattern.new()
	var cfg := FloorTileConfig.new()
	cfg.tile_size = 2.0

	# 1. Cluster vacío
	var empty_cluster = FloorSurfaceCluster.new(0)
	var empty_mesh: ArrayMesh = mesh_builder.build_cluster_mesh(empty_cluster, cfg)
	assert(empty_mesh.get_surface_count() == 0, "Empty cluster must produce 0 surfaces")
	print("  [OK] Empty cluster handled.")

	# 2. Cluster con 1 celda
	var cluster_1 = FloorSurfaceCluster.new(1)
	cluster_1.cells = [Vector2i(0, 0)]
	cluster_1.descriptors = pattern_gen.generate_descriptors_for_cell(Vector2i(0, 0), cfg, 1234)

	var mesh_1: ArrayMesh = mesh_builder.build_cluster_mesh(cluster_1, cfg)
	assert(mesh_1.get_surface_count() == 2, "Must contain 2 surfaces (FloorSlabs and FloorMortar)")
	assert(mesh_1.surface_get_name(0) == "FloorSlabs", "Surface 0 is FloorSlabs")
	assert(mesh_1.surface_get_name(1) == "FloorMortar", "Surface 1 is FloorMortar")

	var aabb_1: AABB = mesh_1.get_aabb()
	assert(aabb_1.size.x >= 1.9 and aabb_1.size.z >= 1.9, "AABB covers single tile")
	print("  [OK] Single tile mesh generated: 2 surfaces, AABB=(%.2f, %.2f, %.2f)m" % [aabb_1.size.x, aabb_1.size.y, aabb_1.size.z])

	# 3. Cluster con 4 celdas (2x2) y patrón COBBLESTONE
	cfg.pattern = FloorTileConfig.PatternType.COBBLESTONE
	var cluster_2x2 = FloorSurfaceCluster.new(2)
	for y in range(2):
		for x in range(2):
			cluster_2x2.cells.append(Vector2i(x, y))
			var descs = pattern_gen.generate_descriptors_for_cell(Vector2i(x, y), cfg, 999)
			cluster_2x2.descriptors.append_array(descs)

	assert(cluster_2x2.descriptors.size() == 4 * 16, "2x2 cobblestone must have 64 descriptors")
	var mesh_cobble: ArrayMesh = mesh_builder.build_cluster_mesh(cluster_2x2, cfg)
	assert(mesh_cobble.get_surface_count() == 2, "Cobblestone cluster has 2 surfaces")
	var aabb_cobble: AABB = mesh_cobble.get_aabb()
	assert(aabb_cobble.size.x >= 3.9 and aabb_cobble.size.z >= 3.9, "AABB covers 2x2 tiles")
	print("  [OK] 2x2 Cobblestone cluster mesh generated with 64 stones.")

	print("==================================================================")
	print("[PASS] test_floor_surface_mesh_builder completado con 100% éxito!")
	print("==================================================================")
	quit(0)
