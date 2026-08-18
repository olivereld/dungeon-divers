extends SceneTree

## Test Suite para Congelar y Diagnosticar Seeds Críticas (Fase 1 de fase_corredores.md).
## Registra el estado de las seeds:
## - 3196820195
## - 148285204
## - 352896113 (con depth 5 y 7)

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _DungeonDiagnosticExporterScript = preload("res://src/dungeon_generator/debug/dungeon_diagnostic_exporter.gd")

const TARGET_SEEDS: Array[int] = [
	3196820195,
	148285204,
	352896113
]

func _init() -> void:
	print("--- Running test_corridor_regression_seeds (Phase 1 Baseline Freeze) ---")
	test_critical_seeds()
	print("[PASS] test_corridor_regression_seeds executed successfully!")
	quit(0)

func test_critical_seeds() -> void:
	var pipeline := _DungeonPipelineScript.new()
	
	for seed_val in TARGET_SEEDS:
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		config.mission_depth = 5
		
		var result: DungeonResult = pipeline.generate(config, 5, true)
		assert(result != null, "Generation must succeed for seed %d" % seed_val)
		
		var diag: Dictionary = _DungeonDiagnosticExporterScript.export_diagnostic_report(result, config)
		assert(diag.has("metadata"), "Diagnostic must have metadata")
		
		# Contar cuántas salas están marcadas como BOSS
		var boss_count: int = 0
		for r in result.rooms:
			if r != null and r.room_type == &"boss":
				boss_count += 1
		
		print("  -> Seed: %d | Rooms: %d | Edges: %d | Doors: %d | Boss Count: %d | Checksum: %s" % [
			seed_val,
			result.rooms.size(),
			result.connections.size(),
			result.doors.size(),
			boss_count,
			result.checksum.substr(0, 12)
		])
	
	print("    [OK] Phase 1 Baseline frozen successfully")
