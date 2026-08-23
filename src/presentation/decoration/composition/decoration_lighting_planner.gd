class_name DecorationLightingPlanner
extends RefCounted

## Planificador inteligente de iluminación arquitectónica gobernado por presupuestos de energía y roles espaciales.

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixtureAnchorResolverScript = preload("res://src/presentation/fixtures/fixture_anchor_resolver.gd")

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
	tile_size: float = 2.0
) -> Array:
	var result: Array = []

	if fixture_palette == null or fixture_palette.entries.is_empty() or room_geom == null:
		return result

	var current_cost: float = 0.0
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

	var wall_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.WALL)
	var floor_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.FLOOR)
	var hanging_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.HANGING)
	var surface_entries = fixture_palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.SURFACE)

	var has_other_modes: bool = not floor_entries.is_empty() or not hanging_entries.is_empty() or not surface_entries.is_empty()
	var wall_budget_limit: float = budget * 0.65 if has_other_modes else budget

	# 1. Resolver luminarias de pared (WALL)
	if not wall_entries.is_empty() and current_cost < wall_budget_limit:
		var wall_anchors = _anchor_resolver.find_wall_anchors(room_geom, tile_size)
		# Filtrar puertas
		var valid_wall_anchors: Array = []
		for wa in wall_anchors:
			if not door_map.has(wa.cell):
				valid_wall_anchors.append(wa)

		# Espaciado regular y selección determinista
		var spacing: int = 3
		for i in range(0, valid_wall_anchors.size(), spacing):
			if current_cost >= wall_budget_limit:
				break

			var anchor = valid_wall_anchors[i]
			var entry = wall_entries[(i + seed_val) % wall_entries.size()]
			var style: _FixtureStyleScript = entry.style
			var cost: float = _get_style_cost(style)

			if current_cost + cost <= budget:
				var a_pos: Vector3 = anchor.position if "position" in anchor else (anchor.world_position if "world_position" in anchor else Vector3.ZERO)
				var pl := _FixturePlacementScript.new(
					_FixturePlacementModeScript.Mode.WALL,
					anchor.cell,
					anchor.wall_side if "wall_side" in anchor else -1,
					a_pos,
					anchor.rotation_y,
					Vector3.UP
				)
				var f_dir := _FixtureDirectiveScript.new(
					style.id,
					room_id,
					style,
					pl,
					style.scale
				)
				result.append(f_dir)
				current_cost += cost

	# 2. Resolver luminarias de suelo (FLOOR / Ceremoniales)
	if not floor_entries.is_empty() and current_cost < budget:
		var floor_anchors = _anchor_resolver.find_floor_anchors(room_geom, tile_size)
		var floor_spacing: int = 4
		for i in range(0, floor_anchors.size(), floor_spacing):
			if current_cost >= budget:
				break
			var fa = floor_anchors[i]
			if door_map.has(fa.cell):
				continue
			if occupancy != null and occupancy.is_cell_occupied(fa.cell):
				continue

			var entry = floor_entries[(i + seed_val) % floor_entries.size()]
			var style: _FixtureStyleScript = entry.style
			var cost: float = _get_style_cost(style)

			if current_cost + cost <= budget:
				var fa_pos: Vector3 = fa.position if "position" in fa else (fa.world_position if "world_position" in fa else Vector3.ZERO)
				var pl := _FixturePlacementScript.new(
					_FixturePlacementModeScript.Mode.FLOOR,
					fa.cell,
					-1,
					fa_pos,
					fa.rotation_y,
					Vector3.UP
				)
				var f_dir := _FixtureDirectiveScript.new(
					style.id,
					room_id,
					style,
					pl,
					style.scale
				)
				result.append(f_dir)
				current_cost += cost

	# 3. Resolver luminarias colgantes (HANGING)
	if not hanging_entries.is_empty() and current_cost < budget:
		var hanging_anchors = _anchor_resolver.find_hanging_anchors(room_geom, tile_size)
		var hanging_spacing: int = 4
		for i in range(0, hanging_anchors.size(), hanging_spacing):
			if current_cost >= budget:
				break
			var ha = hanging_anchors[i]
			if door_map.has(ha.cell):
				continue
			if occupancy != null and occupancy.is_cell_occupied(ha.cell):
				continue

			var entry = hanging_entries[(i + seed_val) % hanging_entries.size()]
			var style: _FixtureStyleScript = entry.style
			var cost: float = _get_style_cost(style)

			if current_cost + cost <= budget:
				var ha_pos: Vector3 = ha.position if "position" in ha else (ha.world_position if "world_position" in ha else Vector3.ZERO)
				var pl := _FixturePlacementScript.new(
					_FixturePlacementModeScript.Mode.HANGING,
					ha.cell,
					-1,
					ha_pos,
					ha.rotation_y,
					Vector3.DOWN
				)
				var f_dir := _FixtureDirectiveScript.new(
					style.id,
					room_id,
					style,
					pl,
					style.scale
				)
				result.append(f_dir)
				current_cost += cost

	# 4. Resolver luminarias de superficie (SURFACE)
	if not surface_entries.is_empty() and current_cost < budget:
		var surface_anchors = _anchor_resolver.find_surface_anchors(room_geom, tile_size)
		var surface_spacing: int = 5
		for i in range(0, surface_anchors.size(), surface_spacing):
			if current_cost >= budget:
				break
			var sa = surface_anchors[i]
			if door_map.has(sa.cell):
				continue
			if occupancy != null and occupancy.is_cell_occupied(sa.cell):
				continue

			var entry = surface_entries[(i + seed_val) % surface_entries.size()]
			var style: _FixtureStyleScript = entry.style
			var cost: float = _get_style_cost(style)

			if current_cost + cost <= budget:
				var sa_pos: Vector3 = sa.position if "position" in sa else (sa.world_position if "world_position" in sa else Vector3.ZERO)
				var pl := _FixturePlacementScript.new(
					_FixturePlacementModeScript.Mode.SURFACE,
					sa.cell,
					-1,
					sa_pos,
					sa.rotation_y,
					Vector3.UP
				)
				var f_dir := _FixtureDirectiveScript.new(
					style.id,
					room_id,
					style,
					pl,
					style.scale
				)
				result.append(f_dir)
				current_cost += cost

	return result

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
