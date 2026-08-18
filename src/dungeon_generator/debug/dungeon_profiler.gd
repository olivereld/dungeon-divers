class_name DungeonProfiler
extends RefCounted

## Módulo de Profiling y Benchmarking Formal para la Fase 11 (Hardening).
## Mide con precisión microsegundo cada etapa del pipeline de generación y presentación,
## evaluando tiempos por etapa, uso de memoria y cumplimiento de presupuestos de latencia.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _MultiFloorGeneratorScript = preload("res://src/dungeon_generator/core/multi_floor_generator.gd")
const _ContinuousWallMeshBuilderScript = preload("res://src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd")
const _WallMeshConfigScript = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
const _DoorManifestFactoryScript = preload("res://src/dungeon_generator/core/data/door_manifest_factory.gd")

class BenchmarkResult:
	var grid_size: int = 32
	var iterations: int = 100
	var core_p50_ms: float = 0.0
	var core_p95_ms: float = 0.0
	var core_max_ms: float = 0.0
	var wall_mesh_p50_ms: float = 0.0
	var wall_mesh_p95_ms: float = 0.0
	var wall_mesh_max_ms: float = 0.0
	var total_p50_ms: float = 0.0
	var total_p95_ms: float = 0.0
	var total_max_ms: float = 0.0
	var budget_p95_limit_ms: float = 20.0
	var passed_budget: bool = false

## Ejecuta un benchmark completo para un tamaño de rejilla dado.
func benchmark_grid_size(grid_size: int, iterations: int = 100, p95_budget_ms: float = 20.0) -> BenchmarkResult:
	var res := BenchmarkResult.new()
	res.grid_size = grid_size
	res.iterations = iterations
	res.budget_p95_limit_ms = p95_budget_ms

	var pipeline := _DungeonPipelineScript.new()
	var wall_builder := _ContinuousWallMeshBuilderScript.new()

	var core_times: Array[float] = []
	var wall_times: Array[float] = []
	var total_times: Array[float] = []

	for i in range(iterations):
		var cfg := DungeonConfig.new()
		cfg.grid_width = grid_size
		cfg.grid_height = grid_size
		cfg.mission_depth = 4
		cfg.seed = 300000 + i
		cfg.use_fixed_seed = true

		# 1. Medir Core Pipeline
		var t0: int = Time.get_ticks_usec()
		var d_res: DungeonResult = pipeline.generate(cfg)
		var t1: int = Time.get_ticks_usec()

		var core_ms: float = float(t1 - t0) / 1000.0
		core_times.append(core_ms)

		# 2. Medir Malla Continua de Paredes
		var wall_ms: float = 0.0
		if d_res != null and d_res.grid != null:
			var w_cfg := _WallMeshConfigScript.new()
			w_cfg.cube_size = 2.0
			w_cfg.cubes_high = 2
			w_cfg.seed = d_res.seed_used

			var open_manifest = null
			if d_res.door_pairs != null:
				open_manifest = _DoorManifestFactoryScript.create_wall_opening_manifest(d_res.door_pairs)

			var tw0: int = Time.get_ticks_usec()
			var wall_mesh: ArrayMesh = wall_builder.build_dungeon_wall_mesh(d_res.grid, w_cfg, 0, open_manifest)
			var tw1: int = Time.get_ticks_usec()
			wall_ms = float(tw1 - tw0) / 1000.0

		wall_times.append(wall_ms)
		total_times.append(core_ms + wall_ms)

	# Calcular percentiles
	res.core_p50_ms = _calc_percentile(core_times, 0.50)
	res.core_p95_ms = _calc_percentile(core_times, 0.95)
	res.core_max_ms = _calc_max(core_times)

	res.wall_mesh_p50_ms = _calc_percentile(wall_times, 0.50)
	res.wall_mesh_p95_ms = _calc_percentile(wall_times, 0.95)
	res.wall_mesh_max_ms = _calc_max(wall_times)

	res.total_p50_ms = _calc_percentile(total_times, 0.50)
	res.total_p95_ms = _calc_percentile(total_times, 0.95)
	res.total_max_ms = _calc_max(total_times)

	res.passed_budget = (res.total_p95_ms <= p95_budget_ms)
	return res

static func _calc_percentile(arr: Array[float], p: float) -> float:
	if arr.is_empty():
		return 0.0
	var copy: Array[float] = arr.duplicate()
	copy.sort()
	var idx: int = mini(copy.size() - 1, int(float(copy.size()) * p))
	return copy[idx]

static func _calc_max(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var max_val: float = arr[0]
	for v in arr:
		if v > max_val:
			max_val = v
	return max_val
