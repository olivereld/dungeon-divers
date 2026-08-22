extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const FixturePaletteResolverScript = preload("res://src/presentation/fixtures/fixture_palette_resolver.gd")
const FixtureResolverScript = preload("res://src/presentation/fixtures/fixture_resolver.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_fixture_resolver_does_not_mutate_cell_grid ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 778899
	cfg.use_fixed_seed = true

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var sem = SemanticOrchestratorScript.new().generate_semantics(res, cfg)
	var room_contexts = PresentationContextBuilderScript.new().build_contexts(sem)
	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, room_contexts, sem)

	# 1. Snapshot bit-a-bit del CellGrid antes de resolver fixtures
	var grid_snapshot: Array = []
	for y in range(res.grid.height):
		for x in range(res.grid.width):
			grid_snapshot.append(res.grid.get_cell(Vector2i(x, y)))

	# 2. Ejecutar FixtureResolver en todas las habitaciones
	var pal_resolver := FixturePaletteResolverScript.new()
	var fix_resolver := FixtureResolverScript.new()

	for r_ctx in room_contexts:
		var palette = pal_resolver.resolve_palette(r_ctx.profile)
		var directives = fix_resolver.resolve_room_fixtures(r_ctx, partition, palette, cfg.seed)
		assert(not directives.is_empty(), "FAIL: Directives should be produced")

	# 3. Comprobar snapshot bit-a-bit del CellGrid después de resolver
	var idx: int = 0
	for y in range(res.grid.height):
		for x in range(res.grid.width):
			var current_val = res.grid.get_cell(Vector2i(x, y))
			assert(current_val == grid_snapshot[idx], "FAIL: CellGrid was mutated at (%d, %d)" % [x, y])
			idx += 1

	print("  [OK] Bit-by-bit CellGrid immutability verified across all room fixture resolutions.")
	print("[PASS] test_fixture_resolver_does_not_mutate_cell_grid completed successfully!")
	quit(0)
