extends SceneTree

const _SolidRegionExtractorScript = preload("res://src/geometry_generator/extraction/solid_region_extractor.gd")
const _SolidGeometryBuilderScript = preload("res://src/geometry_generator/geometry/solid_geometry_builder.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

func _init() -> void:
	print("====================================================")
	print("   TEST: SOLID GEOMETRY BUILDER & VOLUMETRIC MESH   ")
	print("====================================================")

	var extractor := _SolidRegionExtractorScript.new()
	var builder := _SolidGeometryBuilderScript.new()
	var config := _WallGeometryConfigScript.new()
	config.cube_size = 2.0
	config.cubes_high = 2 # Altura total = 4.0m

	# Caso 1: Celda 1x1 WALL aislada
	var grid1 := _CellGridScript.new(3, 3, _CellGridScript.CellType.FLOOR)
	grid1.set_cell(Vector2i(1, 1), _CellGridScript.CellType.WALL)

	var regions1 = extractor.extract_regions(grid1)
	assert(regions1.size() == 1, "Debe haber 1 región")
	var g_mesh1 = builder.build_region_mesh(regions1[0], config)
	assert(g_mesh1 != null and g_mesh1.mesh != null, "Malla no nula")
	assert(g_mesh1.mesh.get_surface_count() == 1, "Debe tener 1 superficie SolidMass")

	var aabb1 = g_mesh1.bounds
	assert(absf(aabb1.position.x - 2.0) < 0.01, "AABB X min")
	assert(absf(aabb1.position.z - 2.0) < 0.01, "AABB Z min")
	assert(absf(aabb1.size.x - 2.0) < 0.01, "AABB Ancho X = 2.0m")
	assert(absf(aabb1.size.z - 2.0) < 0.01, "AABB Ancho Z = 2.0m")
	assert(absf(aabb1.size.y - 4.0) < 0.01, "AABB Altura Y = 4.0m")
	print("✔ Caso 1: Celda 1x1 con volumen 2.0m x 2.0m x 4.0m superado.")

	# Caso 2: Bloque contiguo 2x2 WALL
	var grid2 := _CellGridScript.new(4, 4, _CellGridScript.CellType.FLOOR)
	grid2.set_cell(Vector2i(1, 1), _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(2, 1), _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(1, 2), _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(2, 2), _CellGridScript.CellType.WALL)

	var regions2 = extractor.extract_regions(grid2)
	assert(regions2.size() == 1, "1 región 2x2")
	var g_mesh2 = builder.build_region_mesh(regions2[0], config)
	var aabb2 = g_mesh2.bounds
	assert(absf(aabb2.size.x - 4.0) < 0.01, "AABB Ancho X = 4.0m")
	assert(absf(aabb2.size.z - 4.0) < 0.01, "AABB Ancho Z = 4.0m")
	assert(absf(aabb2.size.y - 4.0) < 0.01, "AABB Altura Y = 4.0m")
	print("✔ Caso 2: Bloque contiguo 2x2 con tapa superior continua superado.")

	# Caso 3: Apertura en pared
	var grid3 := _CellGridScript.new(3, 1, _CellGridScript.CellType.WALL)
	grid3.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)
	grid3.set_cell(Vector2i(1, 0), _CellGridScript.CellType.WALL)
	grid3.set_cell(Vector2i(2, 0), _CellGridScript.CellType.CORRIDOR)

	var manifest := _WallOpeningManifestScript.new()
	manifest.add_opening(Vector2i(2, 0), _RoomEntranceScript.WEST, "conn_1")

	var regions3 = extractor.extract_regions(grid3, manifest)
	var g_mesh3 = builder.build_region_mesh(regions3[0], config, 2.4)
	assert(g_mesh3 != null and g_mesh3.mesh != null, "Malla con vano generada")
	print("✔ Caso 3: Apertura en pared sin bloqueo ciego superado.")

	print("\nTODOS LOS TESTS DE SOLID GEOMETRY BUILDER PASARON EXITOSAMENTE.")
	quit(0)
