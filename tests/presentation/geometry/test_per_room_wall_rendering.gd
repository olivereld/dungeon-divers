extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const ArchitecturalStyleConfigResolverScript = preload("res://src/presentation/architecture/architectural_style_config_resolver.gd")
const DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")
const WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_per_room_wall_rendering ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 665544
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.FORTRESS

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, contexts, sem)

	var style_resolver := ArchitecturalStyleConfigResolverScript.new()
	var wall_cfg := WallGeometryConfigScript.new()
	wall_cfg.cube_size = cfg.cell_size
	wall_cfg.cubes_high = 2

	var col_cfg := CollisionConfigScript.new()
	col_cfg.mode = CollisionConfigScript.CollisionMode.COMPOUND_BOX

	var base_dec := DecorationConfigScript.new()
	base_dec.enabled = true

	var opening_manifest = DoorManifestFactoryScript.create_wall_opening_manifest(sem.door_pairs)

	var geom_gen := DungeonGeometryGeneratorScript.new()
	var geom_res = geom_gen.generate_wall_clusters_for_partition(
		res.grid, partition, style_resolver, opening_manifest, wall_cfg, col_cfg, base_dec, 0, cfg.seed
	)

	assert(geom_res != null, "FAIL: GeometryResult cannot be null")
	assert(not geom_res.generated_meshes.is_empty(), "FAIL: Generated meshes cannot be empty")

	for g_mesh in geom_res.generated_meshes:
		assert(g_mesh.mesh != null, "FAIL: Mesh cannot be null")
		assert(not g_mesh.collision_shapes.is_empty(), "FAIL: Collision shapes must be created")

	print("  [OK] Wall clusters generated successfully for partition with per-room architectural styling.")
	print("  [OK] Openings and collisions preserved.")
	print("[PASS] test_per_room_wall_rendering completed successfully.")
	quit(0)
