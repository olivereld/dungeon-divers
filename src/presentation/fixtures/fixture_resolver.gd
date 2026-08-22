class_name FixtureResolver
extends RefCounted

## Resolutor espacial puro de fixtures arquitectónicos por habitación.
## Analiza PresentationRoomGeometry, partición y paleta para generar directivas deterministas.
## Despacha internamente según FixturePlacementMode (WALL, FLOOR, SURFACE, HANGING).
## 100% puro: no crea nodos de escena ni muta CellGrid.

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixturePlacementScript = preload("res://src/presentation/fixtures/fixture_placement.gd")
const _FixturePlacementModeScript = preload("res://src/presentation/fixtures/fixture_placement_mode.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixtureStyleScript = preload("res://src/presentation/fixtures/fixture_style.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _SeedDerivationScript = preload("res://src/dungeon_generator/core/seed_derivation.gd")

const SIDE_NORTH: int = 0
const SIDE_EAST: int = 1
const SIDE_SOUTH: int = 2
const SIDE_WEST: int = 3

## Resuelve todas las directivas de fixtures para una habitación específica.
func resolve_room_fixtures(
	room_context: _PresentationRoomContextScript,
	partition, # PresentationGeometryPartition
	palette: _FixturePaletteScript,
	master_seed: int,
	tile_size: float = 2.0
) -> Array: # Array[FixtureDirective]
	var directives: Array = []
	if room_context == null or partition == null or palette == null or palette.fixtures.is_empty():
		return directives

	var r_id: int = room_context.room_id
	var r_geom = partition.get_room_geometry(r_id)
	if r_geom == null:
		return directives

	# 1. Resolver fixtures de pared (WALL)
	var wall_fixtures = palette.get_fixtures_by_placement(_FixturePlacementModeScript.Mode.WALL)
	if not wall_fixtures.is_empty() and not r_geom.wall_cells.is_empty():
		var wall_dirs = _resolve_wall_fixtures(r_ctx_or_id(r_id), r_geom, wall_fixtures, palette, master_seed, tile_size)
		directives.append_array(wall_dirs)

	# 2. Resolver fixtures de suelo (FLOOR)
	var floor_fixtures = palette.get_fixtures_by_placement(_FixturePlacementModeScript.Mode.FLOOR)
	if not floor_fixtures.is_empty() and not r_geom.floor_cells.is_empty():
		var floor_dirs = _resolve_floor_fixtures(r_ctx_or_id(r_id), r_geom, floor_fixtures, palette, master_seed, tile_size)
		directives.append_array(floor_dirs)

	return directives

func r_ctx_or_id(room_id: int) -> int:
	return room_id

# ==============================================================================
# 1. RESOLVER DE PARED (WALL)
# ==============================================================================
func _resolve_wall_fixtures(
	room_id: int,
	r_geom,
	wall_styles: Array[_FixtureStyleScript],
	palette: _FixturePaletteScript,
	master_seed: int,
	tile_size: float
) -> Array:
	var directives: Array = []
	var primary_style: _FixtureStyleScript = wall_styles[0]

	# Mapear celdas de suelo para comprobación rápida de interior
	var floor_cells_map: Dictionary = {}
	for fc in r_geom.floor_cells:
		floor_cells_map[fc] = true

	# Mapear celdas bloqueadas (puertas y su zona de despeje de 1 celda)
	var blocked_cells: Dictionary = {}
	for dc in r_geom.door_positions:
		blocked_cells[dc] = true
		for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			blocked_cells[dc + off] = true

	var placed_cells: Array[Vector2i] = []
	var spacing: int = maxi(1, palette.wall_fixture_spacing)

	var sorted_walls: Array = r_geom.wall_cells.duplicate()
	sorted_walls.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for w_pos in sorted_walls:
		if blocked_cells.has(w_pos):
			continue

		var too_close: bool = false
		for p in placed_cells:
			if (abs(w_pos.x - p.x) + abs(w_pos.y - p.y)) < spacing:
				too_close = true
				break
		if too_close:
			continue

		var valid_side: int = -1
		var facing_normal := Vector3.ZERO
		var rot_y: float = 0.0

		if floor_cells_map.has(w_pos + Vector2i(0, 1)):
			valid_side = SIDE_NORTH
			facing_normal = Vector3(0.0, 0.0, 1.0)
			rot_y = 0.0
		elif floor_cells_map.has(w_pos + Vector2i(0, -1)):
			valid_side = SIDE_SOUTH
			facing_normal = Vector3(0.0, 0.0, -1.0)
			rot_y = PI
		elif floor_cells_map.has(w_pos + Vector2i(1, 0)):
			valid_side = SIDE_WEST
			facing_normal = Vector3(1.0, 0.0, 0.0)
			rot_y = -PI * 0.5
		elif floor_cells_map.has(w_pos + Vector2i(-1, 0)):
			valid_side = SIDE_EAST
			facing_normal = Vector3(-1.0, 0.0, 0.0)
			rot_y = PI * 0.5

		if valid_side == -1:
			continue

		var cell_seed: int = _SeedDerivationScript.derive_seed(master_seed, "fixtures_wall", room_id * 10000 + w_pos.x * 100 + w_pos.y)
		var roll: float = float(cell_seed % 1000) / 1000.0
		if roll > palette.wall_fixture_probability:
			continue

		# Seleccionar estilo determinista de la lista disponible para muros
		var style_idx: int = cell_seed % wall_styles.size()
		var chosen_style: _FixtureStyleScript = wall_styles[style_idx]

		var center_x: float = (float(w_pos.x) + 0.5) * tile_size
		var center_z: float = (float(w_pos.y) + 0.5) * tile_size
		var world_pos := Vector3(center_x, 0.0, center_z) + (facing_normal * (tile_size * 0.48))
		world_pos += chosen_style.offset

		var placement = _FixturePlacementScript.new(
			_FixturePlacementModeScript.Mode.WALL,
			w_pos,
			valid_side,
			world_pos,
			rot_y,
			facing_normal
		)

		var directive = _FixtureDirectiveScript.new(
			chosen_style.id,
			room_id,
			chosen_style,
			placement,
			chosen_style.scale
		)
		directives.append(directive)
		placed_cells.append(w_pos)

	return directives

# ==============================================================================
# 2. RESOLVER DE SUELO (FLOOR)
# ==============================================================================
func _resolve_floor_fixtures(
	room_id: int,
	r_geom,
	floor_styles: Array[_FixtureStyleScript],
	palette: _FixturePaletteScript,
	master_seed: int,
	tile_size: float
) -> Array:
	var directives: Array = []

	# Mapear celdas bloqueadas (puertas, perímetro de muros y zona de paso)
	var blocked_cells: Dictionary = {}
	for dc in r_geom.door_positions:
		blocked_cells[dc] = true
		for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			blocked_cells[dc + off] = true

	var placed_cells: Array[Vector2i] = []
	var spacing: int = maxi(2, palette.floor_fixture_spacing)

	var sorted_floors: Array = r_geom.floor_cells.duplicate()
	sorted_floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for f_pos in sorted_floors:
		if blocked_cells.has(f_pos):
			continue

		var too_close: bool = false
		for p in placed_cells:
			if (abs(f_pos.x - p.x) + abs(f_pos.y - p.y)) < spacing:
				too_close = true
				break
		if too_close:
			continue

		var cell_seed: int = _SeedDerivationScript.derive_seed(master_seed, "fixtures_floor", room_id * 10000 + f_pos.x * 100 + f_pos.y)
		var roll: float = float(cell_seed % 1000) / 1000.0
		if roll > palette.floor_fixture_probability:
			continue

		var style_idx: int = cell_seed % floor_styles.size()
		var chosen_style: _FixtureStyleScript = floor_styles[style_idx]

		var center_x: float = (float(f_pos.x) + 0.5) * tile_size
		var center_z: float = (float(f_pos.y) + 0.5) * tile_size
		var world_pos := Vector3(center_x, 0.0, center_z) + chosen_style.offset

		# Rotación aleatoria discreta o determinista en suelo
		var rot_y: float = float((cell_seed % 4)) * (PI * 0.5)

		var placement = _FixturePlacementScript.new(
			_FixturePlacementModeScript.Mode.FLOOR,
			f_pos,
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
		placed_cells.append(f_pos)

	return directives
