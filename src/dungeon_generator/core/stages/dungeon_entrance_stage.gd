class_name DungeonEntranceStage
extends RefCounted

## Etapa 4: Resolución de Entradas (EntranceSolver).

const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _CorridorPlannerScript = preload("res://src/dungeon_generator/core/planning/corridor_planner.gd")
const _RoomTemplateResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")
const _RoomTemplateShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()

	# 1. CorridorPlanner establece la intención lógica (roles, preferencias, longitudes soft)
	var planner := _CorridorPlannerScript.new()
	ctx.corridor_plan = planner.plan_corridors(
		ctx.rooms,
		ctx.connections,
		ctx.placement_plan,
		ctx.spatial_intent,
		ctx.mission_graph
	)

	# 2. EntranceSolver resuelve las coordenadas físicas consumiendo la prioridad semántica del plan
	var entrance_res = _EntranceSolverScript.resolve(ctx.rooms, ctx.connections, ctx.grid, ctx.config, ctx.corridor_plan)
	ctx.entrance_pairs = entrance_res.entrance_pairs

	if not entrance_res.is_valid:
		if ctx.diagnostics_enabled:
			push_warning("[DungeonEntranceStage] Attempt %d: EntranceSolver failed to resolve mandatory connections." % ctx.attempt)
		ctx.mark_attempt_failed("ENTRANCE_SOLVER_FAILED", "TRANSIENT")
		return false

	# 3. Enlazar las coordenadas físicas a cada CorridorRequest en ctx.corridor_plan y sellarlo
	if ctx.corridor_plan != null:
		for pair in ctx.entrance_pairs:
			if pair != null:
				var req = ctx.corridor_plan.get_request_for_connection(pair.connection_id)
				if req != null:
					req.bind_physical_entrances(pair)
		ctx.corridor_plan.seal()

	ctx.record_timing("entrance_solver", float(Time.get_ticks_msec() - t0))

	# En modo Template, tallar formas geométricas definitivas con conocimiento completo de las entradas
	if ctx.config != null and ctx.config.algorithm == "Template":
		_carve_templates_with_entrances(ctx)

	return true

func _carve_templates_with_entrances(ctx: DungeonGenerationContext) -> void:
	if ctx == null or ctx.profile_bundle == null or ctx.profile_bundle.template_registry == null:
		return

	var template_resolver := _RoomTemplateResolverScript.new(ctx.profile_bundle.template_registry)

	# 1. Agrupar entradas físicas (inner cells) por room.id
	var entrances_by_room: Dictionary = {}
	for r in ctx.rooms:
		entrances_by_room[r.id] = []

	for pair in ctx.entrance_pairs:
		if pair != null:
			if pair.entrance_a != null and entrances_by_room.has(pair.entrance_a.room_id):
				entrances_by_room[pair.entrance_a.room_id].append(pair.entrance_a.inner_cell)
			if pair.entrance_b != null and entrances_by_room.has(pair.entrance_b.room_id):
				entrances_by_room[pair.entrance_b.room_id].append(pair.entrance_b.inner_cell)

	# 2. Resolver y tallar cada sala con conocimiento exacto de sus entradas
	for room in ctx.rooms:
		var room_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"room_shape_%d" % room.id)
		var room_rng := RandomNumberGenerator.new()
		room_rng.seed = room_seed

		var room_profile = ctx.profile_bundle.get_room(room.room_type)
		var room_entrances: Array[Vector2i] = []
		if entrances_by_room.has(room.id):
			var raw_ents: Array = entrances_by_room[room.id]
			for e in raw_ents:
				if e is Vector2i:
					room_entrances.append(e)

		var resolved_tpl = template_resolver.resolve_template(room, room_profile, room_entrances, room_seed)
		var orientation := _RoomTemplateShapeCarverScript.determine_orientation_from_entrances(room.rect, room_entrances, room_seed)
		var carve_res = _RoomTemplateShapeCarverScript.carve(ctx.grid, room, resolved_tpl, room_entrances, room_rng, orientation)
		if "custom_data" in room and room.custom_data is Dictionary:
			room.custom_data["zone_map"] = carve_res.zone_map if carve_res != null else null
			room.custom_data["resolved_template_id"] = resolved_tpl.id if resolved_tpl != null else &"procedural_fallback"
			room.custom_data["orientation"] = carve_res.orientation if carve_res != null else orientation
			room.custom_data["resolved_anchors"] = carve_res.resolved_anchors if carve_res != null else {}

		# Reconstruir sincronización estricta de room_owner con la geometría final
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				var pos := Vector2i(x, y)
				if ctx.grid.is_walkable(pos):
					ctx.grid.set_room_owner(pos, room.id)
				else:
					ctx.grid.clear_room_owner(pos)
