extends SceneTree

const _ContinuousWallExtractorScript = preload("res://src/wall_mesh_generator/core/continuous_wall_extractor.gd")
const _ContinuousWallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd")
const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")

func _init() -> void:
	print("--- Running test_continuous_wall_generator ---")

	# 1. Crear un CellGrid de prueba con una habitación de 6x4 y un pasillo
	var grid := CellGrid.new(16, 16, CellGrid.CellType.WALL)
	for y in range(2, 6):
		for x in range(2, 8):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	# Pasillo saliendo hacia el sur
	for y in range(6, 10):
		grid.set_cell(Vector2i(4, y), CellGrid.CellType.CORRIDOR)

	# 2. Validar Extracción de Bucles de Contorno Cerrados
	var loops: Array = _ContinuousWallExtractorScript.extract_wall_loops(grid, 2.0)
	assert(not loops.is_empty(), "Wall loops must not be empty")
	print("  [OK] Extracted %d continuous closed wall loops from grid" % loops.size())

	for l in loops:
		assert(l.vertices.size() >= 3, "Loop must have at least 3 vertices")

	# 3. Validar Generación de Malla Continua
	var builder := _ContinuousWallMeshBuilderScript.new()
	var config := _WallMeshConfigScript.new()
	config.cube_size = 2.0
	config.cubes_high = 2
	config.seed = 42

	var wall_mesh: ArrayMesh = builder.build_dungeon_wall_mesh(grid, config)
	assert(wall_mesh != null, "Continuous wall mesh must be generated")
	assert(wall_mesh.get_surface_count() == 3, "Mesh must contain 3 surfaces: Trims, WallPanel, Bricks")

	assert(wall_mesh.surface_get_name(0) == "Trims", "Surface 0 must be Trims")
	assert(wall_mesh.surface_get_name(1) == "WallPanel", "Surface 1 must be WallPanel")
	assert(wall_mesh.surface_get_name(2) == "Bricks", "Surface 2 must be Bricks")

	var aabb: AABB = wall_mesh.get_aabb()
	print("  [OK] Continuous Wall Mesh Generated. AABB: %.2f x %.2f x %.2f m" % [aabb.size.x, aabb.size.y, aabb.size.z])
	assert(aabb.size.x > 8.0 and aabb.size.z > 8.0, "AABB should cover the room and corridor span")
	assert(aabb.size.y > 3.5, "AABB height should match 2 cubes high (~4m)")

	# 4. Validar Materiales Asignados
	for s in range(3):
		var mat = wall_mesh.surface_get_material(s)
		assert(mat != null, "Surface %d must have PBR material assigned" % s)
	print("  [OK] PBR materials attached to all 3 surfaces")

	# 5. Validar Integración en DungeonPresentationBuilder
	var pres_builder := DungeonPresentationBuilder.new()
	var semantic := DungeonSemanticResult.new()
	semantic.grid = grid
	semantic.gameplay_valid = true

	var staging_root := Node3D.new()
	var biome := BiomeProfile.new() # Procedural
	var dungeon_config := DungeonConfig.new()
	dungeon_config.cell_size = 2.0
	dungeon_config.wall_height = 2

	var pres_res: DungeonPresentationResult = pres_builder.build_presentation(
		semantic, staging_root, biome, dungeon_config
	)
	assert(pres_res.success, "Presentation build must succeed")

	var continuous_wall_node: MeshInstance3D = pres_res.presentation_root.get_node_or_null("ContinuousWalls")
	assert(continuous_wall_node != null, "ContinuousWalls node must exist in presentation hierarchy")
	assert(continuous_wall_node.mesh != null, "ContinuousWalls must have a valid mesh")
	print("  [OK] ContinuousWalls node successfully instantiated in DungeonPresentation")

	staging_root.free()
	print("\n>>> ALL CONTINUOUS WALL GENERATOR TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
