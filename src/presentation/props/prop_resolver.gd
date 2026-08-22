class_name PropResolver
extends RefCounted

## Resolutor puro para Room Props.
## Consume PresentationRoomContext, PropPalette y PresentationRoomGeometry,
## evalúa anclajes espaciales disponibles (FLOOR, WALL, CENTER, CORNER),
## comprueba la disponibilidad de celdas según PropFootprint,
## y genera un Array de PropDirective inmutables.
## 100% puro: no crea nodos Node3D, no muta CellGrid ni invoca randomize().

const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropAnchorResolverScript = preload("res://src/presentation/props/prop_anchor_resolver.gd")
const _PropPlacementModeScript = preload("res://src/presentation/props/prop_placement_mode.gd")
const _PropPaletteScript = preload("res://src/presentation/props/prop_palette.gd")
const _PropStyleScript = preload("res://src/presentation/props/prop_style.gd")

var _anchor_resolver := _PropAnchorResolverScript.new()

func resolve_room_props(
	room_context,
	palette: _PropPaletteScript,
	room_geometry,
	base_seed: int,
	tile_size: float = 2.0
) -> Array[_PropDirectiveScript]:
	var directives: Array[_PropDirectiveScript] = []
	if room_context == null or palette == null or room_geometry == null:
		return directives

	if palette.entries.is_empty():
		return directives

	var room_id: int = room_context.room_id
	var floor_cells_map: Dictionary = {}
	for fc in room_geometry.floor_cells:
		floor_cells_map[fc] = true

	# Mapa de celdas ocupadas / bloqueadas (puertas, escaleras y props ya colocados)
	var claimed_cells: Dictionary = _PropAnchorResolverScript._build_door_and_stairs_clearance_map(room_geometry)

	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed + room_id * 7331

	var props_spawned: int = 0
	var max_props: int = palette.max_props_per_room

	# 1. RESOLUCIÓN DE ANCHORS CENTRALES (CENTER) - Prioridad 1 (foco visual)
	var center_anchors = _anchor_resolver.find_center_anchors(room_geometry, tile_size)
	for anchor in center_anchors:
		if props_spawned >= max_props:
			break
		var dir = _try_place_prop_on_anchor(anchor, palette, _PropPlacementModeScript.Mode.CENTER, room_id, floor_cells_map, claimed_cells, rng.randi(), tile_size)
		if dir != null:
			directives.append(dir)
			props_spawned += 1

	# 2. RESOLUCIÓN DE ANCHORS DE ESQUINA (CORNER) - Prioridad 2 (urnas, cofres)
	var corner_anchors = _anchor_resolver.find_corner_anchors(room_geometry, tile_size)
	for anchor in corner_anchors:
		if props_spawned >= max_props:
			break
		if rng.randf() > palette.density * 1.5:
			continue
		var dir = _try_place_prop_on_anchor(anchor, palette, _PropPlacementModeScript.Mode.CORNER, room_id, floor_cells_map, claimed_cells, rng.randi(), tile_size)
		if dir != null:
			directives.append(dir)
			props_spawned += 1

	# 3. RESOLUCIÓN DE ANCHORS DE MURO (WALL) - Prioridad 3 (librerías, bancos adosados)
	var wall_anchors = _anchor_resolver.find_wall_anchors(room_geometry, tile_size)
	for anchor in wall_anchors:
		if props_spawned >= max_props:
			break
		if rng.randf() > palette.density:
			continue
		var dir = _try_place_prop_on_anchor(anchor, palette, _PropPlacementModeScript.Mode.WALL, room_id, floor_cells_map, claimed_cells, rng.randi(), tile_size)
		if dir != null:
			directives.append(dir)
			props_spawned += 1

	# 4. RESOLUCIÓN DE ANCHORS DE SUELO GENERAL (FLOOR) - Prioridad 4 (mesas, bancos libres)
	var floor_anchors = _anchor_resolver.find_floor_anchors(room_geometry, tile_size)
	for anchor in floor_anchors:
		if props_spawned >= max_props:
			break
		if rng.randf() > palette.density * 0.8:
			continue
		var dir = _try_place_prop_on_anchor(anchor, palette, _PropPlacementModeScript.Mode.FLOOR, room_id, floor_cells_map, claimed_cells, rng.randi(), tile_size)
		if dir != null:
			directives.append(dir)
			props_spawned += 1

	return directives

func _try_place_prop_on_anchor(
	anchor,
	palette: _PropPaletteScript,
	placement_mode: int,
	room_id: int,
	floor_cells_map: Dictionary,
	claimed_cells: Dictionary,
	seed_val: int,
	tile_size: float
) -> _PropDirectiveScript:
	if claimed_cells.has(anchor.cell):
		return null

	var style: _PropStyleScript = palette.select_weighted(placement_mode, seed_val)
	if style == null:
		return null

	# Comprobar huella en celdas (Footprint)
	var rot_deg: float = rad_to_deg(anchor.rotation_degrees_y)
	var needed_cells: Array[Vector2i] = []
	if style.footprint != null:
		needed_cells = style.footprint.get_occupied_cells(anchor.cell, rot_deg)
	else:
		needed_cells = [anchor.cell]

	for c in needed_cells:
		if not floor_cells_map.has(c):
			return null # Fuera de la habitación
		if claimed_cells.has(c):
			return null # Celda ya ocupada o bloqueada por puerta/escalera

	# Reclamar celdas
	for c in needed_cells:
		claimed_cells[c] = true

	var directive_pos: Vector3 = anchor.world_position + style.offset
	return _PropDirectiveScript.new(
		style.id,
		room_id,
		style,
		directive_pos,
		rot_deg,
		needed_cells,
		placement_mode,
		style.collision_mode
	)
