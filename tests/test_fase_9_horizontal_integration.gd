extends SceneTree

## Suite de integración End-to-End para la Fase 9: Compleción Estructural Horizontal.
## Valida el pipeline completo real: Pipeline -> SemanticOrchestrator -> PresentationBuilder.

const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("================================================================")
	print("   EJECUTANDO SUITE DE INTEGRACION E2E - FASE 9 (HORIZONTAL)   ")
	print("================================================================")

	var pipeline := DungeonPipeline.new()
	var semantic_orchestrator := SemanticOrchestrator.new()
	var presentation_builder := DungeonPresentationBuilder.new()

	var biome := BiomeProfile.new()
	biome.name = "TestDungeon"
	biome.id = &"test_dungeon"

	var config := DungeonConfig.new()
	config.grid_width = 48
	config.grid_height = 48
	config.algorithm = "Hybrid"
	config.mission_depth = 4
	config.seed = 1337
	config.use_fixed_seed = true

	# 1. Generación de Mazmorra Lógica (Core)
	var dungeon_res: DungeonResult = pipeline.generate(config)
	assert(dungeon_res != null, "DungeonResult must be valid")
	assert(dungeon_res.validation != null and dungeon_res.validation.hard_valid, "Generated dungeon must satisfy quality gate")
	print("  [OK] Core Dungeon generated: %d rooms, %d door pairs" % [
		dungeon_res.rooms.size(), dungeon_res.door_pairs.size()
	])

	# 2. Generación de la Capa Semántica Real mediante SemanticOrchestrator
	var semantic_res: DungeonSemanticResult = semantic_orchestrator.generate_semantics(dungeon_res, config)
	assert(semantic_res != null, "SemanticOrchestrator must return a DungeonSemanticResult")
	assert(semantic_res.gameplay_valid, "SemanticResult must pass gameplay validation")
	assert(semantic_res.is_committed, "SemanticResult must be committed before presentation")
	assert(semantic_res.grid == dungeon_res.grid, "SemanticResult must reference the generated CellGrid")
	assert(semantic_res.rooms.size() == dungeon_res.rooms.size(), "SemanticResult must preserve RoomData set")
	assert(semantic_res.door_pairs.size() == dungeon_res.door_pairs.size(), "SemanticResult must preserve DoorPair set")
	print("  [OK] Semantic layer generated and committed")

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
	assert(continuous_walls.get_child_count() > 0, "ContinuousWalls must have collision body")
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
