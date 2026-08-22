class_name PropAnchorResolver
extends RefCounted

## Descubridor y resolutor espacial puro de puntos de anclaje (Anchors) para Room Props.
## Analiza PresentationRoomGeometry para identificar posiciones válidas en los 4 modos de colocación:
## FLOOR, WALL (celdas de suelo adyacentes a muro orientadas hacia la sala), CENTER y CORNER.
## 100% puro: no crea nodos de escena, no muta CellGrid ni depende de semillas aleatorias.

const _FloorPropAnchorScript = preload("res://src/presentation/props/anchors/floor_prop_anchor.gd")
const _WallPropAnchorScript = preload("res://src/presentation/props/anchors/wall_prop_anchor.gd")
const _CenterPropAnchorScript = preload("res://src/presentation/props/anchors/center_prop_anchor.gd")
const _CornerPropAnchorScript = preload("res://src/presentation/props/anchors/corner_prop_anchor.gd")
const _PropAnchorScript = preload("res://src/presentation/props/prop_anchor.gd")

## Descubre todos los anchors de suelo general.
func find_floor_anchors(r_geom, tile_size: float = 2.0) -> Array[_FloorPropAnchorScript]:
	var anchors: Array[_FloorPropAnchorScript] = []
	if r_geom == null or r_geom.floor_cells.is_empty():
		return anchors

	var blocked_cells: Dictionary = _build_door_and_stairs_clearance_map(r_geom)
	var sorted_floors: Array = r_geom.floor_cells.duplicate()
	sorted_floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for f_pos in sorted_floors:
		if blocked_cells.has(f_pos):
			continue
		var world_pos := Vector3(float(f_pos.x) * tile_size + tile_size * 0.5, 0.0, float(f_pos.y) * tile_size + tile_size * 0.5)
		anchors.append(_FloorPropAnchorScript.new(f_pos, world_pos, 0.0))

	return anchors

## Descubre anchors adosados a muros (celda de suelo pegada a la pared orientada hacia el interior).
func find_wall_anchors(r_geom, tile_size: float = 2.0) -> Array[_WallPropAnchorScript]:
	var anchors: Array[_WallPropAnchorScript] = []
	if r_geom == null or r_geom.floor_cells.is_empty():
		return anchors

	var floor_cells_map: Dictionary = {}
	for fc in r_geom.floor_cells:
		floor_cells_map[fc] = true

	var blocked_cells: Dictionary = _build_door_and_stairs_clearance_map(r_geom)
	var sorted_floors: Array = r_geom.floor_cells.duplicate()
	sorted_floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for f_pos in sorted_floors:
		if blocked_cells.has(f_pos):
			continue

		# Comprobar si tiene una pared adyacente (Norte, Sur, Este, Oeste)
		var wall_dir := Vector2i.ZERO
		var rot_y: float = 0.0

		if not floor_cells_map.has(f_pos + Vector2i(0, -1)): # Pared al Norte (-Y)
			wall_dir = Vector2i(0, -1)
			rot_y = 0.0 # Mirando hacia el Sur (+Z en 3D)
		elif not floor_cells_map.has(f_pos + Vector2i(0, 1)): # Pared al Sur (+Y)
			wall_dir = Vector2i(0, 1)
			rot_y = PI # Mirando hacia el Norte (-Z en 3D)
		elif not floor_cells_map.has(f_pos + Vector2i(-1, 0)): # Pared al Oeste (-X)
			wall_dir = Vector2i(-1, 0)
			rot_y = -PI * 0.5 # Mirando hacia el Este (+X en 3D)
		elif not floor_cells_map.has(f_pos + Vector2i(1, 0)): # Pared al Este (+X)
			wall_dir = Vector2i(1, 0)
			rot_y = PI * 0.5 # Mirando hacia el Oeste (-X en 3D)

		if wall_dir != Vector2i.ZERO:
			var world_pos := Vector3(float(f_pos.x) * tile_size + tile_size * 0.5, 0.0, float(f_pos.y) * tile_size + tile_size * 0.5)
			anchors.append(_WallPropAnchorScript.new(f_pos, world_pos, rot_y, wall_dir))

	return anchors

## Descubre el anclaje focal central de la habitación.
func find_center_anchors(r_geom, tile_size: float = 2.0) -> Array[_CenterPropAnchorScript]:
	var anchors: Array[_CenterPropAnchorScript] = []
	if r_geom == null or r_geom.floor_cells.is_empty():
		return anchors

	var blocked_cells: Dictionary = _build_door_and_stairs_clearance_map(r_geom)

	# Calcular baricentro / centroide de la sala
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	for fc in r_geom.floor_cells:
		sum_x += float(fc.x)
		sum_y += float(fc.y)

	var count: float = float(r_geom.floor_cells.size())
	var centroid := Vector2(sum_x / count, sum_y / count)

	# Buscar la celda de suelo no bloqueada más cercana al centroide
	var best_cell := Vector2i.ZERO
	var best_dist: float = 999999.0

	var sorted_floors: Array = r_geom.floor_cells.duplicate()
	sorted_floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for f_pos in sorted_floors:
		if blocked_cells.has(f_pos):
			continue
		var d: float = centroid.distance_to(Vector2(float(f_pos.x), float(f_pos.y)))
		if d < best_dist:
			best_dist = d
			best_cell = f_pos

	if best_dist < 999900.0:
		var world_pos := Vector3(float(best_cell.x) * tile_size + tile_size * 0.5, 0.0, float(best_cell.y) * tile_size + tile_size * 0.5)
		anchors.append(_CenterPropAnchorScript.new(best_cell, world_pos, 0.0))

	return anchors

## Descubre anchors de esquina interior (celdas de suelo con al menos 2 paredes ortogonales).
func find_corner_anchors(r_geom, tile_size: float = 2.0) -> Array[_CornerPropAnchorScript]:
	var anchors: Array[_CornerPropAnchorScript] = []
	if r_geom == null or r_geom.floor_cells.is_empty():
		return anchors

	var floor_cells_map: Dictionary = {}
	for fc in r_geom.floor_cells:
		floor_cells_map[fc] = true

	var blocked_cells: Dictionary = _build_door_and_stairs_clearance_map(r_geom)
	var sorted_floors: Array = r_geom.floor_cells.duplicate()
	sorted_floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y if a.y != b.y else a.x < b.x
	)

	for f_pos in sorted_floors:
		if blocked_cells.has(f_pos):
			continue

		var has_north_wall: bool = not floor_cells_map.has(f_pos + Vector2i(0, -1))
		var has_south_wall: bool = not floor_cells_map.has(f_pos + Vector2i(0, 1))
		var has_west_wall: bool = not floor_cells_map.has(f_pos + Vector2i(-1, 0))
		var has_east_wall: bool = not floor_cells_map.has(f_pos + Vector2i(1, 0))

		var rot_y: float = 0.0
		var is_corner: bool = false

		if has_north_wall and has_west_wall:
			is_corner = true
			rot_y = -PI * 0.25 # Esquina Noroeste mirando hacia SE (+X, +Z)
		elif has_north_wall and has_east_wall:
			is_corner = true
			rot_y = PI * 0.25 # Esquina Noreste mirando hacia SO (-X, +Z)
		elif has_south_wall and has_west_wall:
			is_corner = true
			rot_y = -PI * 0.75 # Esquina Suroeste mirando hacia NE (+X, -Z)
		elif has_south_wall and has_east_wall:
			is_corner = true
			rot_y = PI * 0.75 # Esquina Sureste mirando hacia NO (-X, -Z)

		if is_corner:
			var world_pos := Vector3(float(f_pos.x) * tile_size + tile_size * 0.5, 0.0, float(f_pos.y) * tile_size + tile_size * 0.5)
			anchors.append(_CornerPropAnchorScript.new(f_pos, world_pos, rot_y))

	return anchors

## Construye un mapa de celdas de despeje para puertas y escaleras.
static func _build_door_and_stairs_clearance_map(r_geom) -> Dictionary:
	var map: Dictionary = {}
	if r_geom == null:
		return map

	if "door_positions" in r_geom and r_geom.door_positions != null:
		for d_pos in r_geom.door_positions:
			map[d_pos] = true
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					map[d_pos + Vector2i(dx, dy)] = true

	if "stairs_cells" in r_geom and r_geom.stairs_cells != null:
		for s_pos in r_geom.stairs_cells:
			map[s_pos] = true
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					map[s_pos + Vector2i(dx, dy)] = true

	return map

