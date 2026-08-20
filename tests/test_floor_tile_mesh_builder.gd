extends SceneTree

## Test suite para validar FloorTileMeshBuilder en src/floor_tile_generator/geometry.

const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const FloorTileMeshBuilder = preload("res://src/floor_tile_generator/geometry/floor_tile_mesh_builder.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_tile_mesh_builder (Floor Mesh Geometry) ---")
	print("==================================================================")

	var builder := FloorTileMeshBuilder.new()
	var cfg := FloorTileConfig.new()
	cfg.tile_size = 2.0
	cfg.seed = 1234

	# 1. Región vacía
	var empty_mesh: ArrayMesh = builder.build_region_mesh([], cfg, 1234)
	assert(empty_mesh.get_surface_count() == 0, "Empty region should produce 0 surfaces")
	print("  [OK] Empty region handled correctly.")

	# 2. Región de 1 baldosa
	var single_mesh: ArrayMesh = builder.build_region_mesh([Vector2i(0, 0)], cfg, 1234)
	assert(single_mesh != null, "Single tile mesh must not be null")
	assert(single_mesh.get_surface_count() == 2, "Must have 2 surfaces (FloorSlabs and FloorMortar)")
	assert(single_mesh.surface_get_name(0) == "FloorSlabs", "Surface 0 must be FloorSlabs")
	assert(single_mesh.surface_get_name(1) == "FloorMortar", "Surface 1 must be FloorMortar")

	var aabb: AABB = single_mesh.get_aabb()
	assert(aabb.size.x >= 1.9 and aabb.size.z >= 1.9, "AABB must cover ~2.0m width and depth")
	assert(aabb.size.y > 0.04 and aabb.size.y < 0.15, "AABB height must be ~0.08m (slabs thickness)")
	print("  [OK] Single tile mesh verified: 2 surfaces, AABB=(%.2f, %.2f, %.2f)m" % [aabb.size.x, aabb.size.y, aabb.size.z])

	# 3. Región 3x3 continua (9 celdas)
	var cells_3x3: Array[Vector2i] = []
	for y in range(3):
		for x in range(3):
			cells_3x3.append(Vector2i(x, y))

	var mesh_3x3: ArrayMesh = builder.build_region_mesh(cells_3x3, cfg, 42)
	assert(mesh_3x3.get_surface_count() == 2, "3x3 region must have 2 surfaces")
	var aabb_3x3: AABB = mesh_3x3.get_aabb()
	assert(aabb_3x3.size.x >= 5.9 and aabb_3x3.size.z >= 5.9, "3x3 AABB must cover ~6.0m area")
	print("  [OK] 3x3 region mesh verified: AABB=(%.2f, %.2f, %.2f)m" % [aabb_3x3.size.x, aabb_3x3.size.y, aabb_3x3.size.z])

	# 4. Determinismo: Misma semilla debe generar mallas idénticas
	var mesh_det_1: ArrayMesh = builder.build_region_mesh(cells_3x3, cfg, 9999)
	var mesh_det_2: ArrayMesh = builder.build_region_mesh(cells_3x3, cfg, 9999)
	var arrays_1 = mesh_det_1.surface_get_arrays(0)
	var arrays_2 = mesh_det_2.surface_get_arrays(0)
	var verts_1: PackedVector3Array = arrays_1[Mesh.ARRAY_VERTEX]
	var verts_2: PackedVector3Array = arrays_2[Mesh.ARRAY_VERTEX]
	assert(verts_1.size() == verts_2.size(), "Vertex count must match exactly for same seed")
	assert(verts_1[0] == verts_2[0] and verts_1[verts_1.size() - 1] == verts_2[verts_2.size() - 1], "Vertices must match identically")
	print("  [OK] Mesh generation determinism confirmed.")

	print("==================================================================")
	print("[PASS] test_floor_tile_mesh_builder completado con 100% éxito!")
	print("==================================================================")
	quit(0)
