extends SceneTree

## Test suite para validar la integración de FloorTileGenerator en DungeonPresentationBuilder.

const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_tile_presentation_integration ---")
	print("==================================================================")

	var pipeline := DungeonPipeline.new()
	var semantic_orchestrator := SemanticOrchestrator.new()
	var presentation_builder := DungeonPresentationBuilder.new()

	var biome := BiomeProfile.new()
	biome.name = "TestDungeon"
	biome.id = &"test_dungeon"

	var config := DungeonConfig.new()
	config.grid_width = 36
	config.grid_height = 36
	config.algorithm = "Hybrid"
	config.mission_depth = 3
	config.seed = 1337
	config.use_fixed_seed = true

	# 1. Generar Lógica + Semántica
	var dungeon_res = pipeline.generate(config)
	assert(dungeon_res != null, "DungeonResult valid")
	var semantic_res = semantic_orchestrator.generate_semantics(dungeon_res, config)
	assert(semantic_res != null and semantic_res.gameplay_valid, "SemanticResult valid")

	# 2. Materializar en Presentación
	var parent_root := Node3D.new()
	var pres_res = presentation_builder.build_presentation(
		semantic_res, parent_root, biome, config, null, true
	)

	assert(pres_res != null and pres_res.success, "Presentation build must succeed")
	var pres_root: Node3D = pres_res.presentation_root
	assert(pres_root != null, "Presentation root node must exist")

	# 3. Validar presencia de FloorTiles
	var floor_tiles_root: Node3D = pres_root.get_node_or_null("FloorTiles")
	assert(floor_tiles_root != null, "FloorTiles container must exist in presentation root")
	assert(floor_tiles_root.get_child_count() > 0, "FloorTiles must contain at least 1 FloorCluster")

	var first_cluster: MeshInstance3D = floor_tiles_root.get_child(0) as MeshInstance3D
	assert(first_cluster != null, "Cluster child must be MeshInstance3D")
	assert(first_cluster.mesh != null and first_cluster.mesh.get_surface_count() == 2,
		"Cluster mesh must contain 2 surfaces (FloorSlabs and FloorMortar)")

	# Validar colisión de suelo
	var floor_body: StaticBody3D = first_cluster.get_node_or_null("FloorStaticBody")
	assert(floor_body != null, "FloorStaticBody must exist under FloorCluster")
	assert(floor_body.get_child_count() > 0, "FloorStaticBody must contain CollisionShape3D children")
	print("  [OK] FloorTiles container verified: %d clusters with 2-surface meshes and StaticBody3D" % floor_tiles_root.get_child_count())

	# 4. Validar que ContinuousWalls también coexiste intacto
	var continuous_walls: MeshInstance3D = pres_root.get_node_or_null("ContinuousWalls")
	assert(continuous_walls != null, "ContinuousWalls must coexist with FloorTiles")
	print("  [OK] ContinuousWalls and FloorTiles coexistence verified.")

	# 5. Validar Atomic Swap
	var second_pres_res = presentation_builder.build_presentation(
		semantic_res, parent_root, biome, config, pres_root, true
	)
	assert(second_pres_res != null and second_pres_res.success, "Atomic swap with FloorTiles must succeed")
	assert(parent_root.get_child_count() == 1, "Parent root must contain exactly 1 active presentation")

	parent_root.free()

	print("==================================================================")
	print("[PASS] test_floor_tile_presentation_integration completado con 100% éxito!")
	print("==================================================================")
	quit(0)
