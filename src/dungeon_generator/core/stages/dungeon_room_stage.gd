class_name DungeonRoomStage
extends RefCounted

## Etapa 2: Gramática Espacial, Construcción de Rejilla y Conectividad Interna de Salas.

const _SpaceGrammarScript = preload("res://src/dungeon_generator/core/grammars/space_grammar.gd")
const _CellularAutomataScript = preload("res://src/dungeon_generator/core/algorithms/cellular_automata.gd")
const _RoomShapeGeneratorScript = preload("res://src/dungeon_generator/core/algorithms/room_shape_generator.gd")
const _RoomTemplateResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")
const _RoomTemplateShapeCarverScript = preload("res://src/dungeon_generator/core/room_templates/generation/room_template_shape_carver.gd")
const _ZoneMapScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_zone_map.gd")
const _StructuralValidatorScript = preload("res://src/dungeon_generator/core/validation/structural_validator.gd")
const _RoomConnectivityRepairScript = preload("res://src/dungeon_generator/core/repair/room_connectivity_repair.gd")
const _DungeonSeedFactoryScript = preload("res://src/dungeon_generator/core/generation/dungeon_seed_factory.gd")
const _SemanticMappingValidatorScript = preload("res://src/dungeon_generator/core/validation/semantic_mapping_validator.gd")
const _CompositionStrategyScript = preload("res://src/dungeon_generator/core/grammars/composition_strategy.gd")
const _SpatialIntentBuilderScript = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")
const _RoomPlacementPlanScript = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const _RoomPlacerScript = preload("res://src/dungeon_generator/core/placement/room_placer.gd")
const _RoomSpatialSeparatorScript = preload("res://src/dungeon_generator/core/topology/room_spatial_separator.gd")
const _SpaceGrammarConfigScript = preload("res://src/dungeon_generator/config/space_grammar_config.gd")

var _space_grammar := _SpaceGrammarScript.new()
var _cellular_automata := _CellularAutomataScript.new()

func execute(ctx: DungeonGenerationContext) -> bool:
	var t0 := Time.get_ticks_msec()
	var layout_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"layout")
	var variation_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed, ctx.attempt, &"variation")
	ctx.stage_seeds["layout"] = layout_seed
	ctx.stage_seeds["variation"] = variation_seed

	# 1. SpaceGrammar: WHAT rooms exist (room creation and configuration only)
	ctx.rooms = _space_grammar.generate(ctx.mission_graph, ctx.config, layout_seed)
	ctx.placement_tier_3 = 0
	ctx.placement_tier_4 = 0
	ctx.record_timing("space_grammar", float(Time.get_ticks_msec() - t0))

	# VALIDACIÓN CRÍTICA: Contrato semántico MissionGraph → RoomData
	if not _SemanticMappingValidatorScript.validate_mission_to_room_semantics(ctx.mission_graph, ctx.rooms, ctx):
		return false

	# 2. CompositionStrategy: WHERE rooms go (evaluates candidates, generates sealed RoomPlacementPlan)
	var t_place := Time.get_ticks_msec()
	var placement_rng := RandomNumberGenerator.new()
	placement_rng.seed = layout_seed

	var grid_w: int = ctx.config.grid_width if ctx.config != null else 64
	var grid_h: int = ctx.config.grid_height if ctx.config != null else 64
	var grid_bounds := Rect2i(3, 3, grid_w - 6, grid_h - 6)

	var strategy := _CompositionStrategyScript.new(placement_rng)
	var sg_config: _SpaceGrammarConfigScript = ctx.config.space_grammar_config if (ctx.config != null and ctx.config.space_grammar_config != null) else null
	if sg_config == null and ctx.config != null:
		sg_config = _SpaceGrammarConfigScript.new()
		sg_config.use_mission_aware_placement = ctx.config.use_mission_aware_placement
		sg_config.mission_aware_preferred_distance = ctx.config.mission_aware_preferred_distance
		sg_config.mission_aware_candidate_count = ctx.config.mission_aware_candidate_count
		sg_config.mission_aware_distance_jitter = ctx.config.mission_aware_distance_jitter
		sg_config.min_room_separation = ctx.config.min_room_separation
		sg_config.min_mission_edge_distance = ctx.config.min_mission_edge_distance
		sg_config.max_mission_edge_distance = ctx.config.max_mission_edge_distance
		sg_config.progression_strength = ctx.config.progression_strength
		sg_config.density_strength = ctx.config.density_strength
		sg_config.preferred_progression_direction = ctx.config.preferred_progression_direction

	if ctx.mission_graph != null:
		var intent_builder := _SpatialIntentBuilderScript.new()
		ctx.spatial_intent = intent_builder.build(ctx.mission_graph)

	var plan = strategy.create_placement_plan(ctx.rooms, ctx.mission_graph, grid_bounds, sg_config, ctx.spatial_intent)
	ctx.placement_plan = plan

	# 3. RoomPlacer: APPLY placement decisions to ctx.rooms
	var placer := _RoomPlacerScript.new()
	var placed_count: int = placer.apply_plan(ctx.rooms, plan)
	if placed_count != ctx.rooms.size():
		ctx.mark_attempt_failed("ROOM_PLACEMENT_INCOMPLETE", "TRANSIENT")
		return false

	# 4. RoomSpatialSeparator: REPAIR ONLY if any overlap occurs
	if not placer.validate_placement_integrity(ctx.rooms, 2):
		ctx.rooms = _RoomSpatialSeparatorScript.separate_rooms(ctx.rooms, grid_bounds, placement_rng, 2)

	ctx.record_timing("room_placement", float(Time.get_ticks_msec() - t_place))

	# 5. Construct CellGrid AFTER room placement is applied, so shapes reflect new positions
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
	var algo: String = config.algorithm if config != null else "Hybrid"
	var template_resolver: _RoomTemplateResolverScript = null
	if ctx != null and ctx.profile_bundle != null and ctx.profile_bundle.template_registry != null:
		template_resolver = _RoomTemplateResolverScript.new(ctx.profile_bundle.template_registry)

	for room in rooms:
		var room_seed: int = _DungeonSeedFactoryScript.derive_seed(ctx.base_seed if ctx != null else 0, ctx.attempt if ctx != null else 0, &"room_shape_%d" % room.id)
		var room_rng := RandomNumberGenerator.new()
		room_rng.seed = room_seed

		var room_profile = null
		if ctx != null and ctx.profile_bundle != null:
			if config != null and config.profile_mode == &"force_profile" and not config.forced_profile_id.is_empty():
				room_profile = ctx.profile_bundle.get_room(config.forced_profile_id)
			else:
				room_profile = ctx.profile_bundle.get_room(room.room_type)
				if room_profile == null and ctx.profile_bundle.archetype != null:
					var g_map: Dictionary = ctx.profile_bundle.archetype.gameplay_purpose_map
					var key: String = str(room.room_type).to_upper()
					if g_map.has(key) and not g_map[key].is_empty():
						var candidates_list: Array = g_map[key]
						var mapped_purpose = candidates_list[room_rng.randi_range(0, candidates_list.size() - 1)]
						room_profile = ctx.profile_bundle.get_room(mapped_purpose)

		var resolved_tpl: RoomTemplate = null
		if template_resolver != null:
			if config != null and (config.template_mode == &"specific" or config.profile_mode == &"force_template") and not config.forced_template_id.is_empty():
				resolved_tpl = ctx.profile_bundle.template_registry.get_template(config.forced_template_id)
			else:
				resolved_tpl = template_resolver.resolve_template(room, room_profile, [], room_seed)

		var is_fallback: bool = (resolved_tpl == null or resolved_tpl.id == &"procedural_fallback")
		var prof_id: StringName = room_profile.id if room_profile != null else &"none"

		if not is_fallback:
			var zone_map = _RoomTemplateShapeCarverScript.carve_room_shape(grid, room, resolved_tpl, [], room_rng)
			if "custom_data" in room and room.custom_data is Dictionary:
				room.custom_data["zone_map"] = zone_map
				room.custom_data["resolved_template_id"] = resolved_tpl.id
				room.custom_data["profile_id"] = prof_id
				room.custom_data["is_template_fallback"] = false
		else:
			match algo:
				"CellularAutomata":
					if room.rect.size.x >= 12 and room.rect.size.y >= 12:
						_cellular_automata.apply(grid, room.rect, room_rng)
						grid.set_cell(room.get_center(), CellGrid.CellType.FLOOR)
					else:
						_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.OCTAGONAL_CHAMBER, room_rng)
				"BSP":
					grid.fill_rect(room.rect, CellGrid.CellType.FLOOR)
				"Hybrid", "Template", _:
					if room.room_type == &"start" or room.room_type == &"goal":
						_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.OPEN_HALL, room_rng)
					else:
						var roll: float = room_rng.randf()
						if roll < 0.60:
							_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.OPEN_HALL, room_rng)
						elif roll < 0.78:
							_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.OCTAGONAL_CHAMBER, room_rng)
						elif roll < 0.89:
							_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.CRUCIFORM_SANCTUARY, room_rng)
						else:
							_RoomShapeGeneratorScript.apply_room_shape(grid, room, _RoomShapeGeneratorScript.ShapeType.PILLARED_HALL, room_rng)

			# Adjuntar zone_map por defecto sin mutar celdas
			var zm := _ZoneMapScript.new(room.rect)
			zm.set_zone(room.get_center(), &"focal")
			for cy in range(room.rect.position.y, room.rect.end.y):
				for cx in range(room.rect.position.x, room.rect.end.x):
					var cpos := Vector2i(cx, cy)
					if grid.is_walkable(cpos) and zm.get_zone(cpos) == &"unassigned":
						zm.set_zone(cpos, &"circulation")
			if "custom_data" in room and room.custom_data is Dictionary:
				room.custom_data["zone_map"] = zm
				room.custom_data["resolved_template_id"] = &"procedural_fallback"
				room.custom_data["profile_id"] = prof_id
				room.custom_data["is_template_fallback"] = true

		if ctx != null and ctx.diagnostics_enabled:
			print("[DungeonRoomStage] Room %d: type=%s, profile=%s, size=%s, template=%s, fallback=%s" % [
				room.id, room.room_type, prof_id, str(room.rect.size),
				str(room.custom_data.get("resolved_template_id", "none")),
				str(room.custom_data.get("is_template_fallback", true))
			])

		# Asignar Room Ownership explícito a todas las celdas interiores de la sala
		for y in range(room.rect.position.y, room.rect.end.y):
			for x in range(room.rect.position.x, room.rect.end.x):
				var pos := Vector2i(x, y)
				if grid.is_walkable(pos):
					grid.set_room_owner(pos, room.id)
