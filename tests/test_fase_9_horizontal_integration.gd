extends SceneTree

## Suite de integración End-to-End para la Fase 9: Compleción Estructural Horizontal.
## Valida el pipeline completo: Pipeline -> Semantic -> Presentation (Wall Mesh + Carved Openings + Doors).

func _init() -> void:
	print("================================================================")
	print("   EJECUTANDO SUITE DE INTEGRACION E2E - FASE 9 (HORIZONTAL)   ")
	print("================================================================")

	var pipeline := DungeonPipeline.new()
	var presentation_builder := DungeonPresentationBuilder.new()
	var biome := BiomeProfile.new()
	biome.name = "TestDungeon"
	biome.id = &"test_dungeon"

	var config := DungeonConfig.new()
	config.grid_width = 32
	config.grid_height = 32
	config.algorithm = "Hybrid"
	config.mission_depth = 4
	config.seed = 1337

	# 1. Generación de Mazmorra Lógica (Core)
	var dungeon_res: DungeonResult = pipeline.generate(config)
	assert(dungeon_res != null, "DungeonResult must be valid")
	assert(dungeon_res.validation.is_winnable, "Generated dungeon must be winnable")
	print("  [OK] Core Dungeon generated: %d rooms, %d door pairs" % [
		dungeon_res.rooms.size(), dungeon_res.door_pairs.size()
	])

	# 2. Envoltura Semántica
	var semantic_res := DungeonSemanticResult.new()
	semantic_res.grid = dungeon_res.grid
	semantic_res.rooms = dungeon_res.rooms
	semantic_res.connections = dungeon_res.connections
	semantic_res.door_pairs = dungeon_res.door_pairs
	semantic_res.is_valid = true

	# Guardar copia de celdas para validar inmutabilidad del CellGrid
	var original_cells: Dictionary = {}
	for y in range(dungeon_res.grid.height):
		for x in range(dungeon_res.grid.width):
			var c := Vector2i(x, y)
			original_cells[c] = dungeon_res.grid.get_cell(c)

	# 3. Materialización 3D mediante DungeonPresentationBuilder
	var parent_root := Node3D.new()
	var pres_res: DungeonPresentationResult = presentation_builder.build_presentation(
		semantic_res, parent_root, biome, config, null, true
	)

	# 4. Validaciones de Invariantes de Fase 9
	assert(pres_res != null and pres_res.success, "Presentation build must succeed")
	assert(pres_res.staging_committed, "Staging root must be committed")
	assert(parent_root.get_child_count() > 0, "Parent root must contain presentation root")

	var pres_root: Node3D = pres_res.presentation_root
	assert(pres_root != null, "PresentationRoot must exist")

	# 4.1 Validar presencia de ContinuousWalls
	var continuous_walls: MeshInstance3D = pres_root.get_node_or_null("ContinuousWalls")
	assert(continuous_walls != null, "ContinuousWalls must be instantiated in presentation root")
	assert(continuous_walls.mesh != null and continuous_walls.mesh.get_surface_count() == 3,
		"ContinuousWalls must contain 3 surfaces (Trim, Panel, Bricks)")
	assert(continuous_walls.get_child_count() > 0, "ContinuousWalls must have trimesh collision body")
	print("  [OK] ContinuousWalls generated with 3 PBR surfaces and static collision")

	# 4.2 Validar contenedor y entidades de Puertas
	var doors_container: Node3D = pres_root.get_node_or_null("Doors")
	if not dungeon_res.door_pairs.is_empty():
		assert(doors_container != null, "Doors container must exist when door_pairs are present")
		assert(doors_container.get_child_count() > 0, "Doors container must contain spawned door arches")
		print("  [OK] Doors container verified with %d spawned door instances" % doors_container.get_child_count())

	# 4.3 Validar Inmutabilidad del CellGrid (0 mutaciones en Core)
	for y in range(dungeon_res.grid.height):
		for x in range(dungeon_res.grid.width):
			var c := Vector2i(x, y)
			assert(dungeon_res.grid.get_cell(c) == original_cells[c],
				"CellGrid must remain 100% immutable during Presentation building")
	print("  [OK] CellGrid immutability verified (0 cell mutations)")

	# 4.4 Validar Atomic Swap
	var second_pres_res: DungeonPresentationResult = presentation_builder.build_presentation(
		semantic_res, parent_root, biome, config, pres_root, true
	)
	assert(second_pres_res != null and second_pres_res.success, "Second presentation build must succeed via Atomic Swap")
	assert(parent_root.get_child_count() == 1, "Parent root must contain exactly 1 active presentation root after swap")
	print("  [OK] Atomic Swap verified successfully")

	parent_root.free()
	print("\n>>> ALL FASE 9 HORIZONTAL INTEGRATION TESTS PASSED PERFECTLY! <<<\n")
	quit(0)
