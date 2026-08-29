class_name DungeonRoomStage
extends RefCounted

## Etapa 2: Gramática Espacial, Construcción de Rejilla y Conectividad Interna de Salas.

const _SpaceGrammarScript = preload("res://src/dungeon_generator/core/grammars/space_grammar.gd")
const _CellularAutomataScript = preload("res://src/dungeon_generator/core/algorithms/cellular_automata.gd")
const _RoomShapeGeneratorScript = preload("res://src/dungeon_generator/core/algorithms/room_shape_generator.gd")
const _RoomTemplateResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")
const _RoomTemplateShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")
const _RoomConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/room_connectivity_repair.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")
const _SemanticMappingValidatorScript = preload("res://src/dungeon_generator/core/validation/semantic_mapping_validator.gd")

var _space_grammar := _SpaceGrammarScript.new()
var _cellular_automata := _CellularAutomataScript.new()

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	var layout_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"layout")
	var variation_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"variation")
	ctx.stage_seeds["layout"] = layout_seed
	ctx.stage_seeds["variation"] = variation_seed

	ctx.rooms = _space_grammar.generate(ctx.mission_graph, ctx.config, layout_seed)
	ctx.record_timing("space_grammar", float(Time.get_ticks_msec() - t0))

	# VALIDACIÓN CRÍTICA: Contrato semántico MissionGraph → RoomData
	if not _SemanticMappingValidatorScript.validate_mission_to_room_semantics(ctx.mission_graph, ctx.rooms, ctx):
		return false

	t0 = Time.get_ticks_msec()
	ctx.grid = CellGrid.new(ctx.config.grid_width, ctx.config.grid_height, CellGrid.CellType.WALL)
	
	var rng_variation := RandomNumberGenerator.new()
	rng_variation.seed = variation_seed

	_build_room_floors(ctx.grid, ctx.rooms, ctx.config, rng_variation, ctx)
	ctx.record_timing("room_construction", float(Time.get_ticks_msec() - t0))

	# Validación y Reparación de Conectividad Interna por Habitación
	for r in ctx.rooms:
		var r_val = _StructuralValidatorScript.validate_room_internal_connectivity(ctx.grid, r)
		if not r_val["is_valid"]:
			var room_repair_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"repair_room_%d" % r.id)
			var rep_res = _RoomConnectivityRepairScript.repair_room_internal_connectivity(
				ctx.grid, r, r_val, room_repair_seed
			)

			ctx.record_repair("room_repair", room_repair_seed, rep_res.success, {
				"room_id": r.id,
				"repairs_applied": rep_res.get("repairs_applied", [])
			})

			if not rep_res.success:
				if ctx.diagnostics_enabled:
					push_warning("[DungeonRoomStage] Attempt %d: Room %d internal connectivity failed and could not be repaired." % [
						ctx.attempt, r.id
					])
				ctx.mark_attempt_failed("ROOM_%d_DISCONNECTED" % r.id, "TRANSIENT")
				return false

			var post_val = _StructuralValidatorScript.validate_room_internal_connectivity(ctx.grid, r)
			if not post_val["is_valid"]:
				if ctx.diagnostics_enabled:
					push_warning("[DungeonRoomStage] Attempt %d: Room %d failed post-repair validation." % [
						ctx.attempt, r.id
					])
				ctx.mark_attempt_failed("ROOM_%d_POST_REPAIR_FAILED" % r.id, "TRANSIENT")
				return false

	return true

func _build_room_floors(grid: CellGrid, rooms: Array[RoomData], config: DungeonConfig, rng: RandomNumberGenerator, ctx: DungeonGenerationContext) -> void:
	var template_resolver: _RoomTemplateResolverScript = null
	if ctx != null and ctx.profile_bundle != null and ctx.profile_bundle.template_registry != null:
		template_resolver = _RoomTemplateResolverScript.new(ctx.profile_bundle.template_registry)

	for room in rooms:
		var room_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed if ctx != null else 0, ctx.attempt if ctx != null else 0, &"room_shape_%d" % room.id)
		var room_rng := RandomNumberGenerator.new()
		room_rng.seed = room_seed

		var room_profile = null
		if ctx != null and ctx.profile_bundle != null:
			room_profile = ctx.profile_bundle.get_room(room.room_type)

		if template_resolver != null:
			var resolved_tpl = template_resolver.resolve_template(room, room_profile, [], room_seed)
			var zone_map = _RoomTemplateShapeCarverScript.carve_room_shape(grid, room, resolved_tpl, [], room_rng)
			if "custom_data" in room and room.custom_data is Dictionary:
				room.custom_data["zone_map"] = zone_map
				room.custom_data["resolved_template_id"] = resolved_tpl.id if resolved_tpl != null else &"procedural_fallback"
		else:
			match config.algorithm:
				"CellularAutomata":
					if room.rect.size.x >= 12 and room.rect.size.y >= 12:
						_cellular_automata.apply(grid, room.rect, rng)
						grid.set_cell(room.get_center(), CellGrid.CellType.FLOOR)
					else:
						_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.OCTAGONAL_CHAMBER, rng)
				"BSP":
					grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)
				"Hybrid":
					if room.room_type == &"start" or room.room_type == &"goal":
						_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.OPEN_HALL, rng)
					else:
						var roll: float = rng.randf()
						if roll < 0.60:
							_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.OPEN_HALL, rng)
						elif roll < 0.78:
							_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.OCTAGONAL_CHAMBER, rng)
						elif roll < 0.89:
							_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.CRUCIFORM_SANCTUARY, rng)
						else:
							_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.PILLARED_HALL, rng)
				_:
					grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)

		# Asignar Room Ownership explícito a todas las celdas interiores de la sala
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				var pos := Vector2i(x, y)
				if grid.is_walkable(pos):
					grid.set_room_owner(pos, room.id)
