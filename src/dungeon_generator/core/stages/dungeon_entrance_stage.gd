class_name DungeonEntranceStage
extends RefCounted

## Etapa 4: Resolución de Entradas (EntranceSolver).

const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	var entrance_res = _EntranceSolverScript.resolve(ctx.rooms, ctx.connections, ctx.grid, ctx.config)
	ctx.entrance_pairs = entrance_res.entrance_pairs
	ctx.record_timing("entrance_solver", float(Time.get_ticks_msec() - t0))

	if not entrance_res.is_valid:
		if ctx.diagnostics_enabled:
			push_warning("[DungeonEntranceStage] Attempt %d: EntranceSolver failed to resolve mandatory connections." % ctx.attempt)
		ctx.mark_attempt_failed("ENTRANCE_SOLVER_FAILED", "TRANSIENT")
		return false

	return true
