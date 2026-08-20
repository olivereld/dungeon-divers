extends SceneTree

## Test suite para validar la fachada DungeonFloorTileGenerator.

const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const DungeonFloorTileGenerator = preload("res://src/floor_tile_generator/facade/dungeon_floor_tile_generator.gd")
const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const FloorTileResult = preload("res://src/floor_tile_generator/data/floor_tile_result.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_tile_generator_facade (End-to-End Facade) ---")
	print("==================================================================")

	var facade := DungeonFloorTileGenerator.new()
	var cfg := FloorTileConfig.new()
	cfg.tile_size = 2.0
	cfg.seed = 5555

	# 1. Manejo de grid nulo
	var null_res = facade.generate_floor_clusters(null, cfg)
	assert(null_res.success == false, "Null grid must result in failure")
	assert(null_res.has_errors() == true, "Null grid must record fatal diagnostic")
	print("  [OK] Null grid handled safely.")

	# 2. Generación en grid con 2 salas desconectadas
	var grid := CellGrid.new(20, 15, CellGrid.CellType.WALL)
	# Sala 1: 3x3 = 9 celdas
	for y in range(2, 5):
		for x in range(2, 5):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	# Sala 2: 4x3 = 12 celdas
	for y in range(8, 11):
		for x in range(10, 14):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var res = facade.generate_floor_clusters(grid, cfg, 777)
	assert(res.success == true, "Generation must succeed")
	assert(res.total_regions_extracted == 2, "Must extract 2 distinct regions")
	assert(res.generated_clusters.size() == 2, "Must produce 2 GeneratedFloorCluster objects")
	assert(res.total_tiles_generated == 21, "Total generated tiles must be 9 + 12 = 21")

	# Validar malla unificada helper
	var unified_mesh: ArrayMesh = res.get_unified_mesh()
	assert(unified_mesh != null and unified_mesh.get_surface_count() == 2, "Unified mesh must combine surfaces")
	print("  [OK] Multi-region floor generation verified: 2 clusters, 21 tiles, unified mesh valid.")

	# 3. attach to parent node
	var parent := Node3D.new()
	var nodes := facade.generate_and_attach_floor_nodes(grid, parent, cfg, 777)
	assert(nodes.size() == 2, "Should return 2 MeshInstance3D nodes")
	assert(parent.get_child_count() == 2, "Parent should have 2 children added")

	for node in nodes:
		var has_static_body := false
		for c in node.get_children():
			if c is StaticBody3D:
				has_static_body = true
				break
		assert(has_static_body == true, "Each floor cluster node must contain a StaticBody3D")

	parent.free()
	print("  [OK] generate_and_attach_floor_nodes attached nodes with colliders correctly.")

	# 4. Determinismo estricto
	var res_a = facade.generate_floor_clusters(grid, cfg, 9999)
	var res_b = facade.generate_floor_clusters(grid, cfg, 9999)
	assert(res_a.generated_clusters.size() == res_b.generated_clusters.size(), "Cluster count must match")
	var verts_a = res_a.generated_clusters[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var verts_b = res_b.generated_clusters[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(verts_a.size() == verts_b.size(), "Vertex counts must be identical for identical seed")
	assert(verts_a[0] == verts_b[0], "First vertex must match exactly")
	print("  [OK] Facade determinism verified.")

	print("==================================================================")
	print("[PASS] test_floor_tile_generator_facade completado con 100% éxito!")
	print("==================================================================")
	quit(0)
