class_name DungeonValidationStage
extends RefCounted

## Etapa 8: Validación de Conectividad (FloodFill) y Evaluación de Calidad (Fitness).

const _DungeonDistanceFieldScript = preload("res://src/dungeon_generator/core/algorithms/dungeon_distance_field.gd")
const _DungeonQualityGateScript = preload("res://src/dungeon_generator/core/validation/dungeon_quality_gate.gd")

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()

	# 1. Calcular y almacenar el campo de distancias canónico (Single-pass BFS)
	var start_pos: Vector2i = Vector2i.ZERO
	var spawn_cells = ctx.grid.find_cells_of_type(CellGrid.CellType.SPAWN)
	if not spawn_cells.is_empty():
		start_pos = spawn_cells[0]
	elif not ctx.rooms.is_empty():
		start_pos = ctx.rooms[0].get_center()

	ctx.distance_field = _DungeonDistanceFieldScript.compute_distance_field(ctx.grid, start_pos)

	# 2. Quality Gate Formal (Hard Constraints + Soft Fitness)
	var qg_res = _DungeonQualityGateScript.evaluate(ctx)
	ctx.record_timing("quality_gate_validation", float(Time.get_ticks_msec() - t0))

	if not qg_res.hard_valid:
		var error_msg: String = "[DungeonValidationStage] Attempt %d: Quality Gate Hard Failure: %s" % [
			ctx.attempt,
			str(qg_res.hard_failures)
		]
		
		# Clasificar el fallo como STRUCTURAL si es un problema semántico
		var failure_reason_str: String = str(qg_res.hard_failures)
		var f_type: String = "TRANSIENT"
		if failure_reason_str.contains("BOSS") or failure_reason_str.contains("SEMANTIC") or failure_reason_str.contains("ROOM_TYPE"):
			f_type = "STRUCTURAL"
		
		if ctx.diagnostics_enabled:
			push_warning(error_msg)
		
		ctx.mark_attempt_failed("QUALITY_GATE_HARD_FAILURE: " + failure_reason_str, f_type)
		return false

	ctx.fitness_score = qg_res.fitness_score
	ctx.validation_result = qg_res
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
	var doors_by_room: Dictionary = {}
	for d in doors:
		if d != null:
			if not doors_by_room.has(d.room_id):
				doors_by_room[d.room_id] = []
			doors_by_room[d.room_id].append(d.position)

	for r_id in doors_by_room.keys():
		var r_doors: Array = doors_by_room[r_id]
		for i in range(r_doors.size()):
			for j in range(i + 1, r_doors.size()):
				var p1: Vector2i = r_doors[i]
				var p2: Vector2i = r_doors[j]
				var m_dist: int = absi(p1.x - p2.x) + absi(p1.y - p2.y)
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
