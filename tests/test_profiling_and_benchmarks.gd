extends SceneTree

## Suite de pruebas de rendimiento y benchmarking para PR-11D: Profiling & Optimización.

func _init() -> void:
	print("================================================================")
	print("    EJECUTANDO BENCHMARK DE RENDIMIENTO FORMAL (FASE 11)       ")
	print("================================================================")

	var profiler_script = preload("res://src/dungeon_generator/debug/dungeon_profiler.gd")
	var profiler = profiler_script.new()

	# 1. Benchmark Rejilla Pequeña (32x32)
	print("\n--- Evaluando Grid 32x32 (Small) ---")
	var res_32 = profiler.benchmark_grid_size(32, 50, 25.0)
	print("  Core Pipeline    : P50 = %.2f ms | P95 = %.2f ms | Max = %.2f ms" % [res_32.core_p50_ms, res_32.core_p95_ms, res_32.core_max_ms])
	print("  Wall Mesh Extr   : P50 = %.2f ms | P95 = %.2f ms | Max = %.2f ms" % [res_32.wall_mesh_p50_ms, res_32.wall_mesh_p95_ms, res_32.wall_mesh_max_ms])
	print("  Total Combinado  : P50 = %.2f ms | P95 = %.2f ms | Max = %.2f ms (Presupuesto P95: %.1f ms)" % [res_32.total_p50_ms, res_32.total_p95_ms, res_32.total_max_ms, res_32.budget_p95_limit_ms])
	assert(res_32.passed_budget, "32x32 generation must pass P95 budget")

	# 2. Benchmark Rejilla Mediana (64x64)
	print("\n--- Evaluando Grid 64x64 (Medium) ---")
	var res_64 = profiler.benchmark_grid_size(64, 30, 45.0)
	print("  Core Pipeline    : P50 = %.2f ms | P95 = %.2f ms | Max = %.2f ms" % [res_64.core_p50_ms, res_64.core_p95_ms, res_64.core_max_ms])
	print("  Wall Mesh Extr   : P50 = %.2f ms | P95 = %.2f ms | Max = %.2f ms" % [res_64.wall_mesh_p50_ms, res_64.wall_mesh_p95_ms, res_64.wall_mesh_max_ms])
	print("  Total Combinado  : P50 = %.2f ms | P95 = %.2f ms | Max = %.2f ms (Presupuesto P95: %.1f ms)" % [res_64.total_p50_ms, res_64.total_p95_ms, res_64.total_max_ms, res_64.budget_p95_limit_ms])
	assert(res_64.passed_budget, "64x64 generation must pass P95 budget")

	print("\n>>> ALL PR-11D PROFILING AND BENCHMARK CHECKS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
