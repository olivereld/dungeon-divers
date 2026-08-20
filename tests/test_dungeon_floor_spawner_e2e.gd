extends SceneTree

## Test suite para validar DungeonFloorSpawner y la integración E2E en PresentationBuilder (Fase M8).

const DungeonPipeline = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfig = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const SemanticOrchestrator = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonPresentationBuilder = preload("res://src/dungeon_generator/presentation/dungeon_presentation_builder.gd")
const DungeonFloorSpawner = preload("res://src/dungeon_generator/presentation/dungeon_floor_spawner.gd")
const DungeonFloorGenerator = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const FloorTileConfig = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")
const BiomeProfile = preload("res://src/dungeon_generator/presentation/biome_profile.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_dungeon_floor_spawner_e2e (M8: Presentation Spawner) ---")
	print("==================================================================")

	var pipeline := DungeonPipeline.new()
	var semantic_orchestrator := SemanticOrchestrator.new()
	var presentation_builder := DungeonPresentationBuilder.new()
	var floor_generator := DungeonFloorGenerator.new()
	var floor_spawner := DungeonFloorSpawner.new()

	var biome := BiomeProfile.new()
	biome.name = "TestDungeon"
	biome.id = &"test_dungeon"

	var config := DungeonConfig.new()
	config.grid_width = 32
	config.grid_height = 32
	config.algorithm = "Hybrid"
	config.mission_depth = 3
	config.seed = 1337
	config.use_fixed_seed = true

	# 1. Pipeline Lógico + Semántico
	var dungeon_res = pipeline.generate(config)
	assert(dungeon_res != null, "DungeonResult valid")
	var semantic_res = semantic_orchestrator.generate_semantics(dungeon_res, config)
	assert(semantic_res != null and semantic_res.gameplay_valid, "SemanticResult valid")

	# 2. Test directo de DungeonFloorSpawner
	var floor_cfg := FloorTileConfig.new()
	floor_cfg.tile_size = 2.0
	floor_cfg.pattern = FloorTileConfig.PatternType.STYLIZED_STONE
	floor_cfg.collision_mode = FloorTileConfig.CollisionMode.COMPOUND_BOX

	var floor_surface_res = floor_generator.generate_floor_surface(semantic_res.grid, floor_cfg, 1337)
	assert(floor_surface_res.success and floor_surface_res.clusters.size() > 0, "FloorSurfaceResult valid")

	var standalone_staging := Node3D.new()
	var spawn_out: Dictionary = floor_spawner.spawn_floor(floor_surface_res, standalone_staging, biome)
	assert(spawn_out.has("floor_container") and spawn_out["floor_container"] != null, "Spawner creates FloorTiles container")
	assert(standalone_staging.get_child_count() == 1, "Standalone staging contains FloorTiles")

	var floor_container: Node3D = spawn_out["floor_container"]
	assert(floor_container.get_child_count() == floor_surface_res.clusters.size(), "All clusters spawned")

	standalone_staging.free()
	print("  [OK] DungeonFloorSpawner standalone materialization verified: %d clusters." % floor_surface_res.clusters.size())

	# 3. Test de Integración completa con DungeonPresentationBuilder
	var presentation_parent := Node3D.new()
	var pres_res = presentation_builder.build_presentation(
		semantic_res, presentation_parent, biome, config, null, true
	)

	assert(pres_res != null and pres_res.success, "PresentationBuilder succeeds")
	var pres_root: Node3D = pres_res.presentation_root
	assert(pres_root != null, "Presentation root exists")

	var pres_floor_tiles: Node3D = pres_root.get_node_or_null("FloorTiles")
	assert(pres_floor_tiles != null, "FloorTiles exists in presentation root")
	assert(pres_floor_tiles.get_child_count() > 0, "FloorTiles contains spawned clusters")

	var first_cluster: MeshInstance3D = pres_floor_tiles.get_child(0) as MeshInstance3D
	assert(first_cluster != null and first_cluster.mesh.get_surface_count() == 2, "Cluster has 2 PBR surfaces")
	assert(first_cluster.get_node_or_null("FloorStaticBody") != null, "Cluster has FloorStaticBody")
	print("  [OK] PresentationBuilder E2E integration verified: FloorTiles container cleanly spawned.")

	# 4. Validar Atomic Swap
	var swap_res = presentation_builder.build_presentation(
		semantic_res, presentation_parent, biome, config, pres_root, true
	)
	assert(swap_res != null and swap_res.success, "Atomic Swap succeeds")
	assert(presentation_parent.get_child_count() == 1, "Exactly 1 presentation root after swap")

	presentation_parent.free()

	print("==================================================================")
	print("[PASS] test_dungeon_floor_spawner_e2e completado con 100% éxito!")
	print("==================================================================")
	quit(0)
