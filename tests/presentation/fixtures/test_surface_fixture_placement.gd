extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const FixturePaletteResolverScript = preload("res://src/presentation/fixtures/fixture_palette_resolver.gd")
const FixtureResolverScript = preload("res://src/presentation/fixtures/fixture_resolver.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_surface_fixture_placement ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 332211
	cfg.use_fixed_seed = true

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var sem = SemanticOrchestratorScript.new().generate_semantics(res, cfg)
	var room_contexts = PresentationContextBuilderScript.new().build_contexts(sem)
	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, room_contexts, sem)

	var pal_resolver := FixturePaletteResolverScript.new()
	var fix_resolver := FixtureResolverScript.new()

	var surface_found := false
	for r_ctx in room_contexts:
		var palette = pal_resolver.resolve_palette(r_ctx.profile)
		var directives = fix_resolver.resolve_room_fixtures(r_ctx, partition, palette, cfg.seed)
		var r_geom = partition.get_room_geometry(r_ctx.room_id)

		for d in directives:
			if d.placement_mode == FixturePlacementModeScript.Mode.SURFACE:
				surface_found = true
				assert(r_geom.floor_cells.has(d.cell), "FAIL: Surface anchor must be on valid room floor cell")
				assert(d.placement.normal.is_equal_approx(Vector3.UP), "FAIL: Surface normal must be UP")

	assert(surface_found, "FAIL: At least one surface fixture should be placed across the rooms")
	print("  [OK] Surface fixtures (CandleHolder): valid surface anchor and normal verified.")
	print("[PASS] test_surface_fixture_placement completed successfully!")
	quit(0)
