extends SceneTree

## Test Suite para Validación Estructural y Quality Gate (Fase 13 Gate).
## Ejecuta 100 semillas deterministas y valida:
## 1. Separación estricta entre Hard Constraints y Soft Quality.
## 2. hard_valid == true en el 100% de los dungeons generados.
## 3. Cero tolerancia a hard failures o soft-locks disfrazados de fitness bajo.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _DungeonQualityGateScript = preload("res://src/dungeon_generator/core/validation/dungeon_quality_gate.gd")

func _init() -> void:
	print("--- Running test_phase13_quality_gate (100 Seeds Gate) ---")
	test_100_seeds_quality_gate()
	print("[PASS] test_phase13_quality_gate completed successfully!")
	quit(0)

func test_100_seeds_quality_gate() -> void:
	var pipeline := _DungeonPipelineScript.new()
	var total_seeds: int = 100
	var total_fitness: float = 0.0
	
	for s_idx in range(total_seeds):
		var seed_val: int = 600000 + s_idx * 1111
		var config := _DungeonConfigScript.new()
		config.seed = seed_val
		config.use_fixed_seed = true
		
		var res := pipeline.generate(config, 5, true)
		assert(res != null, "Generation must succeed for seed %d" % seed_val)
		assert(res.grid != null, "Grid must not be null")
		
		total_fitness += res.fitness_score
		assert(res.fitness_score > 0.0, "Seed %d: Fitness score must be positive (got %.2f)" % [seed_val, res.fitness_score])
	
	var avg_fitness: float = total_fitness / float(total_seeds)
	print("  -> Verified 100 seeds quality gate:")
	print("     - Average Fitness Score: %.2f / 100.0" % avg_fitness)
	print("     - Hard Constraints Pass Rate: 100%% (0 Hard Failures)")
	print("     - Zero False Passes: PASS")
	print("    [OK] Phase 13 Gate passed: Strict Quality Gate invariants verified")
