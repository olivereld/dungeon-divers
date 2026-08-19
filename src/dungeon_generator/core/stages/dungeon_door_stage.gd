class_name DungeonDoorStage
extends RefCounted

## Etapa 6: Resolución y Clasificación de Puertas (DoorResolver).

const _DoorResolverScript = preload("res://src/dungeon_generator/core/solvers/door_resolver.gd")

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	var door_res = _DoorResolverScript.resolve_doors(
		ctx.grid,
		ctx.rooms,
		ctx.entrance_pairs,
		ctx.corridor_paths,
		ctx.connections,
		ctx.config
	)
	ctx.record_timing("door_resolver", float(Time.get_ticks_msec() - t0))

	if not door_res.is_valid:
		if ctx.diagnostics_enabled:
			push_warning("[DungeonDoorStage] Attempt %d: DoorResolver failed to resolve doors." % ctx.attempt)
		ctx.mark_attempt_failed("DOOR_RESOLVER_FAILED", "TRANSIENT")
		return false

	ctx.doors = door_res.doors
	ctx.door_pairs = door_res.door_pairs
	return true
