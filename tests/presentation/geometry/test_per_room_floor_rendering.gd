extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const ArchitecturalStyleConfigResolverScript = preload("res://src/presentation/architecture/architectural_style_config_resolver.gd")
const DungeonFloorGeneratorScript = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")
const FloorTileConfigScript = preload("res://src/floor_tile_generator/config/floor_tile_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_per_room_floor_rendering ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 881122
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem)

	var style_resolver := ArchitecturalStyleConfigResolverScript.new()
	var base_floor_cfg := FloorTileConfigScript.new()
	base_floor_cfg.tile_size = cfg.cell_size

	var floor_gen := DungeonFloorGeneratorScript.new()
	var floor_res = floor_gen.generate_floor_for_partition(
		partition, style_resolver, base_floor_cfg, cfg.seed
	)

	assert(floor_res != null, "FAIL: FloorSurfaceResult cannot be null")
	assert(not floor_res.clusters.is_empty(), "FAIL: Clusters cannot be empty")
	assert(floor_res.total_tiles_generated > 0, "FAIL: Generated tiles must be > 0")

	# Verificar que cada cluster tiene malla y colisión asignada
	for cluster in floor_res.clusters:
		assert(cluster.mesh != null, "FAIL: Cluster mesh must be generated")
		assert(cluster.collision_shapes.size() > 0, "FAIL: Cluster collision shapes must be generated")

	print("  [OK] FloorSurfaceResult successfully generated from PresentationGeometryPartition.")
	print("  [OK] Per-room floor styling and meshes verified.")
	print("[PASS] test_per_room_floor_rendering completed successfully.")
	quit(0)
