class_name DecorationCompositionResolver
extends RefCounted

## Motor de composición espacial integral por roles y prioridades para habitaciones de mazmorra.
## Ejecuta la composición determinista en 5 capas de prioridad:
## Prioridad 0: Reservas estructurales y despejes de aproximación (puertas, escaleras).
## Prioridad 1: Elementos FOCAL (foco visual dominante).
## Prioridad 2: Elementos SUPPORT (apoyo y mobiliario complementario).
## Prioridad 3: Elementos AMBIENT (ambientación, escombros).
## Prioridad 4: Elementos FUNCTIONAL (cofres, mecanismos).
## Prioridad 5: Fixtures arquitectónicos complementarios.
## 100% puro: no crea nodos Node3D ni muta CellGrid.

const _DecorationCompositionScript = preload("res://src/presentation/decoration/decoration_composition.gd")
const _DecorationPaletteScript = preload("res://src/presentation/decoration/decoration_palette.gd")
const _DecorationRoleScript = preload("res://src/presentation/decoration/decoration_role.gd")
const _PresentationSeedContextScript = preload("res://src/presentation/architecture/presentation_seed_context.gd")
const _PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")
const _FixtureResolverScript = preload("res://src/presentation/fixtures/fixture_resolver.gd")
const _PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")

var _anchor_resolver := _PropAnchorResolverScript.new()
var _fixture_resolver := _FixtureResolverScript.new()

func resolve_room_composition(
	room_context,
	palette: _DecorationPaletteScript,
	room_geometry,
	partition = null,
	base_seed: int = 1337,
	tile_size: float = 2.0
) -> _DecorationCompositionScript:
	var room_id: int = room_context.room_id if room_context != null else -1
	var comp := _DecorationCompositionScript.new(room_id)

	if room_context == null or palette == null or room_geometry == null:
		return comp

	var seed_ctx := _PresentationSeedContextScript.for_room(base_seed, room_id)
	var floor_cells_map: Dictionary = {}
	for fc in room_geometry.floor_cells:
		floor_cells_map[fc] = true

	# ==========================================================================
	# PRIORIDAD 0 — RESERVAS ESTRUCTURALES Y DESPEJES DE ACCESO
	# ==========================================================================
	_apply_structural_reservations(comp, room_geometry)

	# ==========================================================================
	# COMPOSICIÓN DE PROPS (PRIORIDADES 1 A 4)
	# ==========================================================================
	if palette.props != null and not palette.props.entries.is_empty():
		var prop_pal = palette.props
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_ctx.prop_seed

		var max_props: int = prop_pal.max_props_per_room
		var current_props: int = 0

		# 1. PRIORIDAD 1: FOCAL PROPS (Altar central, Sarcófago, etc.)
		var focal_entries = _filter_entries_by_role(prop_pal.entries, _DecorationRoleScript.Role.FOCAL)
		if not focal_entries.is_empty():
			var center_anchors = _anchor_resolver.find_center_anchors(room_geometry, tile_size)
			for anchor in center_anchors:
				if current_props >= max_props:
					break
				var dir = _try_place_from_entry_list(anchor, focal_entries, room_id, floor_cells_map, comp, rng.randi(), tile_size)
				if dir != null:
					if comp.add_prop_directive(dir):
						current_props += 1
					else:
						comp.rejected_placements += 1

		# 2. PRIORIDAD 2: SUPPORT PROPS (Bancos, Librerías, Lápidas)
		var support_entries = _filter_entries_by_role(prop_pal.entries, _DecorationRoleScript.Role.SUPPORT)
		if not support_entries.is_empty():
			# Anclajes de muro primero
			var wall_anchors = _anchor_resolver.find_wall_anchors(room_geometry, tile_size)
			for anchor in wall_anchors:
				if current_props >= max_props:
					break
				if rng.randf() > prop_pal.density * 1.2:
					continue
				var dir = _try_place_from_entry_list(anchor, support_entries, room_id, floor_cells_map, comp, rng.randi(), tile_size)
				if dir != null:
					if comp.add_prop_directive(dir):
						current_props += 1
					else:
						comp.rejected_placements += 1

			# Anclajes de suelo para soporte restante
			var floor_anchors = _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
			for anchor in floor_anchors:
				if current_props >= max_props:
					break
				if rng.randf() > prop_pal.density:
					continue
				var dir = _try_place_from_entry_list(anchor, support_entries, room_id, floor_cells_map, comp, rng.randi(), tile_size)
				if dir != null:
					if comp.add_prop_directive(dir):
						current_props += 1
					else:
						comp.rejected_placements += 1

		# 3. PRIORIDAD 3: AMBIENT PROPS (Escombros, urnas en esquinas)
		var ambient_entries = _filter_entries_by_role(prop_pal.entries, _DecorationRoleScript.Role.AMBIENT)
		if not ambient_entries.is_empty():
			var corner_anchors = _anchor_resolver.find_corner_anchors(room_geometry, tile_size)
			for anchor in corner_anchors:
				if current_props >= max_props:
					break
				if rng.randf() > prop_pal.density * 1.5:
					continue
				var dir = _try_place_from_entry_list(anchor, ambient_entries, room_id, floor_cells_map, comp, rng.randi(), tile_size)
				if dir != null:
					if comp.add_prop_directive(dir):
						current_props += 1
					else:
						comp.rejected_placements += 1

		# 4. PRIORIDAD 4: FUNCTIONAL PROPS (Cofres)
		var functional_entries = _filter_entries_by_role(prop_pal.entries, _DecorationRoleScript.Role.FUNCTIONAL)
		if not functional_entries.is_empty():
			var corner_anchors = _anchor_resolver.find_corner_anchors(room_geometry, tile_size)
			for anchor in corner_anchors:
				if current_props >= max_props:
					break
				var dir = _try_place_from_entry_list(anchor, functional_entries, room_id, floor_cells_map, comp, rng.randi(), tile_size)
				if dir != null:
					if comp.add_prop_directive(dir):
						current_props += 1
					else:
						comp.rejected_placements += 1

	# ==========================================================================
	# PRIORIDAD 5 — FIXTURES ARQUITECTÓNICOS (Antorchas, Faroles, Braseros)
	# ==========================================================================
	if palette.fixtures != null and partition != null:
		var fix_dirs = _fixture_resolver.resolve_room_fixtures(
			room_context, partition, palette.fixtures, seed_ctx.fixture_seed, tile_size
		)
		for f_dir in fix_dirs:
			comp.add_fixture_directive(f_dir)

	return comp

func _apply_structural_reservations(comp: _DecorationCompositionScript, r_geom) -> void:
	if r_geom == null:
		return

	# Reservar despeje de puertas (3x3 alrededor de cada puerta)
	if "door_positions" in r_geom and r_geom.door_positions != null:
		for d_pos in r_geom.door_positions:
			comp.reserve_cell(d_pos, &"door")
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					comp.reserve_cell(d_pos + Vector2i(dx, dy), &"door_clearance")

	# Reservar despeje de escaleras
	var stairs_list: Array = []
	if "stairs_positions" in r_geom and r_geom.stairs_positions != null:
		stairs_list.append_array(r_geom.stairs_positions)
	if "stairs_cells" in r_geom and r_geom.stairs_cells != null:
		stairs_list.append_array(r_geom.stairs_cells)

	for s_pos in stairs_list:
		comp.reserve_cell(s_pos, &"stairs")
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				comp.reserve_cell(s_pos + Vector2i(dx, dy), &"stairs_clearance")

func _filter_entries_by_role(entries: Array, role: int) -> Array:
	var result: Array = []
	for entry in entries:
		if entry != null and entry.style != null and entry.style.role == role:
			result.append(entry)
	return result

func _try_place_from_entry_list(
	anchor,
	entries: Array,
	room_id: int,
	floor_cells_map: Dictionary,
	comp: _DecorationCompositionScript,
	seed_val: int,
	tile_size: float
) -> _PropDirectiveScript:
	if comp.occupied_cells.has(anchor.cell) or comp.reserved_cells.has(anchor.cell):
		comp.rejected_placements += 1
		return null

	# Filtrar por modo de colocación del anclaje
	var mode_entries: Array = []
	for e in entries:
		if e.style.placement_mode == anchor.mode:
			mode_entries.append(e)

	if mode_entries.is_empty():
		return null

	# Selección ponderada dentro de los entries compatibles
	var total_w: float = 0.0
	for e in mode_entries:
		total_w += maxf(0.0, e.weight)

	if total_w <= 0.0:
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var roll: float = rng.randf_range(0.0, total_w)
	var chosen_style: _PropStyleScript = null

	var cumul: float = 0.0
	for e in mode_entries:
		cumul += maxf(0.0, e.weight)
		if roll <= cumul:
			chosen_style = e.style
			break

	if chosen_style == null:
		chosen_style = mode_entries[mode_entries.size() - 1].style

	# Comprobar huella en celdas (Footprint)
	var rot_deg: float = rad_to_deg(anchor.rotation_degrees_y)
	var needed_cells: Array[Vector2i] = []
	if chosen_style.footprint != null:
		needed_cells = chosen_style.footprint.get_occupied_cells(anchor.cell, rot_deg)
	else:
		needed_cells = [anchor.cell]

	for c in needed_cells:
		if not floor_cells_map.has(c):
			comp.rejected_placements += 1
			return null
		if comp.occupied_cells.has(c) or comp.reserved_cells.has(c):
			comp.rejected_placements += 1
			return null

	var directive_pos: Vector3 = anchor.world_position + chosen_style.offset
	return _PropDirectiveScript.new(
		chosen_style.id,
		room_id,
		chosen_style,
		directive_pos,
		rot_deg,
		needed_cells,
		anchor.mode,
		chosen_style.collision_mode
	)
