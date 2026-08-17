class_name TestPipelineResilience
extends SceneTree

## Suite de pruebas de resiliencia y determinismo del pipeline (Fase 6.1.1).

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _FloodFillScript = preload("res://src/dungeon_generator/core/algorithms/flood_fill.gd")

func _init() -> void:
	print("\n--- Running test_pipeline_resilience ---")

	test_seed_12345_deterministic_and_valid()
	test_seed_trace_structure_and_hierarchy()
	test_all_presets_resilience()

	print("--- All test_pipeline_resilience tests passed successfully! ---\n")
	quit(0)

func test_seed_12345_deterministic_and_valid() -> void:
	var pipeline = _DungeonPipelineScript.new()
	var config := DungeonConfig.new()
	config.seed = 12345
	config.use_fixed_seed = true
	config.algorithm = "Hybrid"

	# Ejecución 1
	var res1: DungeonResult = pipeline.generate(config, 5, false)
	assert(res1 != null, "Generation for seed 12345 must produce a valid result")
	assert(res1.seed_used == 12345, "seed_used must match base_seed (12345)")

	# Validación de conectividad al 100%
	var flood_fill = _FloodFillScript.new()
	var is_100_connected: bool = flood_fill.verify_100_percent_walkable_connected(res1.grid)
	assert(is_100_connected, "Dungeon generated for seed 12345 must have 100% connected walkable cells")

	# Ejecución 2 (Determinismo)
	var pipeline2 = _DungeonPipelineScript.new()
	var res2: DungeonResult = pipeline2.generate(config, 5, false)
	assert(res2 != null, "Second generation must produce a valid result")
	assert(res1.seed_used == res2.seed_used, "Base seed must match")
	assert(res1.grid.to_debug_string() == res2.grid.to_debug_string(), "Grid output for seed 12345 must be 100% deterministic")

	print("  [OK] Test 1: Seed 12345 generates a 100% connected, valid and deterministic dungeon")

func test_seed_trace_structure_and_hierarchy() -> void:
	var pipeline = _DungeonPipelineScript.new()
	var config := DungeonConfig.new()
	config.seed = 54321
	config.use_fixed_seed = true

	var res: DungeonResult = pipeline.generate(config, 5, false)
	assert(res != null, "Generation must succeed")
	assert(not res.seed_trace.is_empty(), "seed_trace must not be empty")

	assert(res.seed_trace.has("base_seed"), "seed_trace must contain 'base_seed'")
	assert(res.seed_trace["base_seed"] == 54321, "base_seed must be 54321")

	assert(res.seed_trace.has("attempt"), "seed_trace must contain 'attempt'")
	assert(res.seed_trace.has("attempt_seed"), "seed_trace must contain 'attempt_seed'")
	assert(res.seed_trace.has("repair_seed_chain"), "seed_trace must contain 'repair_seed_chain'")
	assert(res.seed_trace["repair_seed_chain"] is Array, "repair_seed_chain must be an Array")

	# Si se ejecutaron reparaciones, comprobar la estructura de cada entrada
	for rep in res.seed_trace["repair_seed_chain"]:
		assert(rep.has("stage"), "Repair trace item must have 'stage'")
		assert(rep.has("attempt"), "Repair trace item must have 'attempt'")
		assert(rep.has("seed"), "Repair trace item must have 'seed'")
		assert(rep["seed"] is int, "Repair seed must be an integer")
		assert(rep.has("success"), "Repair trace item must have 'success'")

	print("  [OK] Test 2: DungeonResult.seed_trace contract correctly records seed hierarchy")

func test_all_presets_resilience() -> void:
	var pipeline = _DungeonPipelineScript.new()
	var flood_fill = _FloodFillScript.new()

	var presets := [
		"res://resources/configs/hybrid_dungeon.tres",
		"res://resources/configs/cave_dungeon.tres",
		"res://resources/configs/castle_dungeon.tres",
		"res://resources/configs/dungeon_128.tres"
	]

	var test_seeds := [100, 202, 303, 404]

	for preset_path in presets:
		var cfg: DungeonConfig = load(preset_path).duplicate()
		for s in test_seeds:
			cfg.seed = s
			cfg.use_fixed_seed = true

			var res: DungeonResult = pipeline.generate(cfg, 5, false)
			assert(res != null, "Generation must succeed for preset '%s' with seed %d" % [preset_path, s])
			var conn_ok: bool = flood_fill.verify_100_percent_walkable_connected(res.grid)
			assert(conn_ok, "100%% walkable cells must be connected for '%s' (seed %d)" % [preset_path, s])

	print("  [OK] Test 3: All 4 presets succeed with 100% connectivity across multiple seeds")
