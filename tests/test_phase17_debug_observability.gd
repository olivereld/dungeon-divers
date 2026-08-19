extends SceneTree

## Test Suite para Debug y Observabilidad Forense (Fase 17 Gate).
## Valida en 50 semillas deterministas:
## 1. Integridad de reportes estructurados de diagnóstico (JSON/Dictionary).
## 2. Cobertura completa de capas: rooms, connections, doors, corridors, seed_trace, ascii.
## 3. Invariante de Reproducibilidad: seed + config reproduce exactamente el mismo checksum SHA-256.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _DungeonDiagnosticExporterScript = preload("res://src/dungeon_generator/debug/dungeon_diagnostic_exporter.gd")

func _init() -> void:
	print("--- Running test_phase17_debug_observability (50 Seeds Gate) ---")
	test_debug_observability_and_reproducibility()
	print("[PASS] test_phase17_debug_observability completed successfully!")
	quit(0)

func test_debug_observability_and_reproducibility() -> void:
	var pipeline := _DungeonPipelineScript.new()
	var total_seeds: int = 50
	
	for s_idx in range(total_seeds):
		var seed_val: int = 700000 + s_idx * 1414
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		config.mission_depth = 5
		
		# 1. Generación de Mazmorra
		var result: DungeonResult = pipeline.generate(config, 5, true)
		assert(result != null, "Generation must succeed for seed %d" % seed_val)
		
		# 2. Generación de Reporte de Diagnóstico
		var report: Dictionary = _DungeonDiagnosticExporterScript.export_diagnostic_report(result, config)
		assert(not report.has("error"), "Diagnostic report must not contain error")
		
		# 3. Validar integridad de capas requeridas por la Fase 17
		assert(report.has("metadata"), "Report must contain metadata")
		assert(report["metadata"]["seed"] == seed_val, "Metadata seed mismatch")
		assert(report["metadata"]["checksum"] == result.checksum, "Metadata checksum mismatch")
		
		assert(report.has("seed_trace"), "Report must contain seed_trace")
		assert(report["seed_trace"].has("stage_timings_ms"), "Seed trace must contain stage_timings_ms")
		
		assert(report.has("metrics"), "Report must contain metrics")
		assert(report["metrics"]["room_count"] == result.rooms.size(), "Metrics room count mismatch")
		assert(report["metrics"]["connection_count"] == result.connections.size(), "Metrics connection count mismatch")
		
		assert(report.has("rooms") and report["rooms"].size() == result.rooms.size(), "Rooms layer mismatch")
		assert(report.has("connections") and report["connections"].size() == result.connections.size(), "Connections layer mismatch")
		assert(report.has("doors") and report["doors"].size() == result.doors.size(), "Doors layer mismatch")
		assert(report.has("corridors") and report["corridors"].size() == result.corridor_paths.size(), "Corridors layer mismatch")
		assert(report.has("ascii_map") and not report["ascii_map"].is_empty(), "ASCII map must not be empty")
		
		# 4. Validar serialización JSON válida
		var json_str: String = _DungeonDiagnosticExporterScript.export_json_string(result, config)
		assert(not json_str.is_empty(), "JSON string must not be empty")
		var parsed_json = JSON.parse_string(json_str)
		assert(parsed_json is Dictionary, "JSON must parse cleanly to Dictionary")
		
		# 5. Gate de Reproducibilidad Exacta
		var repro_cfg := _DungeonConfigScript.new()
		repro_cfg.seed = report["metadata"]["seed"]
		repro_cfg.use_fixed_seed = true
		repro_cfg.mission_depth = 5
		
		var repro_result: DungeonResult = pipeline.generate(repro_cfg, 5, true)
		assert(repro_result != null, "Reproduced generation must succeed")
		assert(repro_result.checksum == result.checksum, "Reproduced dungeon checksum must be 100%% identical (Seed: %d)" % seed_val)
	
	print("  -> Analyzed 50 seeds diagnostic observability:")
	print("     - Full diagnostic layers coverage (Metadata, Trace, Rooms, Graph, Doors, Corridors, ASCII)")
	print("     - 100% JSON serialization clean validation")
	print("     - 100% Bit-exact reproducibility gate verified")
	print("    [OK] Phase 17 Gate passed: Debug and Observability strictly unified")
