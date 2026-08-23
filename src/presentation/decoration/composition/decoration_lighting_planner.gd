class_name DecorationLightingPlanner
extends RefCounted

## Planificador inteligente de iluminación arquitectónica gobernado por presupuestos de energía y roles espaciales.

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixtureAnchorResolverScript = preload("res://src/presentation/fixtures/fixture_anchor_resolver.gd")
const _FixtureBudgetRuleScript = preload("res://src/presentation/decoration/composition/fixture_budget_rule.gd")

var _anchor_resolver := _FixtureAnchorResolverScript.new()

enum LightRole {
	PRIMARY_LIGHT = 0,    ## Luz ambiental principal / antorchas perimetrales
	SECONDARY_LIGHT = 1,  ## Faroles de apoyo
	ACCENT_LIGHT = 2,     ## Velas o luces sutiles de detalle
	CEREMONIAL_LIGHT = 3  ## Braseros o candeleros rituales
}

func plan_room_lighting(
	budget: float,
	intent, # DecorationRoomIntent
	fixture_palette, # FixturePalette
	primary_props: Array,
	room_geom,
	occupancy, # DecorationOccupancyMap
	seed_val: int,
	tile_size: float = 2.0,
	fixture_rules: Array = []
) -> Array:
	var result: Array = []

	if fixture_palette == null or fixture_palette.entries.is_empty() or room_geom == null:
		return result

	var room_id: int = room_geom.room_id if "room_id" in room_geom else 0

	var door_cells: Array[Vector2i] = []
	if "door_positions" in room_geom and room_geom.door_positions != null:
		for d in room_geom.door_positions:
			door_cells.append(d as Vector2i)
	elif "door_cells" in room_geom and room_geom.door_cells != null:
		for d in room_geom.door_cells:
			door_cells.append(d as Vector2i)

	var door_map: Dictionary = {}
	for d in door_cells:
		door_map[d] = true

	var occupied_cells_map: Dictionary = {}
	for f_dir in result:
		occupied_cells_map[f_dir.placement.cell] = true

	# Base allocation ratios por modo
	var wall_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.WALL)
	var floor_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.FLOOR)
	var hanging_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.HANGING)
	var surface_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.SURFACE)

	var has_wall: bool = not wall_entries.is_empty()
	var has_floor: bool = not floor_entries.is_empty()
	var has_hanging: bool = not hanging_entries.is_empty()
	var has_surface: bool = not surface_entries.is_empty()

	var wall_ratio: float = 0.45 if has_wall else 0.0
	var hanging_ratio: float = 0.20 if has_hanging else 0.0
	var floor_ratio: float = 0.20 if has_floor else 0.0
	var surface_ratio: float = 0.15 if has_surface else 0.0

	var total_ratio: float = wall_ratio + hanging_ratio + floor_ratio + surface_ratio
	if total_ratio > 0.0:
		var scale_factor: float = 1.0 / total_ratio
		wall_ratio *= scale_factor
		hanging_ratio *= scale_factor
		floor_ratio *= scale_factor
		surface_ratio *= scale_factor

	var mode_budgets: Dictionary = {
		_FixturePlacementModeScript.Mode.WALL: budget * wall_ratio,
		_FixturePlacementModeScript.Mode.HANGING: budget * hanging_ratio,
		_FixturePlacementModeScript.Mode.FLOOR: budget * floor_ratio,
		_FixturePlacementModeScript.Mode.SURFACE: budget * surface_ratio
	}

	var mode_costs: Dictionary = {
		_FixturePlacementModeScript.Mode.WALL: 0.0,
		_FixturePlacementModeScript.Mode.HANGING: 0.0,
		_FixturePlacementModeScript.Mode.FLOOR: 0.0,
		_FixturePlacementModeScript.Mode.SURFACE: 0.0
	}

	var mode_placed_counts: Dictionary = {
		_FixturePlacementModeScript.Mode.WALL: 0,
		_FixturePlacementModeScript.Mode.HANGING: 0,
		_FixturePlacementModeScript.Mode.FLOOR: 0,
		_FixturePlacementModeScript.Mode.SURFACE: 0
	}

	# === FASE 1: Ejecutar reglas con afinidad FOCAL_COMPANION ===
	if not primary_props.is_empty() and not fixture_rules.is_empty():
		for rule in fixture_rules:
			if rule == null or rule.affinity != 1: # Affinity.FOCAL_COMPANION = 1
				continue

			var matching_entries = _filter_entries_for_rule(fixture_palette, rule)
			if matching_entries.is_empty():
				continue

			var focal_anchors = _anchor_resolver.find_focal_companion_anchors(
				primary_props,
				room_geom,
				rule.placement_mode,
				tile_size
			)

			var placed_for_rule: int = 0
			for anchor in focal_anchors:
				if placed_for_rule >= rule.max_count:
					break
				if occupied_cells_map.has(anchor.cell):
					continue
				if rule.placement_mode == _FixturePlacementModeScript.Mode.FLOOR and occupancy != null and occupancy.is_cell_occupied(anchor.cell):
					continue

				var entry = matching_entries[(placed_for_rule + seed_val) % matching_entries.size()]
				var style: _FixtureStyleScript = entry.style
				var cost: float = _get_style_cost(style)
				var mode: int = rule.placement_mode
				var m_budget: float = mode_budgets.get(mode, budget)
				var m_cost: float = mode_costs.get(mode, 0.0)

				if placed_for_rule < rule.min_count or (m_cost + cost <= m_budget) or m_cost == 0.0:
					var a_pos: Vector3 = anchor.position if "position" in anchor else (anchor.world_position if "world_position" in anchor else Vector3.ZERO)
					var normal := Vector3.DOWN if mode == _FixturePlacementModeScript.Mode.HANGING else Vector3.UP
					var pl := _FixturePlacementScript.new(
						mode,
						anchor.cell,
						-1,
						a_pos,
						anchor.rotation_y if "rotation_y" in anchor else 0.0,
						normal
					)
					var f_dir := _FixtureDirectiveScript.new(
						style.id,
						room_id,
						style,
						pl,
						style.scale
					)
					result.append(f_dir)
					occupied_cells_map[anchor.cell] = true
					placed_for_rule += 1
					mode_costs[mode] = m_cost + cost
					mode_placed_counts[mode] = mode_placed_counts.get(mode, 0) + 1

	# === FASE 2: Ejecutar reglas PERIMETER y FREE / Ambientales ===
	var non_focal_rules: Array = []
	for r in fixture_rules:
		if r != null and r.affinity != 1:
			non_focal_rules.append(r)

	# Si no hay reglas declaradas, generar reglas por defecto por modo
	if non_focal_rules.is_empty():
		if has_wall:
			non_focal_rules.append(_create_default_rule(_FixturePlacementModeScript.Mode.WALL, 1, 999))
		if has_floor:
			non_focal_rules.append(_create_default_rule(_FixturePlacementModeScript.Mode.FLOOR, 0, 999))
		if has_hanging:
			non_focal_rules.append(_create_default_rule(_FixturePlacementModeScript.Mode.HANGING, 0, 999))
		if has_surface:
			non_focal_rules.append(_create_default_rule(_FixturePlacementModeScript.Mode.SURFACE, 0, 999))

	for rule in non_focal_rules:
		var mode: int = rule.placement_mode
		var matching_entries = _filter_entries_for_rule(fixture_palette, rule)
		if matching_entries.is_empty():
			continue

		var m_budget: float = mode_budgets.get(mode, budget)
		var m_cost: float = mode_costs.get(mode, 0.0)
		var placed_for_rule: int = 0

		match mode:
			_FixturePlacementModeScript.Mode.WALL:
				var wall_anchors = _anchor_resolver.find_wall_anchors(room_geom, tile_size)
				var valid_wall_anchors: Array = []
				for wa in wall_anchors:
					if not door_map.has(wa.cell) and not occupied_cells_map.has(wa.cell):
						valid_wall_anchors.append(wa)

				var chosen_anchors = _select_balanced_wall_anchors(valid_wall_anchors, rule.max_count, seed_val)
				for anchor in chosen_anchors:
					if placed_for_rule >= rule.max_count:
						break
					if placed_for_rule >= rule.min_count and m_cost >= m_budget:
						break

					var entry = matching_entries[(placed_for_rule + seed_val) % matching_entries.size()]
					var style: _FixtureStyleScript = entry.style
					var cost: float = _get_style_cost(style)

					if placed_for_rule < rule.min_count or (m_cost + cost <= m_budget) or m_cost == 0.0:
						var a_pos: Vector3 = anchor.position if "position" in anchor else (anchor.world_position if "world_position" in anchor else Vector3.ZERO)
						var pl := _FixturePlacementScript.new(
							_FixturePlacementModeScript.Mode.WALL,
							anchor.cell,
							anchor.wall_side if "wall_side" in anchor else -1,
							a_pos,
							anchor.rotation_y,
							Vector3.UP
						)
						var f_dir := _FixtureDirectiveScript.new(style.id, room_id, style, pl, style.scale)
						result.append(f_dir)
						occupied_cells_map[anchor.cell] = true
						m_cost += cost
						mode_costs[mode] = m_cost
						placed_for_rule += 1
						mode_placed_counts[mode] = mode_placed_counts.get(mode, 0) + 1

			_FixturePlacementModeScript.Mode.FLOOR:
				var floor_anchors = _anchor_resolver.find_floor_anchors(room_geom, tile_size)
				var floor_spacing: int = 4
				for i in range(0, floor_anchors.size(), floor_spacing):
					if placed_for_rule >= rule.max_count:
						break
					if placed_for_rule >= rule.min_count and m_cost >= m_budget:
						break
					var fa = floor_anchors[i]
					if door_map.has(fa.cell) or occupied_cells_map.has(fa.cell):
						continue
					if occupancy != null and occupancy.is_cell_occupied(fa.cell):
						continue

					var entry = matching_entries[(i + seed_val) % matching_entries.size()]
					var style: _FixtureStyleScript = entry.style
					var cost: float = _get_style_cost(style)

					if placed_for_rule < rule.min_count or (m_cost + cost <= m_budget) or m_cost == 0.0:
						var fa_pos: Vector3 = fa.position if "position" in fa else (fa.world_position if "world_position" in fa else Vector3.ZERO)
						var pl := _FixturePlacementScript.new(
							_FixturePlacementModeScript.Mode.FLOOR,
							fa.cell,
							-1,
							fa_pos,
							fa.rotation_y,
							Vector3.UP
						)
						var f_dir := _FixtureDirectiveScript.new(style.id, room_id, style, pl, style.scale)
						result.append(f_dir)
						occupied_cells_map[fa.cell] = true
						m_cost += cost
						mode_costs[mode] = m_cost
						placed_for_rule += 1
						mode_placed_counts[mode] = mode_placed_counts.get(mode, 0) + 1

			_FixturePlacementModeScript.Mode.HANGING:
				var hanging_anchors = _anchor_resolver.find_hanging_anchors(room_geom, tile_size)
				var hanging_spacing: int = 4
				for i in range(0, hanging_anchors.size(), hanging_spacing):
					if placed_for_rule >= rule.max_count:
						break
					if placed_for_rule >= rule.min_count and m_cost >= m_budget:
						break
					var ha = hanging_anchors[i]
					if door_map.has(ha.cell) or occupied_cells_map.has(ha.cell):
						continue

					var entry = matching_entries[(i + seed_val) % matching_entries.size()]
					var style: _FixtureStyleScript = entry.style
					var cost: float = _get_style_cost(style)

					if placed_for_rule < rule.min_count or (m_cost + cost <= m_budget) or m_cost == 0.0:
						var ha_pos: Vector3 = ha.position if "position" in ha else (ha.world_position if "world_position" in ha else Vector3.ZERO)
						var pl := _FixturePlacementScript.new(
							_FixturePlacementModeScript.Mode.HANGING,
							ha.cell,
							-1,
							ha_pos,
							ha.rotation_y,
							Vector3.DOWN
						)
						var f_dir := _FixtureDirectiveScript.new(style.id, room_id, style, pl, style.scale)
						result.append(f_dir)
						occupied_cells_map[ha.cell] = true
						m_cost += cost
						mode_costs[mode] = m_cost
						placed_for_rule += 1
						mode_placed_counts[mode] = mode_placed_counts.get(mode, 0) + 1

			_FixturePlacementModeScript.Mode.SURFACE:
				var surface_anchors = _anchor_resolver.find_surface_anchors(room_geom, tile_size)
				var surface_spacing: int = 5
				for i in range(0, surface_anchors.size(), surface_spacing):
					if placed_for_rule >= rule.max_count:
						break
					if placed_for_rule >= rule.min_count and m_cost >= m_budget:
						break
					var sa = surface_anchors[i]
					if door_map.has(sa.cell) or occupied_cells_map.has(sa.cell):
						continue
					if occupancy != null and occupancy.is_cell_occupied(sa.cell):
						continue

					var entry = matching_entries[(i + seed_val) % matching_entries.size()]
					var style: _FixtureStyleScript = entry.style
					var cost: float = _get_style_cost(style)

					if placed_for_rule < rule.min_count or (m_cost + cost <= m_budget) or m_cost == 0.0:
						var sa_pos: Vector3 = sa.position if "position" in sa else (sa.world_position if "world_position" in sa else Vector3.ZERO)
						var pl := _FixturePlacementScript.new(
							_FixturePlacementModeScript.Mode.SURFACE,
							sa.cell,
							-1,
							sa_pos,
							sa.rotation_y,
							Vector3.UP
						)
						var f_dir := _FixtureDirectiveScript.new(style.id, room_id, style, pl, style.scale)
						result.append(f_dir)
						occupied_cells_map[sa.cell] = true
						m_cost += cost
						mode_costs[mode] = m_cost
						placed_for_rule += 1
						mode_placed_counts[mode] = mode_placed_counts.get(mode, 0) + 1

	return result

static func _filter_entries_for_rule(palette, rule) -> Array:
	var mode: int = rule.placement_mode if rule != null else _FixturePlacementModeScript.Mode.WALL
	var mode_entries: Array = palette.get_entries_for_placement(mode)
	if rule == null:
		return mode_entries

	var result: Array = []
	for entry in mode_entries:
		var style: _FixtureStyleScript = entry.style
		if style == null:
			continue

		if "target_fixture_ids" in rule and not rule.target_fixture_ids.is_empty():
			if rule.target_fixture_ids.has(style.id):
				result.append(entry)
			continue

		if "target_fixture_types" in rule and not rule.target_fixture_types.is_empty():
			if rule.target_fixture_types.has(style.fixture_type):
				result.append(entry)
			continue

		result.append(entry)

	return result

static func _create_default_rule(mode: int, p_min: int, p_max: int) -> _FixtureBudgetRuleScript:
	return _FixtureBudgetRuleScript.new(mode, p_min, p_max)

static func _select_balanced_wall_anchors(valid_wall_anchors: Array, target_count: int, seed_val: int) -> Array:
	if valid_wall_anchors.is_empty() or target_count <= 0:
		return []

	# Agrupar anclajes por lado de muro (0=NORTH, 1=EAST, 2=SOUTH, 3=WEST)
	var by_side: Dictionary = {
		0: [],
		1: [],
		2: [],
		3: []
	}

	for wa in valid_wall_anchors:
		var side: int = wa.wall_side if "wall_side" in wa else -1
		if by_side.has(side):
			by_side[side].append(wa)
		else:
			by_side[0].append(wa)

	# Ordenar anclajes a lo largo de cada línea de muro
	by_side[0].sort_custom(func(a, b): return a.cell.x < b.cell.x)
	by_side[2].sort_custom(func(a, b): return a.cell.x < b.cell.x)
	by_side[1].sort_custom(func(a, b): return a.cell.y < b.cell.y)
	by_side[3].sort_custom(func(a, b): return a.cell.y < b.cell.y)

	var active_sides: Array = []
	# Prioridad de lados: pares opuestos primero [NORTH, SOUTH, EAST, WEST] rotados con la semilla
	var side_order: Array = [0, 2, 1, 3]
	var rot: int = seed_val % 4
	for k in range(4):
		var s: int = side_order[(k + rot) % 4]
		if not by_side[s].is_empty():
			active_sides.append(s)

	if active_sides.is_empty():
		return valid_wall_anchors.slice(0, target_count)

	var selected: Array = []

	# Pase 1: Un anclaje central por cada lado disponible
	for s in active_sides:
		if selected.size() >= target_count:
			break
		var arr: Array = by_side[s]
		var mid_idx: int = arr.size() / 2
		selected.append(arr[mid_idx])
		arr.remove_at(mid_idx)

	# Pase 2: Distribuir anclajes adicionales entre los lados que aún tengan espacio
	var round_idx: int = 0
	var attempts: int = 0
	while selected.size() < target_count and attempts < 100:
		attempts += 1
		var s: int = active_sides[round_idx % active_sides.size()]
		var arr: Array = by_side[s]
		if not arr.is_empty():
			var pick_idx: int = arr.size() / 2
			selected.append(arr[pick_idx])
			arr.remove_at(pick_idx)
		round_idx += 1

		var any_left: bool = false
		for sid in active_sides:
			if not by_side[sid].is_empty():
				any_left = true
				break
		if not any_left:
			break

	return selected

func _get_style_cost(style: _FixtureStyleScript) -> float:
	if style == null:
		return 1.0
	match style.fixture_type:
		_FixtureStyleScript.Type.TORCH:
			return 1.0
		_FixtureStyleScript.Type.LANTERN:
			return 1.5
		_FixtureStyleScript.Type.BRAZIER:
			return 2.0
		_FixtureStyleScript.Type.CANDLE_HOLDER, _FixtureStyleScript.Type.CANDLE_CLUSTER:
			return 0.5
		_:
			return 1.0
