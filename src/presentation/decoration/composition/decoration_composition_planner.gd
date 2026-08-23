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
const _PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const _DecorationTagScript = preload("res://src/presentation/decoration/composition/decoration_tag.gd")

var _anchor_resolver := _PropAnchorResolverScript.new()
var _scorer := _DecorationPlacementScorerScript.new()
var _orientation_resolver := _DecorationOrientationResolverScript.new()
var _zone_partitioner := _DecorationRoomZoneScript.new()
var _purpose_registry := _DecorationPurposeProfileRegistryScript.new()
var _relationship_solver := _DecorationRelationshipSolverScript.new()
var _lighting_planner := _DecorationLightingPlannerScript.new()
var _constraint := _DecorationPlacementConstraintScript.new()

func plan_room_composition(
	profile = null, # DecorationCompositionProfile (opcional, si es null se resolverá de purpose_registry)
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

	# 2. Extraer o resolver el perfil de propósito
	var purpose_type: int = 0
	if room_context is Dictionary:
		purpose_type = int(room_context.get("purpose", room_context.get("room_purpose", 0)))
	elif room_context != null and "purpose" in room_context:
		purpose_type = int(room_context.purpose)
	elif room_context != null and "room_purpose" in room_context:
		purpose_type = int(room_context.room_purpose)

	var purpose_profile = _purpose_registry.get_profile_for_purpose(purpose_type)
	var intent = purpose_profile.intent if purpose_profile != null else null

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

	# 4. Extraer reglas (desde profile, templates de purpose_profile, o fallback)
	var rules_to_execute: Array = []
	if profile != null and not profile.rules.is_empty():
		rules_to_execute = profile.rules.duplicate()
	elif purpose_profile != null and not purpose_profile.templates.is_empty():
		for t in purpose_profile.templates:
			rules_to_execute.append_array(t.get_all_rules())

	var max_allowed: int = profile.max_total_props if profile != null else 8
	var total_placed: int = 0
	var primary_placed_cells: Array[Vector2i] = []

	if not rules_to_execute.is_empty() and palette.props != null:
		rules_to_execute.sort_custom(func(a, b): return a.composition_role < b.composition_role)

		for rule in rules_to_execute:
			if total_placed >= max_allowed:
				break

			var target_entries: Array = _find_matching_palette_entries(palette.props.entries, rule, intent)
			if target_entries.is_empty():
				continue

			var target_count: int = mini(rule.max_count, max_allowed - total_placed)
			var placed_for_rule: int = 0

			# Descubrir anclajes según el modo
			var anchors: Array = _discover_anchors_for_rule(rule, room_geometry, tile_size)
			if anchors.is_empty():
				continue

			# Generar y evaluar candidatos
			var candidates: Array[_DecorationPlacementCandidateScript] = []

			for anchor in anchors:
				# Validar zona funcional
				var zone = zones.get(anchor.cell, _DecorationRoomZoneScript.ZoneType.SIDE)
				if intent != null and not intent.can_place_in_zone(zone):
					continue

				for entry in target_entries:
					var style = entry.style
					if style == null:
						continue

					# Validar correspondencia entre el modo del anclaje y el modo requerido por el prop
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
							seed_ctx.prop_seed if seed_ctx != null else 1337
						)
						candidates.append(cand)

			# Ordenar candidatos por mejor puntaje
			candidates.sort_custom(func(a, b): return a.score > b.score)

			for cand in candidates:
				if placed_for_rule >= target_count or total_placed >= max_allowed:
					break

				if occupancy.add_footprint(cand.occupied_cells, cand.style_id, 0):
					if rule.clearance > 0:
						var clear_cells := _calculate_clearance_ring(cand.occupied_cells, rule.clearance)
						occupancy.add_clearance(clear_cells, cand.style_id)

					var dir := _PropDirectiveScript.new(
						cand.style_id,
						room_id,
						cand.style,
						cand.world_position,
						cand.rotation_y,
						cand.occupied_cells,
						cand.style.placement_mode if cand.style != null else _PropPlacementModeScript.Mode.FLOOR,
						cand.style.collision_mode if cand.style != null else 0
					)
					if comp.add_prop_directive(dir):
						placed_for_rule += 1
						total_placed += 1
						if rule.composition_role == _CompositionRoleScript.Role.PRIMARY:
							primary_placed_cells.append_array(cand.occupied_cells)

	# 5. Planificar iluminación inteligente por presupuesto y roles
	if palette.fixtures != null:
		var budget: float = profile.lighting_budget if profile != null else (purpose_profile.default_lighting_budget if purpose_profile != null else 5.0)
		var light_dirs = _lighting_planner.plan_room_lighting(
			budget,
			intent,
			palette.fixtures,
			primary_placed_cells,
			room_geometry,
			occupancy,
			seed_ctx.fixture_seed if seed_ctx != null else 1337,
			tile_size
		)
		for f_dir in light_dirs:
			if not comp.reserved_cells.has(f_dir.cell):
				comp.add_fixture_directive(f_dir)

	return comp

static func _find_matching_palette_entries(entries: Array, rule, intent) -> Array:
	var result: Array = []
	for entry in entries:
		var style = entry.style
		if style == null:
			continue

		# 1. Filtrar por etiquetas prohibidas de la intención de sala
		if intent != null and not style.tags.is_empty():
			var has_forbidden: bool = false
			for tag in style.tags:
				if intent.forbidden_tags.has(tag):
					has_forbidden = true
					break
			if has_forbidden:
				continue

		# 2. Si la regla especifica target_style_ids, verificar coincidencia directa
		if not rule.target_style_ids.is_empty():
			if rule.target_style_ids.has(style.id):
				result.append(entry)
			continue

		# 3. Si la regla especifica target_tags, verificar si comparte algún tag o rol
		if not rule.target_tags.is_empty():
			var matched_tag: bool = false
			for tag in rule.target_tags:
				if style.tags.has(tag):
					matched_tag = true
					break
				if tag == _DecorationTagScript.BURIAL and (style.prop_type == _PropStyleScript.Type.SARCOPHAGUS or style.prop_type == _PropStyleScript.Type.TOMBSTONE or style.prop_type == _PropStyleScript.Type.URN):
					matched_tag = true
					break
				if tag == _DecorationTagScript.FOCAL and (style.role == _DecorationRoleScript.Role.FOCAL or style.prop_type == _PropStyleScript.Type.SARCOPHAGUS or style.prop_type == _PropStyleScript.Type.ALTAR):
					matched_tag = true
					break
				if tag == _DecorationTagScript.SEATING and style.prop_type == _PropStyleScript.Type.BENCH:
					matched_tag = true
					break
			if matched_tag:
				result.append(entry)
			continue

		# 4. Fallback: aceptar entry
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
