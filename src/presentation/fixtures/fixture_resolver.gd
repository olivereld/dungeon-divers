class_name FixtureResolver
extends RefCounted

## Resolutor espacial puro de fixtures arquitectónicos por habitación.
## Analiza PresentationRoomGeometry, excluye puertas/escaleras y genera directivas deterministas.
## 100% puro: no crea nodos de escena ni muta CellGrid.

const _FixtureDirectiveScript = preload("res://src/presentation/fixtures/fixture_directive.gd")
const _FixturePaletteScript = preload("res://src/presentation/fixtures/fixture_palette.gd")
const _FixtureAnchorScript = preload("res://src/presentation/fixtures/fixture_anchor.gd")
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
	if room_context == null or partition == null or palette == null or palette.wall_fixture == null:
		return directives

	var r_id: int = room_context.room_id
	var r_geom = partition.get_room_geometry(r_id)
	if r_geom == null or r_geom.wall_cells.is_empty():
		return directives

	# 1. Mapear celdas de suelo para comprobación rápida de interior
	var floor_cells_map: Dictionary = {}
	for fc in r_geom.floor_cells:
		floor_cells_map[fc] = true

	# 2. Mapear celdas bloqueadas (puertas y su zona de despeje de 1 celda)
	var blocked_cells: Dictionary = {}
	for dc in r_geom.door_positions:
		blocked_cells[dc] = true
		for off in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
			blocked_cells[dc + off] = true

	# 3. Analizar candidatos en los muros perimetrales
	var placed_cells: Array[Vector2i] = []
	var spacing: int = maxi(1, palette.wall_fixture_spacing)

	# Ordenar celdas de muro de forma determinista
	var sorted_walls: Array = r_geom.wall_cells.duplicate()
	sorted_walls.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for w_pos in sorted_walls:
		if blocked_cells.has(w_pos):
			continue

		# Comprobar si respeta el espaciado mínimo con otros fixtures ya colocados
		var too_close: bool = false
		for p in placed_cells:
			if (abs(w_pos.x - p.x) + abs(w_pos.y - p.y)) < spacing:
				too_close = true
				break
		if too_close:
			continue

		# Determinar lado cardinal y si da cara a un suelo transitable de la sala
		var valid_side: int = -1
		var facing_normal := Vector3.ZERO
		var rot_y: float = 0.0

		if floor_cells_map.has(w_pos + Vector2i(0, 1)): # Muro Norte mirando hacia el Sur
			valid_side = SIDE_NORTH
			facing_normal = Vector3(0.0, 0.0, 1.0)
			rot_y = 0.0
		elif floor_cells_map.has(w_pos + Vector2i(0, -1)): # Muro Sur mirando hacia el Norte
			valid_side = SIDE_SOUTH
			facing_normal = Vector3(0.0, 0.0, -1.0)
			rot_y = PI
		elif floor_cells_map.has(w_pos + Vector2i(1, 0)): # Muro Oeste mirando hacia el Este
			valid_side = SIDE_WEST
			facing_normal = Vector3(1.0, 0.0, 0.0)
			rot_y = -PI * 0.5
		elif floor_cells_map.has(w_pos + Vector2i(-1, 0)): # Muro Este mirando hacia el Oeste
			valid_side = SIDE_EAST
			facing_normal = Vector3(-1.0, 0.0, 0.0)
			rot_y = PI * 0.5

		if valid_side == -1:
			continue # No es una pared recta hacia el interior

		# Decisión pseudo-aleatoria determinista
		var cell_seed: int = _SeedDerivationScript.derive_seed(master_seed, "fixtures", r_id * 10000 + w_pos.x * 100 + w_pos.y)
		var roll: float = float(cell_seed % 1000) / 1000.0
		if roll > palette.wall_fixture_probability:
			continue

		# Calcular posición 3D exacta adosada al plano de la pared
		var center_x: float = (float(w_pos.x) + 0.5) * tile_size
		var center_z: float = (float(w_pos.y) + 0.5) * tile_size
		var world_pos := Vector3(center_x, 0.0, center_z) + (facing_normal * (tile_size * 0.48))
		world_pos += palette.wall_fixture.offset

		var directive = _FixtureDirectiveScript.new(
			palette.wall_fixture.id,
			r_id,
			_FixtureAnchorScript.Type.WALL,
			w_pos,
			valid_side,
			world_pos,
			rot_y,
			palette.wall_fixture.scale,
			palette.wall_fixture
		)
		directives.append(directive)
		placed_cells.append(w_pos)

	return directives
