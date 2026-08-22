extends SceneTree

const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const PresentationContextBuilderScript = preload("res://src/presentation/architecture/presentation_context_builder.gd")
const PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const FixturePaletteResolverScript = preload("res://src/presentation/fixtures/fixture_palette_resolver.gd")
const FixtureResolverScript = preload("res://src/presentation/fixtures/fixture_resolver.gd")
const FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")

func _init() -> void:
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	print("==================================================================")
	print("--- Running test_fixture_resolver ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 448822
	cfg.use_fixed_seed = true
	cfg.dungeon_archetype = DungeonArchetypeScript.Type.MAUSOLEUM

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var orchestrator := SemanticOrchestratorScript.new()
	var sem = orchestrator.generate_semantics(res, cfg)

	var ctx_builder := PresentationContextBuilderScript.new()
	var room_contexts = ctx_builder.build_contexts(sem)

	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, room_contexts, sem)

	var pal_resolver := FixturePaletteResolverScript.new()
	var fix_resolver := FixtureResolverScript.new()

	test_fixture_resolver_determinism(room_contexts[0], partition, pal_resolver, fix_resolver, cfg.seed)
	test_fixture_wall_and_floor_placement(room_contexts, partition, pal_resolver, fix_resolver, cfg.seed)
	test_fixture_does_not_overlap_door(room_contexts, partition, pal_resolver, fix_resolver, cfg.seed)

	print("[PASS] All FixtureResolver tests passed successfully!")
	quit(0)

func test_fixture_resolver_determinism(room_ctx, partition, pal_resolver, fix_resolver, seed_val: int) -> void:
	var palette = pal_resolver.resolve_palette(room_ctx.profile)
	var dir1 = fix_resolver.resolve_room_fixtures(room_ctx, partition, palette, seed_val)
	var dir2 = fix_resolver.resolve_room_fixtures(room_ctx, partition, palette, seed_val)

	assert(dir1.size() == dir2.size(), "FAIL: Directive count mismatch in deterministic run")
	for i in range(dir1.size()):
		assert(dir1[i].cell == dir2[i].cell, "FAIL: Directive cell mismatch")
		assert(dir1[i].world_position == dir2[i].world_position, "FAIL: Directive position mismatch")
		assert(dir1[i].rotation_y == dir2[i].rotation_y, "FAIL: Directive rotation mismatch")
	print("  [OK] test_fixture_resolver_determinism passed.")

func test_fixture_wall_and_floor_placement(room_contexts: Array, partition, pal_resolver, fix_resolver, seed_val: int) -> void:
	for r_ctx in room_contexts:
		var palette = pal_resolver.resolve_palette(r_ctx.profile)
		var directives = fix_resolver.resolve_room_fixtures(r_ctx, partition, palette, seed_val)
		var placed_wall_cells: Array[Vector2i] = []
		var placed_floor_cells: Array[Vector2i] = []

		for d in directives:
			assert(d.style != null, "FAIL: Style must be attached")
			assert(d.placement != null, "FAIL: Placement must be attached")

			if d.placement_mode == FixturePlacementModeScript.Mode.WALL:
				for p in placed_wall_cells:
					var dist = abs(d.cell.x - p.x) + abs(d.cell.y - p.y)
					assert(dist >= palette.wall_fixture_spacing, "FAIL: Wall clearance violation")
				placed_wall_cells.append(d.cell)
			elif d.placement_mode == FixturePlacementModeScript.Mode.FLOOR:
				for p in placed_floor_cells:
					var dist = abs(d.cell.x - p.x) + abs(d.cell.y - p.y)
					assert(dist >= palette.floor_fixture_spacing, "FAIL: Floor clearance violation")
				placed_floor_cells.append(d.cell)

	print("  [OK] test_fixture_wall_and_floor_placement passed.")

func test_fixture_does_not_overlap_door(room_contexts: Array, partition, pal_resolver, fix_resolver, seed_val: int) -> void:
	for r_ctx in room_contexts:
		var palette = pal_resolver.resolve_palette(r_ctx.profile)
		var directives = fix_resolver.resolve_room_fixtures(r_ctx, partition, palette, seed_val)
		var r_geom = partition.get_room_geometry(r_ctx.room_id)

		for d in directives:
			for door_pos in r_geom.door_positions:
				assert(d.cell != door_pos, "FAIL: Fixture overlaps door position!")
				assert(abs(d.cell.x - door_pos.x) + abs(d.cell.y - door_pos.y) > 0, "FAIL: Fixture placed on door cell")

	print("  [OK] test_fixture_does_not_overlap_door passed.")
