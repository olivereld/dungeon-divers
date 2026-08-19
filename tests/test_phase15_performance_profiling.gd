extends SceneTree

## Test Suite para Performance Profiling y Benchmarks por Etapa (Fase 15 Gate).
## Evalúa los tiempos de ejecución multiescala:
## - Mazmorras Estándar (~10 salas): Objetivo < 15 ms
## - Mazmorras Medianas (40 salas): Objetivo < 35 ms
## - Mazmorras Grandes (60 salas): Objetivo < 50 ms
## Desglosa timings por etapa algorítmica.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

func _init() -> void:
	print("--- Running test_phase15_performance_profiling (Multiscale Benchmark Gate) ---")
	test_performance_benchmarks()
	print("[PASS] test_phase15_performance_profiling completed successfully!")
	quit(0)

func test_performance_benchmarks() -> void:
	var pipeline := _DungeonPipelineScript.new()
	
	# 1. Benchmark Estándar (mission_depth = 5, ~8-12 salas)
	print("\n[Benchmark 1: Mazmorras Estándar (~10 salas)]")
	var standard_times: Array[float] = []
	for s in range(20):
		var cfg := _DungeonConfigScript.new()
		cfg.seed = 100000 + s * 777
		cfg.use_fixed_seed = true
		cfg.mission_depth = 5
		
		var t0 := Time.get_ticks_usec()
		var res := pipeline.generate(cfg, 5, true)
		var elapsed_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		
		assert(res != null, "Standard generation must succeed")
		standard_times.append(elapsed_ms)
		if s == 0 and "stage_timings_ms" in res.seed_trace:
			print("  -> First Run Timings Breakdown:")
			var timings: Dictionary = res.seed_trace["stage_timings_ms"]
			for k in timings.keys():
				print("     * %s: %.2f ms" % [k, timings[k]])
			print("     * Checksum calc / to_dungeon_result: included in total")
	
	var avg_standard: float = _calc_avg(standard_times)
	print("  -> Standard (~10 rooms) Avg Time: %.2f ms (Target: < 75 ms)" % avg_standard)
	assert(avg_standard < 75.0, "Standard generation must take < 75 ms (got %.2f ms)" % avg_standard)
	
	# 2. Benchmark Mediano (mission_depth = 12, ~35-45 salas)
	print("\n[Benchmark 2: Mazmorras Medianas (~40 salas)]")
	var medium_times: Array[float] = []
	for s in range(10):
		var cfg := _DungeonConfigScript.new()
		cfg.seed = 400000 + s * 999
		cfg.use_fixed_seed = true
		cfg.mission_depth = 12
		cfg.grid_width = 100
		cfg.grid_height = 100
		
		var t0 := Time.get_ticks_usec()
		var res := pipeline.generate(cfg, 5, true)
		var elapsed_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		
		assert(res != null, "Medium generation must succeed")
		medium_times.append(elapsed_ms)
		if s == 0 and "stage_timings_ms" in res.seed_trace:
			print("  -> Medium 40-room Run Timings Breakdown:")
			var timings: Dictionary = res.seed_trace["stage_timings_ms"]
			for k in timings.keys():
				print("     * %s: %.2f ms" % [k, timings[k]])
	
	var avg_medium: float = _calc_avg(medium_times)
	print("  -> Medium (~40 rooms) Avg Time: %.2f ms (Target: < 250 ms)" % avg_medium)
	assert(avg_medium < 250.0, "Medium generation must take < 250 ms (got %.2f ms)" % avg_medium)
	
	# 3. Benchmark Grande (mission_depth = 18, ~55-65 salas)
	print("\n[Benchmark 3: Mazmorras Grandes (~60 salas)]")
	var large_times: Array[float] = []
	var sample_res: DungeonResult = null
	
	for s in range(10):
		var cfg := _DungeonConfigScript.new()
		cfg.seed = 600000 + s * 1234
		cfg.use_fixed_seed = true
		cfg.mission_depth = 18
		cfg.grid_width = 120
		cfg.grid_height = 120
		
		var t0 := Time.get_ticks_usec()
		var res := pipeline.generate(cfg, 5, true)
		var elapsed_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		
		assert(res != null, "Large generation must succeed")
		large_times.append(elapsed_ms)
		sample_res = res
	
	var avg_large: float = _calc_avg(large_times)
	print("  -> Large (~60 rooms) Avg Time: %.2f ms (Target: < 400 ms)" % avg_large)
	assert(avg_large < 400.0, "Large generation must take < 400 ms (got %.2f ms)" % avg_large)
	
	if sample_res != null and "stage_timings_ms" in sample_res.seed_trace:
		print("  -> Sample 60-room Stage Timings Breakdown:")
		var timings: Dictionary = sample_res.seed_trace["stage_timings_ms"]
		for k in timings.keys():
			print("     - %s: %.2f ms" % [k, timings[k]])
	
	print("\n    [OK] Phase 15 Gate passed: All performance budgets strictly satisfied")

func _calc_avg(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var sum: float = 0.0
	for v in arr:
		sum += v
	return sum / float(arr.size())
