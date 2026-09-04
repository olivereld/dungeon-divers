class_name DungeonCorridorStage
extends RefCounted

## Etapa 5: Tallado y Reparación de Pasillos, Limpieza y Podado.

const _AStarCarverScript = preload("res://src/dungeon_generator/core/algorithms/astar_carver.gd")
const _CorridorConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/corridor_connectivity_repair.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")
const _RoomConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/room_connectivity_repair.gd")
const _RoomIntegrityCleanerScript = preload("res://src/dungeon_generator/core/repair/room_integrity_cleaner.gd")
const _CorridorPrunerScript = preload("res://src/dungeon_generator/core/algorithms/corridor_pruner.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	var corridor_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"corridor")
	ctx.stage_seeds["corridor"] = corridor_seed

	# Consumir el CorridorPlan sellado y vinculado físicamente desde DungeonEntranceStage
	var corridor_plan = ctx.corridor_plan

	if not ctx.connections.is_empty() and (corridor_plan == null or corridor_plan.is_empty()):
		if ctx.diagnostics_enabled:
			push_warning("[DungeonCorridorStage] Attempt %d: CorridorPlanner produced empty plan for %d connections." % [
				ctx.attempt, ctx.connections.size()
			])
		ctx.mark_attempt_failed("CORRIDOR_PLANNING_FAILED", "TRANSIENT")
		return false

	var requests: Array = corridor_plan.get_requests() if corridor_plan != null else []

	var corridor_res = _AStarCarverScript.carve_corridors(
		ctx.grid,
		ctx.rooms,
		requests,
		ctx.connections,
		ctx.config
	)
	ctx.record_timing("corridor_carving", float(Time.get_ticks_msec() - t0))

	if not corridor_res.is_valid:
		var corridor_repair_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"repair_corridors")
		var c_rep_res = _CorridorConnectivityRepairScript.repair_missing_corridors(
			ctx.grid, ctx.rooms, ctx.entrance_pairs, ctx.connections, corridor_res, corridor_repair_seed, ctx.config, ctx.corridor_plan
		)

		ctx.record_repair("corridor_repair", corridor_repair_seed, c_rep_res.success, {
			"repairs_applied": c_rep_res.get("repairs_applied", [])
		})

		if not c_rep_res.success:
			if ctx.diagnostics_enabled:
				var fail_info: Array = []
				for diag in corridor_res.diagnostics:
					if diag.get("status", "") == "FAILED":
						fail_info.append("conn=%s r_a=%s r_b=%s reason=%s" % [
							str(diag.get("connection_id", "-")),
							str(diag.get("room_a", "-")),
							str(diag.get("room_b", "-")),
							str(diag.get("reason", "-"))
						])
				push_warning("[DungeonCorridorStage] Attempt %d: AStarCarver failed and repair failed. Details: %s" % [
					ctx.attempt, ", ".join(fail_info)
				])
			ctx.mark_attempt_failed("CORRIDOR_CARVING_FAILED", "TRANSIENT")
			return false
		corridor_res = c_rep_res.corridor_res

	ctx.corridor_paths = corridor_res.paths

	# Re-asegurar contigüidad interna de todas las habitaciones tras el tallado
	for r in ctx.rooms:
		var r_check = _StructuralValidatorScript.validate_room_internal_connectivity(ctx.grid, r)
		if not r_check["is_valid"]:
			var post_repair_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"post_corridor_repair_room_%d" % r.id)
			var post_rep = _RoomConnectivityRepairScript.repair_room_internal_connectivity(
				ctx.grid, r, r_check, post_repair_seed
			)
			if post_rep.get("success", false):
				ctx.record_repair("post_corridor_room_repair", post_repair_seed, true, { "room_id": r.id })

	# Limpieza de bolsillos huérfanos y podado de stubs ciegos
	_RoomIntegrityCleanerScript.clean_orphaned_room_pockets(ctx.grid, ctx.rooms)

	var protected_cells: Array[Vector2i] = []
	for ep in ctx.entrance_pairs:
		if ep != null:
			if ep.entrance_a != null:
				protected_cells.append(ep.entrance_a.outer_cell)
				protected_cells.append(ep.entrance_a.boundary_cell)
			if ep.entrance_b != null:
				protected_cells.append(ep.entrance_b.outer_cell)
				protected_cells.append(ep.entrance_b.boundary_cell)

	_CorridorPrunerScript.prune_dead_end_stubs(ctx.grid, protected_cells)
	return true
