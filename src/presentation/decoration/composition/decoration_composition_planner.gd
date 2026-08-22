class_name DecorationCompositionPlanner
extends RefCounted

## Planificador inteligente y determinista de composición espacial para habitaciones de mazmorra.
## Ejecuta la composición por perfiles y reglas declarativas (Generic Intelligent Decoration System):
## 1. Reservas estructurales y despejes (puertas, escaleras).
## 2. Evaluación de reglas por orden de rol (PRIMARY -> SECONDARY -> COMPANION -> LIGHTING -> DETAIL).
## 3. Generación y filtrado estricto de candidatos (Hard Constraints).
## 4. Puntuación heurística determinista (Scoring) y selección del mejor candidato.
## 5. Registro unificado en DecorationOccupancyMap (Huellas y Despejes).
## 6. Emisión de DecorationComposition sin modificar CellGrid.

const _DecorationCompositionScript = preload("res://src/presentation/decoration/decoration_composition.gd")
const _DecorationOccupancyMapScript = preload("res://src/presentation/decoration/composition/decoration_occupancy_map.gd")
const _DecorationPlacementConstraintScript = preload("res://src/presentation/decoration/composition/decoration_placement_constraint.gd")
const _DecorationPlacementCandidateScript = preload("res://src/presentation/decoration/composition/decoration_placement_candidate.gd")
const _DecorationPlacementScorerScript = preload("res://src/presentation/decoration/composition/decoration_placement_scorer.gd")
const _DecorationOrientationResolverScript = preload("res://src/presentation/decoration/composition/decoration_orientation_resolver.gd")
const _PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _FixtureResolverScript = preload("res://src/presentation/fixtures/fixture_resolver.gd")
const _CompositionRoleScript = preload("res://src/presentation/decoration/composition/composition_role.gd")

var _anchor_resolver := _PropAnchorResolverScript.new()
var _scorer := _DecorationPlacementScorerScript.new()
var _orientation_resolver := _DecorationOrientationResolverScript.new()
var _fixture_resolver := _FixtureResolverScript.new()
var _constraint := _DecorationPlacementConstraintScript.new()

func plan_room_composition(
	profile, # DecorationCompositionProfile
	palette, # DecorationPalette
	room_geometry,
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

	# 1. Aplicar reservas estructurales en el mapa de ocupación
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

	# 2. Ejecutar reglas de composición de props si existe perfil
	if profile != null and not profile.rules.is_empty() and palette.props != null:
		var sorted_rules: Array = profile.rules.duplicate()
		sorted_rules.sort_custom(func(a, b): return a.composition_role < b.composition_role)

		var total_placed: int = 0
		var max_allowed: int = profile.max_total_props

		for rule in sorted_rules:
			if total_placed >= max_allowed:
				break

			var target_entries: Array = _find_matching_palette_entries(palette.props.entries, rule)
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
				for entry in target_entries:
					var style = entry.style
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
						cand.world_position = anchor.world_position
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
					# Añadir despeje si la regla lo exige
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

	# 3. Resolver fixtures arquitectónicos respetando el mapa de ocupación
	if palette.fixtures != null and partition != null and room_context != null:
		var fix_dirs = _fixture_resolver.resolve_room_fixtures(
			room_context,
			partition,
			palette.fixtures,
			seed_ctx.fixture_seed if seed_ctx != null else 1337,
			tile_size
		)
		if fix_dirs != null:
			for f_dir in fix_dirs:
				# Evitar colocar antorchas o faroles sobre celdas bloqueadas por despeje de puertas
				if not comp.reserved_cells.has(f_dir.cell):
					comp.add_fixture_directive(f_dir)

	return comp

static func _find_matching_palette_entries(entries: Array, rule) -> Array:
	var result: Array = []
	for entry in entries:
		var style = entry.style
		if style == null:
			continue

		if not rule.target_style_ids.is_empty():
			if rule.target_style_ids.has(style.id):
				result.append(entry)
		elif not rule.target_tags.is_empty():
			result.append(entry)
		else:
			result.append(entry)
	return result

func _discover_anchors_for_rule(rule, room_geometry, tile_size: float) -> Array:
	match rule.composition_role:
		_CompositionRoleScript.Role.PRIMARY:
			var centers = _anchor_resolver.find_center_anchors(room_geometry, tile_size)
			if not centers.is_empty():
				return centers
			return _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
		_CompositionRoleScript.Role.SECONDARY, _CompositionRoleScript.Role.COMPANION:
			var walls = _anchor_resolver.find_wall_anchors(room_geometry, tile_size)
			var corners = _anchor_resolver.find_corner_anchors(room_geometry, tile_size)
			var combined: Array = []
			combined.append_array(walls)
			combined.append_array(corners)
			return combined
		_:
			return _anchor_resolver.find_corner_anchors(room_geometry, tile_size)

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
