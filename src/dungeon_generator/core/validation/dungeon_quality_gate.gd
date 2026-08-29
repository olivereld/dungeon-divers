class_name DungeonQualityGate
extends RefCounted

## Quality Gate canónica del generador de mazmorras (Fase 13).
## Separa formalmente las Hard Constraints (rechazo inmediato del intento si alguna falla)
## de las Soft Quality Heuristics (puntuación de fitness de 0.0 a 100.0).

const _DungeonDistanceFieldScript = preload("res://src/dungeon_generator/core/algorithms/dungeon_distance_field.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")
const _FitnessEvaluatorScript = preload("res://src/dungeon_generator/core/solvers/fitness_evaluator.gd")

class QualityGateResult extends RefCounted:
	var hard_valid: bool = true
	var is_valid: bool = true
	var is_winnable: bool = true
	var hard_failures: Array[String] = []
	var fitness_score: float = 0.0
	var soft_metrics: Dictionary = {}
	var diagnostics: Dictionary = {}

	func add_hard_failure(reason: String) -> void:
		hard_valid = false
		is_valid = false
		is_winnable = false
		hard_failures.append(reason)

## Evalúa exhaustivamente el contexto de generación como Quality Gate formal.
static func evaluate(ctx: DungeonGenerationContext) -> QualityGateResult:
	var res := QualityGateResult.new()
	if ctx == null or ctx.grid == null:
		res.add_hard_failure("NULL_CONTEXT_OR_GRID")
		return res

	# =========================================================================
	# 1. HARD CONSTRAINTS (Cualquier fallo rechaza el intento)
	# =========================================================================

	# 1.1 Structural Invariants (Grid, Rooms, Connections)
	var struct_validator := _StructuralValidatorScript.new()
	var struct_report = struct_validator.validate_structure(ctx.grid, ctx.rooms, ctx.connections)
	if not struct_report.is_valid:
		for err in struct_report.errors:
			res.add_hard_failure("STRUCTURAL_ERROR: " + err)

	# 1.2 Reachability & Connectivity (100% Floor Reachable)
	var total_walkable: int = ctx.grid.count_walkable_cells()
	var reached_count: int = ctx.distance_field.size()
	if reached_count < total_walkable:
		res.add_hard_failure("UNREACHABLE_WALKABLE_CELLS: %d / %d reachable" % [reached_count, total_walkable])

	# 1.3 Doors Validity (In Bounds, Walkable, Matched)
	if ctx.doors.is_empty() and not ctx.connections.is_empty():
		res.add_hard_failure("NO_DOORS_FOR_CONNECTIONS")

	for d in ctx.doors:
		if d == null or not ctx.grid.is_in_bounds(d.position):
			res.add_hard_failure("DOOR_OUT_OF_BOUNDS")
		elif not ctx.grid.is_walkable(d.position):
			res.add_hard_failure("DOOR_ON_NON_WALKABLE_CELL: %s" % str(d.position))

	# 1.4 Boss Reachability & Depth
	if ctx.boss_room_id != -1 and not ctx.distance_field.is_empty():
		var boss_room: RoomData = null

		for room in ctx.rooms:
			if room != null and room.id == ctx.boss_room_id:
				boss_room = room
				break
		if boss_room != null:
			var boss_center = boss_room.get_center()
			if not ctx.distance_field.has(boss_center):
				res.add_hard_failure("BOSS_ROOM_UNREACHABLE")

	# 1.5 Semantic Invariants (Fase 11 & Fase 12: Exactly 1 Boss, Boss != Start)
	if ctx.config != null and ctx.config.boss_enabled and ctx.rooms.size() >= 2:
		var boss_count: int = 0
		for r in ctx.rooms:
			if r != null and r.room_type == &"boss":
				boss_count += 1
		if boss_count != 1:
			res.add_hard_failure("SEMANTIC_ERROR: Expected exactly 1 boss room, got %d" % boss_count)
		if ctx.boss_room_id != -1 and ctx.start_room_id != -1 and ctx.boss_room_id == ctx.start_room_id:
			res.add_hard_failure("SEMANTIC_ERROR: Boss room cannot be the start room")

	# Si falló alguna Hard Constraint, abortar antes de calcular fitness
	if not res.hard_valid:
		return res

	# =========================================================================
	# 2. SOFT QUALITY HEURISTICS (Puntuación de Fitness 0.0 a 100.0)
	# =========================================================================
	var fitness_evaluator := _FitnessEvaluatorScript.new()
	res.fitness_score = fitness_evaluator.evaluate(ctx.grid, ctx.rooms, ctx.config)
	res.soft_metrics = {
		"fitness_score": res.fitness_score,
		"reachable_cells": ctx.distance_field.size(),
		"total_walkable_cells": total_walkable
	}

	return res
