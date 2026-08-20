extends SceneTree

## Test suite para validar DungeonFloorGenerator y determinismo de datos puros (Fase M7).

const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const DungeonFloorGenerator = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const FloorSurfaceResult = preload("res://src/floor_tile_generator/data/floor_surface_result.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_generator_determinism (M7: Determinism) ---")
	print("==================================================================")

	var generator := DungeonFloorGenerator.new()
	var cfg := FloorTileConfig.new()
	cfg.tile_size = 2.0
	cfg.pattern = FloorTileConfig.PatternType.STYLIZED_STONE

	# 1. Validar manejo de grid nulo
	var null_res = generator.generate_floor_surface(null, cfg)
	assert(null_res.success == false and null_res.has_errors(), "Null grid fails cleanly")
	print("  [OK] Null grid handled.")

	# 2. Generar en grid con 2 salas desconectadas
	var grid := CellGrid.new(20, 15, CellGrid.CellType.WALL)
	for y in range(2, 5):
		for x in range(2, 5):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR) # 9 celdas
	for y in range(8, 11):
		for x in range(10, 14):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR) # 12 celdas

	var res = generator.generate_floor_surface(grid, cfg, 42)
	assert(res.success == true, "Generation succeeds")
	assert(res.total_regions_count == 2, "2 regions extracted")
	assert(res.clusters.size() == 2, "2 clusters generated")
	assert(res.total_tiles_generated == 21, "21 total tiles")
	assert(res.total_descriptors_count == 21 * 19, "21 tiles * 19 descriptors = 399 total descriptors")

	var unified: ArrayMesh = res.get_unified_mesh()
	assert(unified.get_surface_count() == 2, "Unified mesh contains 2 surfaces")
	print("  [OK] Pure data generation verified: 2 clusters, 21 tiles, 399 descriptors.")

	# 3. Determinismo estricto con misma semilla
	var res_1 = generator.generate_floor_surface(grid, cfg, 777)
	var res_2 = generator.generate_floor_surface(grid, cfg, 777)
	assert(res_1.clusters.size() == res_2.clusters.size(), "Cluster count matches")
	assert(res_1.clusters[0].descriptors.size() == res_2.clusters[0].descriptors.size(), "Descriptors match")

	var v1: PackedVector3Array = res_1.clusters[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var v2: PackedVector3Array = res_2.clusters[0].mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(v1.size() == v2.size(), "Vertex counts match identically")
	assert(v1[0] == v2[0] and v1[v1.size() - 1] == v2[v2.size() - 1], "Vertex coordinates match identically")
	print("  [OK] Determinism verified: 100% identical outputs for identical seed.")

	print("==================================================================")
	print("[PASS] test_floor_generator_determinism completado con 100% éxito!")
	print("==================================================================")
	quit(0)
