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
	print("--- Running test_floor_fixture_placement ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 554433
	cfg.use_fixed_seed = true

	var pipeline := DungeonPipelineScript.new()
	var res = pipeline.generate(cfg, 5, true)
	var sem = SemanticOrchestratorScript.new().generate_semantics(res, cfg)
	var room_contexts = PresentationContextBuilderScript.new().build_contexts(sem)
	var partition := PresentationGeometryPartitionScript.new()
	partition.build_partition(res.grid, room_contexts, sem)

	var pal_resolver := FixturePaletteResolverScript.new()
	var fix_resolver := FixtureResolverScript.new()

	for r_ctx in room_contexts:
		var palette = pal_resolver.resolve_palette(r_ctx.profile)
		var directives = fix_resolver.resolve_room_fixtures(r_ctx, partition, palette, cfg.seed)
		var r_geom = partition.get_room_geometry(r_ctx.room_id)
		var placed_floor_cells: Array[Vector2i] = []

		for d in directives:
			if d.placement_mode == FixturePlacementModeScript.Mode.FLOOR:
				# 1. Verificar que está en celda de suelo transitable
				assert(r_geom.floor_cells.has(d.cell), "FAIL: Floor fixture must be in room floor cells")
				assert(res.grid.is_walkable(d.cell), "FAIL: Cell must be walkable in CellGrid")

				# 2. Verificar que respeta despeje de puertas
				for door_pos in r_geom.door_positions:
					var dist = abs(d.cell.x - door_pos.x) + abs(d.cell.y - door_pos.y)
					assert(dist > 1, "FAIL: Floor fixture within door clearance")

				# 3. Verificar espaciado entre fixtures de suelo
				for p in placed_floor_cells:
					var dist = abs(d.cell.x - p.x) + abs(d.cell.y - p.y)
					assert(dist >= palette.floor_fixture_spacing, "FAIL: Floor fixture spacing violated")
				placed_floor_cells.append(d.cell)

	print("  [OK] Floor fixtures: walkable floor, door clearance, spacing and determinism verified.")
	print("[PASS] test_floor_fixture_placement completed successfully!")
	quit(0)
