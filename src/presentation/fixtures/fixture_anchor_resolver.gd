class_name FixtureAnchorResolver
extends RefCounted

## Descubridor y resolutor espacial puro de puntos de anclaje (Anchors) para fixtures.
## Analiza PresentationRoomGeometry para identificar posiciones válidas y filtrar zonas de exclusión
## (puertas, despejes de puertas, escaleras).
## 100% puro: no crea nodos de escena, no muta CellGrid ni depende de semillas aleatorias.

const _WallAnchorScript = preload("res://src/presentation/fixtures/anchors/wall_anchor.gd")
const _FloorAnchorScript = preload("res://src/presentation/fixtures/anchors/floor_anchor.gd")
const _SurfaceAnchorScript = preload("res://src/presentation/fixtures/anchors/surface_anchor.gd")
const _HangingAnchorScript = preload("res://src/presentation/fixtures/anchors/hanging_anchor.gd")

const SIDE_NORTH: int = 0
const SIDE_EAST: int = 1
const SIDE_SOUTH: int = 2
const SIDE_WEST: int = 3

## Descubre todos los anclajes de pared válidos para la habitación provista.
func find_wall_anchors(r_geom, tile_size: float = 2.0) -> Array[_WallAnchorScript]:
	var anchors: Array[_WallAnchorScript] = []
	if r_geom == null or r_geom.wall_cells.is_empty():
		return anchors

	var floor_cells_map: Dictionary = {}
	for fc in r_geom.floor_cells:
		floor_cells_map[fc] = true

	var blocked_cells: Dictionary = _build_door_clearance_map(r_geom)

	var sorted_walls: Array = r_geom.wall_cells.duplicate()
	sorted_walls.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for w_pos in sorted_walls:
		if blocked_cells.has(w_pos):
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
			rot_y = PI * 0.5
		elif floor_cells_map.has(w_pos + Vector2i(-1, 0)):
			valid_side = SIDE_EAST
			facing_normal = Vector3(-1.0, 0.0, 0.0)
			rot_y = -PI * 0.5

		if valid_side == -1:
			continue

		var center_x: float = (float(w_pos.x) + 0.5) * tile_size
		var center_z: float = (float(w_pos.y) + 0.5) * tile_size
		var world_pos := Vector3(center_x, 0.0, center_z) + (facing_normal * (tile_size * 0.50))

		var anchor := _WallAnchorScript.new(
			w_pos,
			valid_side,
			world_pos,
			rot_y,
			facing_normal
		)
		anchors.append(anchor)

	return anchors

## Descubre todos los anclajes de suelo válidos para la habitación provista.
func find_floor_anchors(r_geom, tile_size: float = 2.0) -> Array[_FloorAnchorScript]:
	var anchors: Array[_FloorAnchorScript] = []
	if r_geom == null or r_geom.floor_cells.is_empty():
		return anchors

	var blocked_cells: Dictionary = _build_door_clearance_map(r_geom)

	var sorted_floors: Array = r_geom.floor_cells.duplicate()
	sorted_floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for f_pos in sorted_floors:
		if blocked_cells.has(f_pos):
			continue

		var center_x: float = (float(f_pos.x) + 0.5) * tile_size
		var center_z: float = (float(f_pos.y) + 0.5) * tile_size
		var world_pos := Vector3(center_x, 0.0, center_z)

		var anchor := _FloorAnchorScript.new(
			f_pos,
			world_pos,
			0.0
		)
		anchors.append(anchor)

	return anchors

## Descubre todos los anclajes de superficie horizontal válidos.
func find_surface_anchors(r_geom, tile_size: float = 2.0) -> Array[_SurfaceAnchorScript]:
	var anchors: Array[_SurfaceAnchorScript] = []
	var floor_anchors = find_floor_anchors(r_geom, tile_size)
	for fa in floor_anchors:
		var s_anchor := _SurfaceAnchorScript.new(
			fa.cell,
			fa.position,
			fa.rotation_y,
			&"floor_surface"
		)
		anchors.append(s_anchor)
	return anchors

## Descubre todos los anclajes suspendidos / colgantes superiores válidos.
func find_hanging_anchors(r_geom, tile_size: float = 2.0, default_height: float = 2.4) -> Array[_HangingAnchorScript]:
	var anchors: Array[_HangingAnchorScript] = []
	var floor_anchors = find_floor_anchors(r_geom, tile_size)
	for fa in floor_anchors:
		var h_pos = fa.position + Vector3(0.0, default_height, 0.0)
		var h_anchor := _HangingAnchorScript.new(
			fa.cell,
			h_pos,
			fa.rotation_y,
			default_height
		)
		anchors.append(h_anchor)
	return anchors

func _build_door_clearance_map(r_geom) -> Dictionary:
	var blocked: Dictionary = {}
	if r_geom != null and not r_geom.door_positions.is_empty():
		for dc in r_geom.door_positions:
			blocked[dc] = true
			for off in [
				Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
				Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)
			]:
				blocked[dc + off] = true
	return blocked
