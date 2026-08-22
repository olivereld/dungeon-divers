class_name FixtureResolver
extends RefCounted

## Resolutor espacial puro de fixtures arquitectónicos por habitación.
## Delega el descubrimiento físico a FixtureAnchorResolver y aplica paletas, restricciones
## y selección determinista ponderada para generar FixtureDirectives en los 4 modos (WALL, FLOOR, SURFACE, HANGING).
## 100% puro: no crea nodos de escena ni muta CellGrid.

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _FixtureAnchorResolverScript = preload("res://src/presentation/fixtures/fixture_anchor_resolver.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _SeedDerivationScript = preload("res://src/dungeon_generator/core/seed_derivation.gd")

var _anchor_resolver = _FixtureAnchorResolverScript.new()

## Resuelve todas las directivas de fixtures para una habitación específica en los 4 modos de colocación.
func resolve_room_fixtures(
	room_context: _PresentationRoomContextScript,
	partition, # PresentationGeometryPartition
	palette: _FixturePaletteScript,
	master_seed: int,
	tile_size: float = 2.0
) -> Array: # Array[FixtureDirective]
	var directives: Array = []
	if room_context == null or partition == null or palette == null or palette.entries.is_empty():
		return directives

	var r_id: int = room_context.room_id
	var r_geom = partition.get_room_geometry(r_id)
	if r_geom == null:
		return directives

	# 1. Resolver fixtures de pared (WALL)
	var wall_entries = palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.WALL)
	if not wall_entries.is_empty():
		var wall_dirs = _resolve_wall_fixtures(r_id, r_geom, palette, master_seed, tile_size)
		directives.append_array(wall_dirs)

	# 2. Resolver fixtures de suelo (FLOOR)
	var floor_entries = palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.FLOOR)
	if not floor_entries.is_empty():
		var floor_dirs = _resolve_floor_fixtures(r_id, r_geom, palette, master_seed, tile_size)
		directives.append_array(floor_dirs)

	# 3. Resolver fixtures de superficie (SURFACE)
	var surface_entries = palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.SURFACE)
	if not surface_entries.is_empty():
		var surface_dirs = _resolve_surface_fixtures(r_id, r_geom, palette, master_seed, tile_size)
		directives.append_array(surface_dirs)

	# 4. Resolver fixtures colgantes / suspendidos (HANGING)
	var hanging_entries = palette.get_entries_for_placement(_FixturePlacementModeScript.Mode.HANGING)
	if not hanging_entries.is_empty():
		var hanging_dirs = _resolve_hanging_fixtures(r_id, r_geom, palette, master_seed, tile_size)
		directives.append_array(hanging_dirs)

	return directives

# ==============================================================================
# 1. RESOLVER DE PARED (WALL)
# ==============================================================================
func _resolve_wall_fixtures(
	room_id: int,
	r_geom,
	palette: _FixturePaletteScript,
	master_seed: int,
	tile_size: float
) -> Array:
	var directives: Array = []
	var anchors = _anchor_resolver.find_wall_anchors(r_geom, tile_size)
	if anchors.is_empty():
		return directives

	var placed_cells: Array[Vector2i] = []
	var spacing: int = maxi(1, palette.wall_fixture_spacing)

	for anchor in anchors:
		var too_close: bool = false
		for p in placed_cells:
			if (abs(anchor.cell.x - p.x) + abs(anchor.cell.y - p.y)) < spacing:
				too_close = true
				break
		if too_close:
			continue

		var cell_seed: int = _SeedDerivationScript.derive_seed(master_seed, "fixtures_wall", room_id * 10000 + anchor.cell.x * 100 + anchor.cell.y)
		var roll: float = float(cell_seed % 1000) / 1000.0
		if roll > palette.wall_fixture_probability:
			continue

		# Selección ponderada determinista
		var chosen_style: _FixtureStyleScript = palette.select_weighted(_FixturePlacementModeScript.Mode.WALL, cell_seed)
		if chosen_style == null:
			continue

		var world_pos: Vector3 = anchor.position + chosen_style.offset

		var placement = _FixturePlacementScript.new(
			_FixturePlacementModeScript.Mode.WALL,
			anchor.cell,
			anchor.wall_side,
			world_pos,
			anchor.rotation_y,
			anchor.normal
		)

		var directive = _FixtureDirectiveScript.new(
			chosen_style.id,
			room_id,
			chosen_style,
			placement,
			chosen_style.scale
		)
		directives.append(directive)
		placed_cells.append(anchor.cell)

	return directives

# ==============================================================================
# 2. RESOLVER DE SUELO (FLOOR)
# ==============================================================================
func _resolve_floor_fixtures(
	room_id: int,
	r_geom,
	palette: _FixturePaletteScript,
	master_seed: int,
	tile_size: float
) -> Array:
	var directives: Array = []
	var anchors = _anchor_resolver.find_floor_anchors(r_geom, tile_size)
	if anchors.is_empty():
		return directives

	var placed_cells: Array[Vector2i] = []
	var spacing: int = maxi(2, palette.floor_fixture_spacing)

	for anchor in anchors:
		var too_close: bool = false
		for p in placed_cells:
			if (abs(anchor.cell.x - p.x) + abs(anchor.cell.y - p.y)) < spacing:
				too_close = true
				break
		if too_close:
			continue

		var cell_seed: int = _SeedDerivationScript.derive_seed(master_seed, "fixtures_floor", room_id * 10000 + anchor.cell.x * 100 + anchor.cell.y)
		var roll: float = float(cell_seed % 1000) / 1000.0
		if roll > palette.floor_fixture_probability:
			continue

		var chosen_style: _FixtureStyleScript = palette.select_weighted(_FixturePlacementModeScript.Mode.FLOOR, cell_seed)
		if chosen_style == null:
			continue

		var world_pos: Vector3 = anchor.position + chosen_style.offset
		var rot_y: float = float((cell_seed % 4)) * (PI * 0.5)

		var placement = _FixturePlacementScript.new(
			_FixturePlacementModeScript.Mode.FLOOR,
			anchor.cell,
			-1,
			world_pos,
			rot_y,
			Vector3.UP
		)

		var directive = _FixtureDirectiveScript.new(
			chosen_style.id,
			room_id,
			chosen_style,
			placement,
			chosen_style.scale
		)
		directives.append(directive)
		placed_cells.append(anchor.cell)

	return directives

# ==============================================================================
# 3. RESOLVER DE SUPERFICIE (SURFACE)
# ==============================================================================
func _resolve_surface_fixtures(
	room_id: int,
	r_geom,
	palette: _FixturePaletteScript,
	master_seed: int,
	tile_size: float
) -> Array:
	var directives: Array = []
	var anchors = _anchor_resolver.find_surface_anchors(r_geom, tile_size)
	if anchors.is_empty():
		return directives

	var placed_cells: Array[Vector2i] = []
	var spacing: int = maxi(3, palette.floor_fixture_spacing)

	for anchor in anchors:
		var too_close: bool = false
		for p in placed_cells:
			if (abs(anchor.cell.x - p.x) + abs(anchor.cell.y - p.y)) < spacing:
				too_close = true
				break
		if too_close:
			continue

		var cell_seed: int = _SeedDerivationScript.derive_seed(master_seed, "fixtures_surface", room_id * 10000 + anchor.cell.x * 100 + anchor.cell.y)
		var roll: float = float(cell_seed % 1000) / 1000.0
		if roll > (palette.floor_fixture_probability * 0.7):
			continue

		var chosen_style: _FixtureStyleScript = palette.select_weighted(_FixturePlacementModeScript.Mode.SURFACE, cell_seed)
		if chosen_style == null:
			continue

		var world_pos: Vector3 = anchor.position + chosen_style.offset
		var rot_y: float = float((cell_seed % 4)) * (PI * 0.5)

		var placement = _FixturePlacementScript.new(
			_FixturePlacementModeScript.Mode.SURFACE,
			anchor.cell,
			-1,
			world_pos,
			rot_y,
			Vector3.UP
		)

		var directive = _FixtureDirectiveScript.new(
			chosen_style.id,
			room_id,
			chosen_style,
			placement,
			chosen_style.scale
		)
		directives.append(directive)
		placed_cells.append(anchor.cell)

	return directives

# ==============================================================================
# 4. RESOLVER COLGANTE (HANGING)
# ==============================================================================
func _resolve_hanging_fixtures(
	room_id: int,
	r_geom,
	palette: _FixturePaletteScript,
	master_seed: int,
	tile_size: float
) -> Array:
	var directives: Array = []
	var anchors = _anchor_resolver.find_hanging_anchors(r_geom, tile_size)
	if anchors.is_empty():
		return directives

	var placed_cells: Array[Vector2i] = []
	var spacing: int = maxi(4, palette.floor_fixture_spacing + 1)

	for anchor in anchors:
		var too_close: bool = false
		for p in placed_cells:
			if (abs(anchor.cell.x - p.x) + abs(anchor.cell.y - p.y)) < spacing:
				too_close = true
				break
		if too_close:
			continue

		var cell_seed: int = _SeedDerivationScript.derive_seed(master_seed, "fixtures_hanging", room_id * 10000 + anchor.cell.x * 100 + anchor.cell.y)
		var roll: float = float(cell_seed % 1000) / 1000.0
		if roll > (palette.floor_fixture_probability * 0.6):
			continue

		var chosen_style: _FixtureStyleScript = palette.select_weighted(_FixturePlacementModeScript.Mode.HANGING, cell_seed)
		if chosen_style == null:
			continue

		var world_pos: Vector3 = anchor.position + chosen_style.offset
		var rot_y: float = float((cell_seed % 8)) * (PI * 0.25)

		var placement = _FixturePlacementScript.new(
			_FixturePlacementModeScript.Mode.HANGING,
			anchor.cell,
			-1,
			world_pos,
			rot_y,
			Vector3.DOWN
		)

		var directive = _FixtureDirectiveScript.new(
			chosen_style.id,
			room_id,
			chosen_style,
			placement,
			chosen_style.scale
		)
		directives.append(directive)
		placed_cells.append(anchor.cell)

	return directives
