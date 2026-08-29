class_name DungeonEntranceStage
extends RefCounted

## Etapa 4: Resolución de Entradas (EntranceSolver).

const _EntranceSolverScript = preload("res://src/dungeon_generator/core/solvers/entrance_solver.gd")
const _RoomTemplateResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")
const _RoomTemplateShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")

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
				entrances_by_room[pair.entrance_a.room_id].append(pair.entrance_a.inner_position)
			if pair.entrance_b != null and entrances_by_room.has(pair.entrance_b.room_id):
				entrances_by_room[pair.entrance_b.room_id].append(pair.entrance_b.inner_position)

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
		var zone_map = _RoomTemplateShapeCarverScript.carve_room_shape(ctx.grid, room, resolved_tpl, room_entrances, room_rng)
		if "custom_data" in room and room.custom_data is Dictionary:
			room.custom_data["zone_map"] = zone_map
			room.custom_data["resolved_template_id"] = resolved_tpl.id if resolved_tpl != null else &"procedural_fallback"

		# Reconstruir sincronización estricta de room_owner con la geometría final
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				var pos := Vector2i(x, y)
				if ctx.grid.is_walkable(pos):
					ctx.grid.set_room_owner(pos, room.id)
				else:
					ctx.grid.clear_room_owner(pos)
