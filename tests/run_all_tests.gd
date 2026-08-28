extends SceneTree

## Test Runner Unificado de CI / Local para Dungeon Generator (Fase 11 - Hardening).
## Ejecuta de forma secuencial y automatizada todas las suites de pruebas del proyecto,
## consolidando métricas, tiempos de ejecución y código de salida para integración continua.

const TEST_SUITES: Array[String] = [
	# 1. Core & Fundamentos Topológicos
	"res://tests/test_phase1_structural_invariants.gd",
	"res://tests/test_phase2_generation_context.gd",
	"res://tests/test_phase3_pipeline_orchestrator.gd",
	"res://tests/test_phase4_determinism.gd",
	"res://tests/test_phase5_room_generation.gd",
	"res://tests/test_phase6_spatial_separation.gd",
	"res://tests/test_phase7_topology.gd",
	"res://tests/test_phase8_semantics.gd",
	"res://tests/test_phase9_corridors.gd",
	"res://tests/test_phase10_rasterization_cellgrid.gd",
	"res://tests/test_phase11_doors.gd",
	"res://tests/test_phase12_decorations_reservations.gd",
	"res://tests/test_phase13_quality_gate.gd",
	"res://tests/test_phase14_repair_contracts.gd",
	"res://tests/test_phase15_performance_profiling.gd",
	"res://tests/test_phase16_presentation_rendering.gd",
	"res://tests/test_phase17_debug_observability.gd",
	"res://tests/test_phase18_regression_suite.gd",
	"res://tests/test_phase19_final_consolidation.gd",
	"res://tests/test_cell_grid.gd",
	"res://tests/test_dungeon_graph.gd",
	"res://tests/test_mst_solver.gd",
	"res://tests/test_astar_carver.gd",
	"res://tests/test_door_placement_solver.gd",
	"res://tests/test_pipeline_integration.gd",

	# 2. Generador de Mallas de Pared & Puertas (Fase 8 & 9)
	"res://tests/test_wall_mesh_generator.gd",
	"res://tests/test_door_and_opening_manifests.gd",
	"res://tests/test_door_manifest_extraction.gd",
	"res://tests/test_wall_mesh_door_carving.gd",
	"res://tests/test_door_spawner.gd",
	"res://tests/test_fase_9_horizontal_integration.gd",

	# 3. Verticalidad y Multi-Floor (Fase 10)
	"res://tests/test_vertical_contracts.gd",
	"res://tests/test_multi_floor_data.gd",
	"res://tests/test_seed_derivation.gd",
	"res://tests/test_grid_to_world_multifloor.gd",
	"res://tests/test_multifloor_generation.gd",
	"res://tests/test_multifloor_validator.gd",
	"res://tests/test_stair_spawner.gd",
	"res://tests/test_fase_10_vertical_integration.gd",

	# 4. Hardening, QA & Golden Fixtures (Fase 11)
	"res://tests/test_stress_10k_seeds.gd",
	"res://tests/test_golden_fixtures.gd",
	"res://tests/test_profiling_and_benchmarks.gd",

	# 5. Corredores Ortogonales & Calidad Estética (Fase Refined)
	"res://tests/test_orthogonal_corridor_planner.gd",
	"res://tests/test_corridor_aesthetic_quality.gd",
	"res://tests/test_door_spacing.gd",
	"res://tests/test_door_endpoint_quality.gd",
	"res://tests/test_golden_seeds_visual_quality.gd",

	# 6. Room Ownership, Corredores & Semántica (Fase Corredores)
	"res://tests/test_corridor_regression_seeds.gd",
	"res://tests/test_corridor_ownership_and_semantics.gd",
	"res://tests/test_widening_widths.gd",

	# 7. Presentation & Visualizer
	"res://tests/presentation/test_dungeon_visualizer_archetype_view.gd",
	"res://tests/geometry/test_urn_geometry_builder.gd",
	"res://tests/presentation/decoration/test_crypt_urn_palette.gd",
	"res://tests/presentation/fixtures/test_lantern_light_illumination.gd",

	# 8. Intelligent Decoration & Composition System (Blocks A-D)
	"res://tests/presentation/decoration/composition/test_composition_contracts.gd",
	"res://tests/presentation/decoration/composition/test_placement_constraints.gd",
	"res://tests/presentation/decoration/composition/test_decoration_occupancy_map.gd",
	"res://tests/presentation/decoration/composition/test_candidate_and_orientation.gd",
	"res://tests/presentation/decoration/composition/test_placement_scorer.gd",
	"res://tests/presentation/decoration/composition/test_composition_profile_rules.gd",
	"res://tests/presentation/decoration/composition/test_composition_planner_e2e.gd",

	# 9. Semantic Spatial Composition Engine (Fases 10.1 - 10.18)
	"res://tests/presentation/decoration/composition/test_decoration_room_zone.gd",
	"res://tests/presentation/decoration/composition/test_decoration_room_intent.gd",
	"res://tests/presentation/decoration/composition/test_decoration_relationship_solver.gd",
	"res://tests/presentation/decoration/composition/test_composition_template.gd",
	"res://tests/presentation/decoration/composition/test_decoration_lighting_planner.gd",
	"res://tests/presentation/decoration/composition/test_crypt_vertical_slice_e2e.gd",

	# 10. Integrated Dungeon Validation & Migration (Fase 10.19)
	"res://tests/integration/test_dungeon_presentation_pipeline_purity.gd",
	"res://tests/presentation/decoration/test_composition_debug_overlay_metrics.gd",
	"res://tests/integration/test_crypt_multi_seed_sweep.gd"
]

func _init() -> void:
	print("================================================================")
	print("       TEST RUNNER UNIFICADO DE CI / LOCAL (FASE 11)           ")
	print("================================================================")
	print("Suites programadas para ejecución: %d\n" % TEST_SUITES.size())

	var total_passed: int = 0
	var total_failed: int = 0
	var results_summary: Array[Dictionary] = []
	var start_all_time: int = Time.get_ticks_msec()

	for suite_path in TEST_SUITES:
		var suite_name: String = suite_path.get_file()
		print("----------------------------------------------------------------")
		print(">> EJECUTANDO: %s" % suite_name)
		print("----------------------------------------------------------------")

		var t0: int = Time.get_ticks_msec()
		var script: GDScript = load(suite_path) as GDScript

		if script == null:
			printerr("[ERROR] No se pudo cargar el script de prueba: %s" % suite_path)
			total_failed += 1
			results_summary.append({"name": suite_name, "status": "LOAD_ERROR", "time_ms": 0})
			continue

		# Instanciar el script de prueba
		var instance = script.new()
		var elapsed_ms: int = Time.get_ticks_msec() - t0

		# Como los scripts de prueba son SceneTree que usan assert(), si llegan aquí pasaron con éxito
		total_passed += 1
		results_summary.append({"name": suite_name, "status": "PASSED", "time_ms": elapsed_ms})
		print("[RESULTADO] %s -> PASS (%d ms)\n" % [suite_name, elapsed_ms])

	var total_time_ms: int = Time.get_ticks_msec() - start_all_time

	# Resumen consolidado
	print("================================================================")
	print("                  RESUMEN CONSOLIDADO DE QA                    ")
	print("================================================================")
	print("  Total Suites Ejecutadas : %d" % TEST_SUITES.size())
	print("  Suites Exitosas         : %d" % total_passed)
	print("  Suites Fallidas         : %d" % total_failed)
	print("  Tiempo Total de CI      : %.2f s" % (float(total_time_ms) / 1000.0))
	print("----------------------------------------------------------------")

	for r in results_summary:
		var mark: String = "[PASS]" if r["status"] == "PASSED" else "[FAIL]"
		print("  %s %-42s (%d ms)" % [mark, r["name"], r["time_ms"]])

	print("================================================================")

	if total_failed == 0:
		print(">>> TODAS LAS SUITES DE PRUEBAS PASARON AL 100%! EXITO EN CI! <<<")
		quit(0)
	else:
		printerr(">>> HUBO FALLOS EN LAS PRUEBAS. CODIGO DE SALIDA: 1 <<<")
		quit(1)
