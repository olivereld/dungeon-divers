class_name DungeonValidationStage
extends RefCounted

## Etapa 8: Validación de Conectividad (FloodFill) y Evaluación de Calidad (Fitness).

const _FloodFillScript = preload("res://src/dungeon_generator/core/algorithms/flood_fill.gd")
const _FitnessEvaluatorScript = preload("res://src/dungeon_generator/core/solvers/fitness_evaluator.gd")

var _flood_fill := _FloodFillScript.new()
var _fitness_evaluator := _FitnessEvaluatorScript.new()

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	var path_ok: bool = _flood_fill.verify_critical_path(ctx.grid) and _flood_fill.verify_100_percent_walkable_connected(ctx.grid)
	ctx.record_timing("flood_fill_connectivity", float(Time.get_ticks_msec() - t0))

	if not path_ok:
		var diag := _flood_fill.get_connectivity_diagnostics(ctx.grid, ctx.rooms)
		push_warning("[DungeonValidationStage] Attempt %d: FloodFill connectivity check failed (Found %d regions, %d isolated islands: %s)." % [
			ctx.attempt,
			diag.get("region_count", 0),
			diag.get("isolated_regions_count", 0),
			str(diag.get("isolated_regions", []))
		])
		ctx.mark_attempt_failed("FLOOD_FILL_CONNECTIVITY_FAILED")
		return false

	ctx.fitness_score = _fitness_evaluator.evaluate(ctx.grid, ctx.rooms, ctx.config)
	ctx.metrics["aesthetic_metrics"] = _compute_aesthetic_metrics(ctx.corridor_paths, ctx.doors)
	return true

func _compute_aesthetic_metrics(corridors: Array, doors: Array) -> Dictionary:
	var total_turns: int = 0
	var zero_turns: int = 0
	var one_turns: int = 0
	var two_turns: int = 0
	var multi_turns: int = 0
	var strategy_counts: Dictionary = {}

	for p in corridors:
		if p != null:
			var t: int = p.turn_count if ("turn_count" in p) else 0
			total_turns += t
			match t:
				0:
					zero_turns += 1
				1:
					one_turns += 1
				2:
					two_turns += 1
				_:
					multi_turns += 1

			var strat: String = str(p.routing_strategy) if ("routing_strategy" in p) else "Unknown"
			strategy_counts[strat] = strategy_counts.get(strat, 0) + 1

	var c_count: int = corridors.size()
	var avg_turns: float = float(total_turns) / float(c_count) if c_count > 0 else 0.0

	var min_door_dist: int = 999
	for i in range(doors.size()):
		for j in range(i + 1, doors.size()):
			var da = doors[i]
			var db = doors[j]
			if da != null and db != null:
				var m_dist: int = absi(da.position.x - db.position.x) + absi(da.position.y - db.position.y)
				if m_dist < min_door_dist:
					min_door_dist = m_dist

	if min_door_dist == 999:
		min_door_dist = 0

	return {
		"corridor_count": c_count,
		"total_turns": total_turns,
		"average_turns_per_corridor": avg_turns,
		"percent_zero_turn": (float(zero_turns) / float(c_count) * 100.0) if c_count > 0 else 0.0,
		"percent_one_turn": (float(one_turns) / float(c_count) * 100.0) if c_count > 0 else 0.0,
		"percent_two_turn": (float(two_turns) / float(c_count) * 100.0) if c_count > 0 else 0.0,
		"percent_multi_turn": (float(multi_turns) / float(c_count) * 100.0) if c_count > 0 else 0.0,
		"routing_strategies": strategy_counts,
		"door_count": doors.size(),
		"min_door_distance": min_door_dist,
		"staircase_corridors": 0
	}
