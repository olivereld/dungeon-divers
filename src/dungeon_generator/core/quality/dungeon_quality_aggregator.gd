class_name DungeonQualityAggregator
extends RefCounted

## Agregador y ejecutor de benchmark de calidad para lotes multi-seed.
## Calcula las tasas agregadas de fiabilidad (D4: semantic_valid_rate, gameplay_valid_rate)
## y promedios consolidados de calidad (D1, D2, D3) sobre mazmorras validadas.

const _DungeonQualityReportScript = preload("res://src/dungeon_generator/core/quality/data/dungeon_quality_report.gd")
const _DungeonQualityAnalyzerScript = preload("res://src/dungeon_generator/core/quality/dungeon_quality_analyzer.gd")
const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _SemanticOrchestratorScript = preload("res://src/dungeon_generator/core/semantic/semantic_orchestrator.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")

var _pipeline: DungeonPipeline
var _semantic_orchestrator: SemanticOrchestrator
var _analyzer: _DungeonQualityAnalyzerScript

func _init() -> void:
	_pipeline = _DungeonPipelineScript.new()
	_semantic_orchestrator = _SemanticOrchestratorScript.new()
	_analyzer = _DungeonQualityAnalyzerScript.new()

## Ejecuta un benchmark sobre una lista de seeds y devuelve el reporte agregado.
func run_benchmark(seeds: Array[int], config_template: DungeonConfig = null) -> Dictionary:
	var reports: Array[_DungeonQualityReportScript] = []

	for s in seeds:
		var cfg: DungeonConfig
		if config_template != null:
			cfg = config_template.duplicate()
		else:
			cfg = _DungeonConfigScript.new()

		cfg.seed = s
		cfg.use_fixed_seed = true

		var d_res: DungeonResult = _pipeline.generate(cfg)
		if d_res == null:
			var fail_report := _DungeonQualityReportScript.new()
			fail_report.set_seed_val(s)
			fail_report.set_validity(false, false)
			fail_report.seal()
			reports.append(fail_report)
			continue

		var sem_res = _semantic_orchestrator.generate_semantics(d_res, cfg)
		var report := _analyzer.analyze(d_res, sem_res, cfg)
		reports.append(report)

	return aggregate_reports(reports)

## Agrega un array de DungeonQualityReport previamente generados.
func aggregate_reports(reports: Array) -> Dictionary:
	var n: int = reports.size()
	if n == 0:
		return {
			"total_evaluated": 0,
			"semantic_valid_count": 0,
			"semantic_valid_rate": 0.0,
			"gameplay_valid_count": 0,
			"gameplay_valid_rate": 0.0,
			"valid_samples_count": 0
		}

	var sem_valid_count: int = 0
	var game_valid_count: int = 0
	var fully_valid_count: int = 0

	# Acumuladores de D1 (Rooms)
	var sum_room_fill_ratio: float = 0.0
	var sum_nearest_neighbor_cv: float = 0.0
	var sum_radial_variance: float = 0.0
	var sum_edge_stretch: float = 0.0

	# Acumuladores de D2 (Corridors)
	var sum_corridor_mean_len: float = 0.0
	var sum_corridor_len_var: float = 0.0
	var sum_short_corridor_rate: float = 0.0
	var sum_corridor_mean_turns: float = 0.0
	var sum_longest_straight_run: float = 0.0

	# Acumuladores de D3 (Gameplay)
	var sum_crit_path_length: float = 0.0
	var sum_crit_path_rooms: float = 0.0
	var sum_obj_spacing: float = 0.0
	var sum_key_lock_spacing: float = 0.0
	var sum_start_boss_dist: float = 0.0
	var sum_start_goal_dist: float = 0.0
	var sum_branch_count: float = 0.0
	var sum_branch_depth: float = 0.0

	for r in reports:
		if r == null:
			continue

		if r.semantic_valid:
			sem_valid_count += 1
		if r.gameplay_valid:
			game_valid_count += 1

		# Solo acumulamos métricas D1-D3 si la muestra superó ambos filtros obligatorios D4
		if r.semantic_valid and r.gameplay_valid:
			fully_valid_count += 1

			# D1
			sum_room_fill_ratio += float(r.room_metrics.get("room_fill_ratio", 0.0))
			sum_nearest_neighbor_cv += float(r.room_metrics.get("nearest_neighbor_cv", 0.0))
			sum_radial_variance += float(r.room_metrics.get("radial_variance", 0.0))
			sum_edge_stretch += float(r.room_metrics.get("edge_stretch", 0.0))

			# D2
			var c_stats = r.corridor_metrics.get("length_stats", {})
			sum_corridor_mean_len += float(c_stats.get("mean", 0.0))
			sum_corridor_len_var += float(r.corridor_metrics.get("length_variance", 0.0))
			sum_short_corridor_rate += float(r.corridor_metrics.get("short_corridor_rate", 0.0))
			var t_stats = r.corridor_metrics.get("turn_count_stats", {})
			sum_corridor_mean_turns += float(t_stats.get("mean", 0.0))
			sum_longest_straight_run += float(r.corridor_metrics.get("longest_straight_run", 0))

			# D3
			sum_crit_path_length += float(r.gameplay_metrics.get("critical_path_length", 0.0))
			sum_crit_path_rooms += float(r.gameplay_metrics.get("critical_path_room_count", 0))
			sum_obj_spacing += float(r.gameplay_metrics.get("objective_spacing", 0.0))
			sum_key_lock_spacing += float(r.gameplay_metrics.get("key_lock_spacing", 0.0))
			sum_start_boss_dist += float(r.gameplay_metrics.get("start_boss_distance", 0.0))
			sum_start_goal_dist += float(r.gameplay_metrics.get("start_goal_distance", 0.0))
			sum_branch_count += float(r.gameplay_metrics.get("branch_count", 0))
			sum_branch_depth += float(r.gameplay_metrics.get("optional_branch_depth", 0.0))

	var v_denom: float = float(fully_valid_count) if fully_valid_count > 0 else 1.0

	return {
		# D4 — Fiabilidad
		"total_evaluated": n,
		"semantic_valid_count": sem_valid_count,
		"semantic_valid_rate": roundf((float(sem_valid_count) / float(n)) * 10000.0) / 10000.0,
		"gameplay_valid_count": game_valid_count,
		"gameplay_valid_rate": roundf((float(game_valid_count) / float(n)) * 10000.0) / 10000.0,
		"fully_valid_count": fully_valid_count,
		"fully_valid_rate": roundf((float(fully_valid_count) / float(n)) * 10000.0) / 10000.0,

		# Promedios D1 — Rooms
		"avg_room_fill_ratio": roundf((sum_room_fill_ratio / v_denom) * 10000.0) / 10000.0 if fully_valid_count > 0 else 0.0,
		"avg_nearest_neighbor_cv": roundf((sum_nearest_neighbor_cv / v_denom) * 10000.0) / 10000.0 if fully_valid_count > 0 else 0.0,
		"avg_radial_variance": roundf((sum_radial_variance / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_edge_stretch": roundf((sum_edge_stretch / v_denom) * 10000.0) / 10000.0 if fully_valid_count > 0 else 0.0,

		# Promedios D2 — Corridors
		"avg_corridor_length": roundf((sum_corridor_mean_len / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_corridor_length_variance": roundf((sum_corridor_len_var / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_short_corridor_rate": roundf((sum_short_corridor_rate / v_denom) * 10000.0) / 10000.0 if fully_valid_count > 0 else 0.0,
		"avg_corridor_turns": roundf((sum_corridor_mean_turns / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_longest_straight_run": roundf((sum_longest_straight_run / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,

		# Promedios D3 — Gameplay
		"avg_critical_path_length": roundf((sum_crit_path_length / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_critical_path_room_count": roundf((sum_crit_path_rooms / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_objective_spacing": roundf((sum_obj_spacing / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_key_lock_spacing": roundf((sum_key_lock_spacing / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_start_boss_distance": roundf((sum_start_boss_dist / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_start_goal_distance": roundf((sum_start_goal_dist / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_branch_count": roundf((sum_branch_count / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0,
		"avg_optional_branch_depth": roundf((sum_branch_depth / v_denom) * 100.0) / 100.0 if fully_valid_count > 0 else 0.0
	}
