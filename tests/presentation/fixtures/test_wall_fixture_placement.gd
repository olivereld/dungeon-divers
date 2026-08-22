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
	print("--- Running test_wall_fixture_placement ---")
	print("==================================================================")

	var cfg := DungeonConfigScript.new()
	cfg.seed = 987654
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

		for d in directives:
			if d.placement_mode == FixturePlacementModeScript.Mode.WALL:
				# 1. Verificar celda de muro válida
				assert(r_geom.wall_cells.has(d.cell), "FAIL: Wall fixture not placed on room wall cell")

				# 2. Verificar orientación y normal correcta
				assert(d.wall_side >= 0 and d.wall_side <= 3, "FAIL: Invalid wall side")
				match d.wall_side:
					0: # NORTH
						assert(is_equal_approx(d.rotation_y, 0.0), "FAIL: NORTH rotation must be 0.0")
						assert(d.placement.normal.is_equal_approx(Vector3(0, 0, 1)), "FAIL: NORTH normal mismatch")
					1: # EAST
						assert(is_equal_approx(d.rotation_y, PI * 0.5), "FAIL: EAST rotation must be PI/2")
						assert(d.placement.normal.is_equal_approx(Vector3(-1, 0, 0)), "FAIL: EAST normal mismatch")
					2: # SOUTH
						assert(is_equal_approx(d.rotation_y, PI), "FAIL: SOUTH rotation must be PI")
						assert(d.placement.normal.is_equal_approx(Vector3(0, 0, -1)), "FAIL: SOUTH normal mismatch")
					3: # WEST
						assert(is_equal_approx(d.rotation_y, -PI * 0.5), "FAIL: WEST rotation must be -PI/2")
						assert(d.placement.normal.is_equal_approx(Vector3(1, 0, 0)), "FAIL: WEST normal mismatch")

				# 3. Verificar que no solapa con puertas ni con su despeje
				for door_pos in r_geom.door_positions:
					assert(d.cell != door_pos, "FAIL: Wall fixture placed on door")
					var dist = abs(d.cell.x - door_pos.x) + abs(d.cell.y - door_pos.y)
					assert(dist > 1, "FAIL: Wall fixture placed within door clearance zone")

	print("  [OK] Wall fixtures: valid wall, correct side, correct normal, correct rotation, no door overlap, deterministic.")
	print("[PASS] test_wall_fixture_placement completed successfully!")
	quit(0)
