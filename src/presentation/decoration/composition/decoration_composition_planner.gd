class_name DecorationCompositionPlanner
extends RefCounted

## Planificador inteligente y determinista de composición espacial semántica (Semantic Spatial Composition Engine).
## Orquesta perfiles de propósito, intenciones de sala, zonificación espacial, plantillas compositivas,
## resolución de relaciones/simetría, mapa unificado de ocupación y presupuesto de iluminación.

const _DecorationCompositionScript = preload("res://src/presentation/decoration/decoration_composition.gd")
const _DecorationOccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")
const _DecorationPlacementConstraintScript = preload("res://src/presentation/decoration/composition/decoration_placement_constraint.gd")
const _DecorationPlacementCandidateScript = preload("res://src/presentation/decoration/composition/decoration_placement_candidate.gd")
const _DecorationPlacementScorerScript = preload("res://src/presentation/decoration/composition/decoration_placement_scorer.gd")
const _DecorationOrientationResolverScript = preload("res://src/presentation/decoration/composition/decoration_orientation_resolver.gd")
const _DecorationRoomZoneScript = preload("res://src/presentation/decoration/composition/decoration_room_zone.gd")
const _DecorationPurposeProfileRegistryScript = preload("res://src/presentation/decoration/composition/decoration_purpose_profile_registry.gd")
const _DecorationRelationshipSolverScript = preload("res://src/presentation/decoration/composition/decoration_relationship_solver.gd")
const _DecorationLightingPlannerScript = preload("res://src/presentation/decoration/composition/decoration_lighting_planner.gd")
const _PropFixtureRelationshipResolverScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relationship_resolver.gd")
const _PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const _DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")

const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")
const _DecorationCompositionRuleScript = preload("res://src/presentation/decoration/composition/decoration_composition_rule.gd")
const _DecorationRoomIntentScript = preload("res://src/presentation/decoration/composition/decoration_room_intent.gd")
const _FixtureBudgetRuleScript = preload("res://src/presentation/decoration/composition/fixture_budget_rule.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _PropFixtureRelationScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation.gd")
const _PropFixtureRelationPlacementScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relation_placement.gd")
const _PropFixtureRelationshipProfileScript = preload("res://src/presentation/decoration/relationships/prop_fixture_relationship_profile.gd")
const _DecorationOrientationModeScript = preload("res://src/presentation/decoration/composition/decoration_orientation_mode.gd")

var _anchor_resolver := _PropAnchorResolverScript.new()
var _scorer := _DecorationPlacementScorerScript.new()
var _orientation_resolver := _DecorationOrientationResolverScript.new()
var _zone_partitioner := _DecorationRoomZoneScript.new()
var _purpose_registry := _DecorationPurposeProfileRegistryScript.new()
var _relationship_solver := _DecorationRelationshipSolverScript.new()
var _relationship_resolver := _PropFixtureRelationshipResolverScript.new()
var _lighting_planner := _DecorationLightingPlannerScript.new()
var _constraint := _DecorationPlacementConstraintScript.new()

func plan_room_composition(
	profile = null, # ProfileRoom or DecorationCompositionProfile
	palette = null, # DecorationPalette
	room_geometry = null,
	room_context = null,
	partition = null,
	seed_ctx = null,
	tile_size: float = 2.0
) -> _DecorationCompositionScript:
	var room_id: int = room_context.room_id if room_context != null and "room_id" in room_context else (room_geometry.room_id if room_geometry != null and "room_id" in room_geometry else 0)
	var comp := _DecorationCompositionScript.new(room_id)

	if room_geometry == null or palette == null:
		return comp

	var occupancy := _DecorationOccupancyMapScript.new()
	var floor_cells_map: Dictionary = {}
	for fc in room_geometry.floor_cells:
		floor_cells_map[fc] = true

	# 1. Zonificación espacial de la sala
	var zones: Dictionary = _zone_partitioner.partition_room(room_geometry, tile_size)

	# 2. Extraer o resolver el perfil de propósito / ProfileRoom
	var profile_room = null
	if profile is _ProfileRoomScript:
		profile_room = profile
	elif room_context != null and "room_profile" in room_context and room_context.room_profile is _ProfileRoomScript:
		profile_room = room_context.room_profile

	var purpose_type: int = 0
	if room_context is Dictionary:
		purpose_type = int(room_context.get("purpose", room_context.get("room_purpose", 0)))
	elif room_context != null and "purpose" in room_context:
		purpose_type = int(room_context.purpose)
	elif room_context != null and "room_purpose" in room_context:
		purpose_type = int(room_context.room_purpose)

	var purpose_profile = _purpose_registry.get_profile_for_purpose(purpose_type)
	var intent = null
	var relationship_profile = null
	var fixture_rules: Array = []
	var total_budget: float = 5.0
	var rules_to_execute: Array = []

	if profile_room != null:
		# Adaptar directamente desde ProfileRoom (fuente de verdad JSON)
		intent = _build_intent_from_profile_room(profile_room)
		rules_to_execute = _build_rules_from_profile_room(profile_room)
		relationship_profile = _build_relationship_profile_from_profile_room(profile_room)
		fixture_rules = _build_fixture_rules_from_profile_room(profile_room)
		total_budget = profile_room.lighting.budget if profile_room.lighting != null else 4.0
	else:
		# Fallback legacy a purpose_profile de registry
		intent = purpose_profile.intent if purpose_profile != null else null
		relationship_profile = purpose_profile.relationship_profile if purpose_profile != null else null
		fixture_rules = purpose_profile.fixture_rules if purpose_profile != null and "fixture_rules" in purpose_profile else []
		total_budget = profile.lighting_budget if (profile != null and "lighting_budget" in profile) else (purpose_profile.default_lighting_budget if purpose_profile != null else 5.0)

		if profile != null and "rules" in profile and not profile.rules.is_empty():
			rules_to_execute = profile.rules.duplicate()
		elif purpose_profile != null and not purpose_profile.templates.is_empty():
			for t in purpose_profile.templates:
				rules_to_execute.append_array(t.get_all_rules())

	var door_cells: Array[Vector2i] = []
	if "door_positions" in room_geometry and room_geometry.door_positions is Array:
		for d in room_geometry.door_positions:
			door_cells.append(d as Vector2i)
	elif "door_cells" in room_geometry and room_geometry.door_cells is Array:
		for d in room_geometry.door_cells:
			door_cells.append(d as Vector2i)

	var stair_cells: Array[Vector2i] = []
	if "stairs_positions" in room_geometry and room_geometry.stairs_positions is Array:
		for s in room_geometry.stairs_positions:
			stair_cells.append(s as Vector2i)
	elif "stair_cells" in room_geometry and room_geometry.stair_cells is Array:
		for s in room_geometry.stair_cells:
			stair_cells.append(s as Vector2i)

	# 3. Aplicar reservas estructurales en el mapa de ocupación
	for d_pos in door_cells:
		occupancy.add_clearance([d_pos], &"door_approach")
		comp.reserve_cell(d_pos, &"door_approach")

	for s_pos in stair_cells:
		occupancy.add_clearance([s_pos], &"stair_approach")
		comp.reserve_cell(s_pos, &"stair_approach")

	# Calcular centro geométrico de la sala
	var room_center_cell := Vector2i.ZERO
	if not room_geometry.floor_cells.is_empty():
		var sum_x: int = 0
		var sum_y: int = 0
		for c in room_geometry.floor_cells:
			sum_x += c.x
			sum_y += c.y
		room_center_cell = Vector2i(sum_x / room_geometry.floor_cells.size(), sum_y / room_geometry.floor_cells.size())

	var max_allowed: int = 10
	if palette != null and palette.props != null and palette.props.max_props_per_room > 0:
		max_allowed = palette.props.max_props_per_room
	if profile != null and "max_total_props" in profile and profile.max_total_props > 0:
		max_allowed = mini(max_allowed, profile.max_total_props)

	var total_placed: int = 0
	var primary_placed_cells: Array[Vector2i] = []

	if not rules_to_execute.is_empty() and palette.props != null:
		rules_to_execute.sort_custom(func(a, b): return a.composition_role < b.composition_role)

		var prop_seed_val: int = _extract_prop_seed(seed_ctx)

		# === PASS 1: Guarantee min_count for each rule in priority order ===
		for rule in rules_to_execute:
			var target_entries: Array = _find_matching_palette_entries(palette.props.entries, rule, intent)
			if target_entries.is_empty():
				continue

			var placed_for_rule: int = 0
			var anchors: Array = _discover_anchors_for_rule(rule, room_geometry, tile_size)
			if anchors.is_empty():
				continue

			var candidates: Array[_DecorationPlacementCandidateScript] = _build_scored_candidates(
				anchors, target_entries, rule, zones, intent, floor_cells_map,
				comp, occupancy, door_cells, stair_cells, room_center_cell, prop_seed_val, primary_placed_cells
			)
			candidates.sort_custom(func(a, b): return a.score > b.score)

			for cand in candidates:
				if placed_for_rule >= rule.min_count:
					break

				if occupancy.add_footprint(cand.occupied_cells, cand.style_id, 0):
					if rule.clearance > 0:
						var clear_cells := _calculate_clearance_ring(cand.occupied_cells, rule.clearance)
						occupancy.add_clearance(clear_cells, cand.style_id)

					var dir := _PropDirectiveScript.new(
						cand.style_id, room_id, cand.style, cand.world_position,
						cand.rotation_y, cand.occupied_cells,
						cand.style.placement_mode if cand.style != null else _PropPlacementModeScript.Mode.FLOOR,
						cand.style.collision_mode if cand.style != null else 0
					)
					if comp.add_prop_directive(dir):
						placed_for_rule += 1
						total_placed += 1
						if rule.composition_role == _CompositionRoleScript.Role.PRIMARY:
							primary_placed_cells.append_array(cand.occupied_cells)

		# === PASS 2: Fill extras up to max_count, capped by max_allowed ===
		for rule in rules_to_execute:
			if total_placed >= max_allowed:
				break

			var target_entries: Array = _find_matching_palette_entries(palette.props.entries, rule, intent)
			if target_entries.is_empty():
				continue

			# Contar cuántos props de esta regla ya fueron colocados en Pass 1
			var already_placed: int = 0
			for dir in comp.prop_directives:
				for me in target_entries:
					if dir.prop_id == me.style.id:
						already_placed += 1
						break

			var remaining_for_rule: int = rule.max_count - already_placed
			if remaining_for_rule <= 0:
				continue

			var anchors: Array = _discover_anchors_for_rule(rule, room_geometry, tile_size)
			if anchors.is_empty():
				continue

			var candidates: Array[_DecorationPlacementCandidateScript] = _build_scored_candidates(
				anchors, target_entries, rule, zones, intent, floor_cells_map,
				comp, occupancy, door_cells, stair_cells, room_center_cell, prop_seed_val, primary_placed_cells
			)
			candidates.sort_custom(func(a, b): return a.score > b.score)

			var extras_placed: int = 0
			for cand in candidates:
				if extras_placed >= remaining_for_rule or total_placed >= max_allowed:
					break

				if occupancy.add_footprint(cand.occupied_cells, cand.style_id, 0):
					if rule.clearance > 0:
						var clear_cells := _calculate_clearance_ring(cand.occupied_cells, rule.clearance)
						occupancy.add_clearance(clear_cells, cand.style_id)

					var dir := _PropDirectiveScript.new(
						cand.style_id, room_id, cand.style, cand.world_position,
						cand.rotation_y, cand.occupied_cells,
						cand.style.placement_mode if cand.style != null else _PropPlacementModeScript.Mode.FLOOR,
						cand.style.collision_mode if cand.style != null else 0
					)
					if comp.add_prop_directive(dir):
						extras_placed += 1
						total_placed += 1
						if rule.composition_role == _CompositionRoleScript.Role.PRIMARY:
							primary_placed_cells.append_array(cand.occupied_cells)

	# 5. Resolver relaciones espaciales semánticas (Prop -> Fixture)
	if palette.fixtures != null and relationship_profile != null:
		var fixture_seed_val: int = _extract_fixture_seed(seed_ctx)
		var rel_dirs = _relationship_resolver.resolve_relationships(
			comp.prop_directives,
			relationship_profile,
			palette.fixtures,
			room_geometry,
			occupancy,
			fixture_seed_val,
			tile_size
		)
		for f_dir in rel_dirs:
			if not comp.reserved_cells.has(f_dir.cell):
				if profile_room != null and profile_room.lighting != null:
					var l_set = profile_room.lighting.resolve_settings_for_fixture(
						&"floor",
						f_dir.fixture_id,
						f_dir.style.light_color if f_dir.style != null else Color.WHITE,
						f_dir.style.light_energy if f_dir.style != null else 1.0,
						f_dir.style.light_range if f_dir.style != null else 4.0
					)
					f_dir.set_custom_lighting(l_set.color, l_set.energy, l_set.light_range)
				comp.add_fixture_directive(f_dir)

	# 6. Planificar iluminación ambiental por presupuesto reconciliado y roles
	if palette.fixtures != null:
		# Reconciliación estricta: calcular el presupuesto ya consumido por las luminarias de relaciones semánticas
		var consumed_budget: float = 0.0
		for f_dir in comp.fixture_directives:
			if f_dir.style != null and f_dir.style.has_light:
				consumed_budget += f_dir.style.light_energy * 0.5
		var remaining_budget: float = maxf(0.0, total_budget - consumed_budget)

		var fixture_seed_val: int = _extract_fixture_seed(seed_ctx)
		var light_dirs = _lighting_planner.plan_room_lighting(
			remaining_budget,
			intent,
			palette.fixtures,
			primary_placed_cells,
			room_geometry,
			occupancy,
			fixture_seed_val,
			tile_size,
			fixture_rules,
			profile_room.lighting if profile_room != null else null
		)
		for f_dir in light_dirs:
			if not comp.reserved_cells.has(f_dir.cell):
				comp.add_fixture_directive(f_dir)

	return comp

func _build_intent_from_profile_room(p_room: _ProfileRoomScript) -> _DecorationRoomIntentScript:
	var intent := _DecorationRoomIntentScript.new()
	if p_room.intent != null:
		intent.player_clearance_level = p_room.intent.player_clearance_level
		intent.symmetry_required = p_room.intent.symmetry
		intent.allowed_tags = p_room.intent.allowed_tags.duplicate()
		intent.forbidden_tags = p_room.intent.forbidden_tags.duplicate()
	return intent

func _build_rules_from_profile_room(p_room: _ProfileRoomScript) -> Array:
	var result: Array = []
	if p_room.composition == null:
		return result

	# Primary
	if p_room.composition.primary != null:
		result.append(_convert_profile_rule(p_room.composition.primary, _CompositionRoleScript.Role.PRIMARY))

	# Secondary
	for sec in p_room.composition.secondary:
		result.append(_convert_profile_rule(sec, _CompositionRoleScript.Role.SECONDARY))

	# Support
	for sup in p_room.composition.support:
		result.append(_convert_profile_rule(sup, _CompositionRoleScript.Role.COMPANION))

	return result

func _convert_profile_rule(p_rule, role: int) -> _DecorationCompositionRuleScript:
	var rule := _DecorationCompositionRuleScript.new()
	rule.rule_id = p_rule.rule_id
	rule.composition_role = role
	rule.min_count = p_rule.min_count
	rule.max_count = p_rule.max_count
	rule.clearance = p_rule.clearance
	rule.required_tags = p_rule.asset_tags.duplicate()
	rule.forbidden_tags = p_rule.forbidden_tags.duplicate()

	match str(p_rule.placement_mode).to_lower():
		"wall", "perimeter":
			rule.placement_mode = _PropPlacementModeScript.Mode.WALL
		"corner":
			rule.placement_mode = _PropPlacementModeScript.Mode.CORNER
		"center":
			rule.placement_mode = _PropPlacementModeScript.Mode.CENTER
		_: # floor
			rule.placement_mode = _PropPlacementModeScript.Mode.FLOOR

	match str(p_rule.orientation).to_lower():
		"face_wall":
			rule.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_WALL
		"face_center":
			rule.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_CENTER
		"align_wall":
			rule.orientation_mode = _DecorationOrientationModeScript.Mode.ALIGN_WALL
		"free", "random":
			rule.orientation_mode = _DecorationOrientationModeScript.Mode.FREE
		_: # face_room, fixed
			rule.orientation_mode = _DecorationOrientationModeScript.Mode.FACE_ROOM

	return rule

func _build_relationship_profile_from_profile_room(p_room: _ProfileRoomScript):
	if p_room.relationships.is_empty():
		return null

	var relations_arr: Array[_PropFixtureRelationScript] = []
	for rel in p_room.relationships:
		var target_types: Array[int] = []
		var target_ids: Array[StringName] = []
		for t_str in rel.targets:
			target_ids.append(StringName(str(t_str)))
			var f_type = _fixture_style_from_name(str(t_str))
			if f_type >= 0 and not target_types.has(f_type):
				target_types.append(f_type)

		var forbidden_types: Array[int] = []
		var forbidden_ids: Array[StringName] = []
		for f_str in rel.forbidden_targets:
			forbidden_ids.append(StringName(str(f_str)))
			var f_type = _fixture_style_from_name(str(f_str))
			if f_type >= 0 and not forbidden_types.has(f_type):
				forbidden_types.append(f_type)

		var placement_enum = _PropFixtureRelationPlacementScript.Placement.NEAR
		match str(rel.placement).to_lower():
			"above":
				placement_enum = _PropFixtureRelationPlacementScript.Placement.ABOVE
			"left":
				placement_enum = _PropFixtureRelationPlacementScript.Placement.LEFT
			"right":
				placement_enum = _PropFixtureRelationPlacementScript.Placement.RIGHT
			"front":
				placement_enum = _PropFixtureRelationPlacementScript.Placement.FRONT
			"back":
				placement_enum = _PropFixtureRelationPlacementScript.Placement.BACK
			"surface":
				placement_enum = _PropFixtureRelationPlacementScript.Placement.SURFACE
			_: # near, flanking
				placement_enum = _PropFixtureRelationPlacementScript.Placement.NEAR

		for src_name in rel.source:
			var r := _PropFixtureRelationScript.new(
				src_name,
				target_types,
				placement_enum,
				rel.min_count,
				rel.max_count,
				rel.id,
				rel.min_distance,
				rel.max_distance,
				1.0,
				forbidden_types
			)
			r.target_fixture_ids = target_ids
			r.forbidden_fixture_ids = forbidden_ids
			relations_arr.append(r)

	return _PropFixtureRelationshipProfileScript.new(StringName(str(p_room.id) + "_profile_relations"), relations_arr)

func _build_fixture_rules_from_profile_room(p_room: _ProfileRoomScript) -> Array:
	var result: Array = []
	if p_room.lighting == null:
		return result

	var l = p_room.lighting
	if l.wall != null and (l.wall.min_count > 0 or l.wall.max_count > 0):
		var styles: Array[int] = []
		var f_ids: Array[StringName] = []
		for a in l.wall.allowed:
			f_ids.append(StringName(str(a)))
			var st = _fixture_style_from_name(str(a))
			if st >= 0 and not styles.has(st):
				styles.append(st)
		var r = _FixtureBudgetRuleScript.new(
			_FixturePlacementModeScript.Mode.WALL,
			l.wall.min_count,
			l.wall.max_count,
			_FixtureBudgetRuleScript.Affinity.PERIMETER,
			styles,
			&"wall_slot"
		)
		r.target_fixture_ids = f_ids
		result.append(r)

	if l.floor != null and (l.floor.min_count > 0 or l.floor.max_count > 0):
		var styles: Array[int] = []
		var f_ids: Array[StringName] = []
		for a in l.floor.allowed:
			f_ids.append(StringName(str(a)))
			var st = _fixture_style_from_name(str(a))
			if st >= 0 and not styles.has(st):
				styles.append(st)
		var r = _FixtureBudgetRuleScript.new(
			_FixturePlacementModeScript.Mode.FLOOR,
			l.floor.min_count,
			l.floor.max_count,
			_FixtureBudgetRuleScript.Affinity.FREE,
			styles,
			&"floor_slot"
		)
		r.target_fixture_ids = f_ids
		result.append(r)

	if l.hanging != null and (l.hanging.min_count > 0 or l.hanging.max_count > 0):
		var styles: Array[int] = []
		var f_ids: Array[StringName] = []
		for a in l.hanging.allowed:
			f_ids.append(StringName(str(a)))
			var st = _fixture_style_from_name(str(a))
			if st >= 0 and not styles.has(st):
				styles.append(st)
		var r = _FixtureBudgetRuleScript.new(
			_FixturePlacementModeScript.Mode.HANGING,
			l.hanging.min_count,
			l.hanging.max_count,
			_FixtureBudgetRuleScript.Affinity.FOCAL_COMPANION,
			styles,
			&"hanging_slot"
		)
		r.target_fixture_ids = f_ids
		result.append(r)

	return result


static func _fixture_style_from_name(name_str: String) -> int:
	match name_str.to_lower():
		"wall_torch", "torch":
			return _FixtureStyleScript.Type.TORCH
		"wall_lantern", "hanging_lantern", "lantern":
			return _FixtureStyleScript.Type.LANTERN
		"brazier":
			return _FixtureStyleScript.Type.BRAZIER
		"candle_holder":
			return _FixtureStyleScript.Type.CANDLE_HOLDER
		"candle_cluster":
			return _FixtureStyleScript.Type.CANDLE_CLUSTER
	return -1

static func _style_has_tag(style, tag: StringName) -> bool:
	for t in style.tags:
		if str(t).to_lower() == str(tag).to_lower():
			return true
	# Implicit type-based tag mappings for backward compat
	if str(tag).to_lower() == "burial" and (style.prop_type == _PropStyleScript.Type.SARCOPHAGUS or style.prop_type == _PropStyleScript.Type.TOMBSTONE or style.prop_type == _PropStyleScript.Type.URN):
		return true
	if str(tag).to_lower() == "focal" and (style.role == _DecorationRoleScript.Role.FOCAL or style.prop_type == _PropStyleScript.Type.SARCOPHAGUS or style.prop_type == _PropStyleScript.Type.ALTAR):
		return true
	if str(tag).to_lower() == "seating" and style.prop_type == _PropStyleScript.Type.BENCH:
		return true
	if str(tag).to_lower() == "ceremonial" and style.prop_type == _PropStyleScript.Type.ALTAR:
		return true
	return false



func _build_scored_candidates(
	anchors: Array,
	target_entries: Array,
	rule,
	zones: Dictionary,
	intent,
	floor_cells_map: Dictionary,
	comp,
	occupancy,
	door_cells: Array[Vector2i],
	stair_cells: Array[Vector2i],
	room_center_cell: Vector2i,
	prop_seed_val: int,
	primary_cells: Array[Vector2i] = []
) -> Array[_DecorationPlacementCandidateScript]:
	var candidates: Array[_DecorationPlacementCandidateScript] = []

	for anchor in anchors:
		var zone = zones.get(anchor.cell, _DecorationRoomZoneScript.ZoneType.SIDE)
		if intent != null and not intent.can_place_in_zone(zone):
			continue

		for entry in target_entries:
			var style = entry.style
			if style == null:
				continue

			if style.placement_mode == _PropPlacementModeScript.Mode.WALL and anchor.mode != _PropPlacementModeScript.Mode.WALL:
				continue
			if style.placement_mode == _PropPlacementModeScript.Mode.CORNER and anchor.mode != _PropPlacementModeScript.Mode.CORNER:
				continue
			if style.placement_mode == _PropPlacementModeScript.Mode.CENTER and (anchor.mode != _PropPlacementModeScript.Mode.CENTER and anchor.mode != _PropPlacementModeScript.Mode.FLOOR):
				continue

			var foot_cells: Array[Vector2i] = []
			if style.footprint != null:
				foot_cells = style.footprint.get_occupied_cells(anchor.cell, anchor.rotation_degrees_y)
			else:
				foot_cells = [anchor.cell]

			var violations = _constraint.check_hard_constraints(
				foot_cells,
				floor_cells_map,
				comp.reserved_cells,
				occupancy.occupied_cells,
				door_cells,
				stair_cells
			)

			if violations.is_empty():
				var cand := _DecorationPlacementCandidateScript.new()
				cand.style_id = style.id
				cand.style = style
				cand.cell = anchor.cell
				cand.world_position = anchor.world_position + style.offset
				cand.rotation_y = _orientation_resolver.resolve_rotation(anchor, rule.orientation_mode)
				cand.occupied_cells = foot_cells
				cand.score = _scorer.score_candidate(
					cand,
					rule.composition_role,
					occupancy,
					room_center_cell,
					door_cells,
					prop_seed_val,
					primary_cells
				)
				candidates.append(cand)

	return candidates

static func _extract_prop_seed(seed_ctx) -> int:
	if seed_ctx is int:
		return seed_ctx
	if seed_ctx is Dictionary:
		return int(seed_ctx.get("prop_seed", 1337))
	if seed_ctx != null:
		if "prop_seed" in seed_ctx:
			return int(seed_ctx.prop_seed)
		if seed_ctx.has_meta("prop_seed"):
			return int(seed_ctx.get_meta("prop_seed"))
	return 1337

static func _extract_fixture_seed(seed_ctx) -> int:
	if seed_ctx is int:
		return seed_ctx
	if seed_ctx is Dictionary:
		return int(seed_ctx.get("fixture_seed", 1337))
	if seed_ctx != null:
		if "fixture_seed" in seed_ctx:
			return int(seed_ctx.fixture_seed)
		if seed_ctx.has_meta("fixture_seed"):
			return int(seed_ctx.get_meta("fixture_seed"))
	return 1337

static func _find_matching_palette_entries(entries: Array, rule, intent) -> Array:
	var result: Array = []
	var use_new_tags: bool = ("required_tags" in rule and not rule.required_tags.is_empty()) or ("forbidden_tags" in rule and not rule.forbidden_tags.is_empty())

	for entry in entries:
		var style = entry.style
		if style == null:
			continue

		# 1. Intent-level forbidden tags (room-wide exclusion)
		if intent != null and not style.tags.is_empty():
			var has_forbidden: bool = false
			for tag in style.tags:
				if intent.forbidden_tags.has(tag):
					has_forbidden = true
					break
			if has_forbidden:
				continue

		# 2. Rule-level forbidden tags
		# 2. Check forbidden tags first (hard exclusion)
		if "forbidden_tags" in rule and not rule.forbidden_tags.is_empty():
			var has_forbidden: bool = false
			for tag in rule.forbidden_tags:
				if _style_has_tag(style, tag):
					has_forbidden = true
					break
			if has_forbidden:
				continue

		# 3. Direct style_id match (highest priority)
		if not rule.target_style_ids.is_empty():
			if rule.target_style_ids.has(style.id):
				result.append(entry)
			continue

		# 4. New strict tag system: required_tags use AND logic
		if use_new_tags:
			if "required_tags" in rule and not rule.required_tags.is_empty():
				var all_required_met: bool = true
				for req_tag in rule.required_tags:
					if not _style_has_tag(style, req_tag):
						all_required_met = false
						break
				if not all_required_met:
					continue
			result.append(entry)
			continue

		# 5. Legacy: target_tags use OR logic (backward compat)
		if not rule.target_tags.is_empty():
			var matched_tag: bool = false
			for tag in rule.target_tags:
				if _style_has_tag(style, tag):
					matched_tag = true
					break
			if matched_tag:
				result.append(entry)
			# NO FALLBACK — if tags don't match, entry is excluded
			continue

		# 6. Unconstrained rule (no tags at all) — accept entry
		result.append(entry)

	return result

func _discover_anchors_for_rule(rule, room_geometry, tile_size: float) -> Array:

	# Si la regla declara explícitamente placement_mode, usarlo directamente
	if rule != null and "placement_mode" in rule and rule.placement_mode >= 0:
		match rule.placement_mode:
			_PropPlacementModeScript.Mode.WALL:
				return _anchor_resolver.find_wall_anchors(room_geometry, tile_size)
			_PropPlacementModeScript.Mode.CENTER:
				var centers = _anchor_resolver.find_center_anchors(room_geometry, tile_size)
				if not centers.is_empty():
					return centers
				return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
			_PropPlacementModeScript.Mode.CORNER:
				return _anchor_resolver.find_corner_anchors(room_geometry, tile_size)
			_PropPlacementModeScript.Mode.FLOOR:
				return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)

	# Fallback: usar composition_role para inferir tipo de anclaje
	var combined: Array = []
	match rule.composition_role:
		_CompositionRoleScript.Role.PRIMARY:
			var centers = _anchor_resolver.find_center_anchors(room_geometry, tile_size)
			if not centers.is_empty():
				return centers
			return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
		_CompositionRoleScript.Role.SECONDARY, _CompositionRoleScript.Role.COMPANION, _CompositionRoleScript.Role.DETAIL:
			var walls = _anchor_resolver.find_wall_anchors(room_geometry, tile_size)
			var corners = _anchor_resolver.find_corner_anchors(room_geometry, tile_size)
			var floors = _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
			combined.append_array(walls)
			combined.append_array(corners)
			combined.append_array(floors)
			return combined
		_:
			return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)

static func _calculate_clearance_ring(occupied: Array[Vector2i], clearance_radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var occ_map: Dictionary = {}
	for c in occupied:
		occ_map[c] = true

	for c in occupied:
		for dx in range(-clearance_radius, clearance_radius + 1):
			for dy in range(-clearance_radius, clearance_radius + 1):
				var neighbor := Vector2i(c.x + dx, c.y + dy)
				if not occ_map.has(neighbor) and not result.has(neighbor):
					result.append(neighbor)
	return result
