class_name RoomTemplateShapeCarver
extends RefCounted

## Generador y tallador paramétrico de formas geométricas para RoomTemplates.
## Aplica familias de formas espaciales a CellGrid garantizando conectividad,
## despeje de entradas, zonas reservadas y ratio de habitabilidad >= 70%.

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _ZoneMapScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template_zone_map.gd")
const _TemplateCarveResultScript = preload("res://src/dungeon_generator/core/room_templates/data/template_carve_result.gd")

static func carve_room_shape(
	grid: CellGrid,
	room: RoomData,
	template: _RoomTemplateScript,
	entrances: Array[Vector2i] = [],
	rng: RandomNumberGenerator = null
) -> _ZoneMapScript:
	var res = carve(grid, room, template, entrances, rng, 0)
	return res.zone_map if res != null else null

static func carve(
	grid: CellGrid,
	room: RoomData,
	template: _RoomTemplateScript,
	entrances: Array[Vector2i] = [],
	rng: RandomNumberGenerator = null,
	p_orientation: int = 0
) -> _TemplateCarveResultScript:
	if grid == null or room == null:
		return null

	var rect := room.rect
	var zone_map := _ZoneMapScript.new(rect)
	var w: int = rect.size.x
	var h: int = rect.size.y
	var center: Vector2i = room.get_center()

	# Default baseline: Fill entire room with floor
	grid.fill_rect(rect, CellGrid.CellType.FLOOR)

	# Determine primary shape family from template geometry policy
	var shape_family: StringName = &"rectangle"
	if template != null and template.geometry != null and not template.geometry.allowed_shapes.is_empty():
		shape_family = template.geometry.allowed_shapes[0]

	# If room is too small (< 6 on either axis), enforce open rectangular floor for walkability safety
	if w < 6 or h < 6:
		shape_family = &"rectangle"

	match shape_family:
		&"octagonal", &"octagonal_chamber", &"octagon":
			_apply_octagonal_shape(grid, rect, w, h, entrances)

		&"cruciform", &"cruciform_sanctuary", &"cross":
			_apply_cruciform_shape(grid, rect, w, h, entrances)

		&"pillared", &"pillared_hall", &"pillars":
			_apply_pillared_shape(grid, rect, w, h, entrances, rng)

		&"chapel":
			_apply_chapel_shape(grid, rect, w, h, entrances, zone_map, p_orientation)

		&"central_nave", &"nave":
			_apply_central_nave_shape(grid, rect, w, h, entrances, zone_map, p_orientation)

		&"niched_hall", &"niches":
			_apply_niched_hall_shape(grid, rect, w, h, entrances, zone_map, p_orientation)

		&"rectangle", &"open_rectangle", &"square", _:
			# Open rectangle (already filled with floor)
			pass

	# Ensure room center is always walkable floor
	grid.set_cell(room.get_center(), CellGrid.CellType.FLOOR)

	# Ensure all entrance points and immediate 1-cell inward step are always walkable floor
	for ent in entrances:
		if rect.has_point(ent):
			grid.set_cell(ent, CellGrid.CellType.FLOOR)
			zone_map.set_zone(ent, &"entrance_clearance")
			# Inward cardinal neighbors inside the room
			for offset in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				var inward: Vector2i = ent + offset
				if rect.has_point(inward) and not _is_on_boundary(rect, inward):
					grid.set_cell(inward, CellGrid.CellType.FLOOR)
					if zone_map.get_zone(inward) == &"unassigned":
						zone_map.set_zone(inward, &"entrance_clearance")
			_ensure_path_to_center(grid, rect, ent, center)

	# Assign focal zone if not already assigned
	if zone_map.get_zone(center) == &"unassigned":
		zone_map.set_zone(center, &"focal")

	# Collect carved cells and assign zones
	var carved_cells: Array[Vector2i] = []
	var reserved_cells: Array[Vector2i] = []

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if grid.is_walkable(cell):
				carved_cells.append(cell)
				if zone_map.get_zone(cell) == &"unassigned":
					if _is_adjacent_to_wall(grid, cell):
						zone_map.set_zone(cell, &"perimeter")
					else:
						zone_map.set_zone(cell, &"circulation")
				else:
					reserved_cells.append(cell)

	# Resolve concrete anchor positions
	var resolved_anchors: Dictionary = {}
	if template != null and template.anchors is Dictionary:
		for a_key in template.anchors:
			var a_def = template.anchors[a_key]
			var loc: StringName = a_def.location_hint if a_def != null else &"center"
			var target: Vector2i = _resolve_anchor_coordinate(rect, loc, p_orientation, center)
			if not grid.is_walkable(target):
				target = _find_nearest_walkable_cell(grid, rect, target)
			resolved_anchors[a_key] = target

	return _TemplateCarveResultScript.new(
		true,
		zone_map,
		carved_cells,
		reserved_cells,
		resolved_anchors,
		p_orientation,
		{ "shape_family": str(shape_family), "walkable_ratio": float(carved_cells.size()) / float(w * h) }
	)

static func _apply_octagonal_shape(grid: CellGrid, rect: Rect2i, w: int, h: int, entrances: Array[Vector2i]) -> void:
	var bevel: int = 1 if (w <= 7 or h <= 7) else 2
	for b in range(bevel):
		_set_wall_if_not_entrance(grid, rect.position + Vector2i(b, 0), entrances)
		_set_wall_if_not_entrance(grid, rect.position + Vector2i(0, b), entrances)
		_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1 - b, 0), entrances)
		_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1, b), entrances)
		_set_wall_if_not_entrance(grid, rect.position + Vector2i(0, h - 1 - b), entrances)
		_set_wall_if_not_entrance(grid, rect.position + Vector2i(b, h - 1), entrances)
		_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1 - b, h - 1), entrances)
		_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1, h - 1 - b), entrances)

static func _apply_cruciform_shape(grid: CellGrid, rect: Rect2i, w: int, h: int, entrances: Array[Vector2i]) -> void:
	var cut: int = 1 if (w <= 7 or h <= 7) else 2
	for cy in range(cut):
		for cx in range(cut):
			_set_wall_if_not_entrance(grid, rect.position + Vector2i(cx, cy), entrances)
			_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1 - cx, cy), entrances)
			_set_wall_if_not_entrance(grid, rect.position + Vector2i(cx, h - 1 - cy), entrances)
			_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1 - cx, h - 1 - cy), entrances)

static func _apply_pillared_shape(grid: CellGrid, rect: Rect2i, w: int, h: int, entrances: Array[Vector2i], _rng: RandomNumberGenerator) -> void:
	if w < 8 or h < 8:
		return
	var offset_x: int = 2 if w >= 10 else 1
	var offset_y: int = 2 if h >= 10 else 1
	var pillars: Array[Vector2i] = [
		rect.position + Vector2i(offset_x + 1, offset_y + 1),
		rect.position + Vector2i(w - 2 - offset_x, offset_y + 1),
		rect.position + Vector2i(offset_x + 1, h - 2 - offset_y),
		rect.position + Vector2i(w - 2 - offset_x, h - 2 - offset_y)
	]
	for p in pillars:
		_set_wall_if_not_entrance(grid, p, entrances)

static func _apply_chapel_shape(grid: CellGrid, rect: Rect2i, w: int, h: int, entrances: Array[Vector2i], zone_map: _ZoneMapScript, orientation: int = 0) -> void:
	# Chapel: Recessed corners, apse focal zone oriented based on orientation
	var cut: int = 1 if (w <= 7 or h <= 7) else 2
	var apse_center: Vector2i = rect.position + Vector2i(w / 2, 1)

	match orientation:
		0: # NORTH
			for cx in range(cut):
				_set_wall_if_not_entrance(grid, rect.position + Vector2i(cx, 0), entrances)
				_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1 - cx, 0), entrances)
			apse_center = rect.position + Vector2i(w / 2, 1)
		2: # SOUTH
			for cx in range(cut):
				_set_wall_if_not_entrance(grid, rect.position + Vector2i(cx, h - 1), entrances)
				_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1 - cx, h - 1), entrances)
			apse_center = rect.position + Vector2i(w / 2, h - 2)
		1: # EAST
			for cy in range(cut):
				_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1, cy), entrances)
				_set_wall_if_not_entrance(grid, rect.position + Vector2i(w - 1, h - 1 - cy), entrances)
			apse_center = rect.position + Vector2i(w - 2, h / 2)
		3: # WEST
			for cy in range(cut):
				_set_wall_if_not_entrance(grid, rect.position + Vector2i(0, cy), entrances)
				_set_wall_if_not_entrance(grid, rect.position + Vector2i(0, h - 1 - cy), entrances)
			apse_center = rect.position + Vector2i(1, h / 2)

	zone_map.set_zone(apse_center, &"focal")
	if w >= 8:
		if orientation == 0 or orientation == 2:
			zone_map.set_zone(apse_center + Vector2i(-1, 0), &"focal")
			zone_map.set_zone(apse_center + Vector2i(1, 0), &"focal")
		else:
			zone_map.set_zone(apse_center + Vector2i(0, -1), &"focal")
			zone_map.set_zone(apse_center + Vector2i(0, 1), &"focal")

static func _apply_central_nave_shape(grid: CellGrid, rect: Rect2i, w: int, h: int, entrances: Array[Vector2i], zone_map: _ZoneMapScript, _orientation: int = 0) -> void:
	# Central corridor open, alcove niches on left and right borders
	for y in range(rect.position.y + 2, rect.end.y - 2, 2):
		_set_wall_if_not_entrance(grid, Vector2i(rect.position.x + 1, y), entrances)
		_set_wall_if_not_entrance(grid, Vector2i(rect.end.x - 2, y), entrances)
	zone_map.set_zone(rect.position + Vector2i(w / 2, h / 2), &"focal")

static func _apply_niched_hall_shape(grid: CellGrid, rect: Rect2i, w: int, h: int, entrances: Array[Vector2i], zone_map: _ZoneMapScript, _orientation: int = 0) -> void:
	# Recesses along walls marked as wall_niche zones
	if w >= 8:
		for x in range(rect.position.x + 2, rect.end.x - 2, 3):
			var niche_north := Vector2i(x, rect.position.y)
			var niche_south := Vector2i(x, rect.end.y - 1)
			if grid.is_walkable(niche_north) and not entrances.has(niche_north):
				zone_map.set_zone(niche_north, &"wall_niche")
			if grid.is_walkable(niche_south) and not entrances.has(niche_south):
				zone_map.set_zone(niche_south, &"wall_niche")

static func _resolve_anchor_coordinate(rect: Rect2i, loc: StringName, orientation: int, center: Vector2i) -> Vector2i:
	var effective_loc: StringName = _rotate_location_by_orientation(loc, orientation)

	match effective_loc:
		&"center":
			return center
		&"north_wall", &"north":
			return Vector2i(center.x, rect.position.y + 1)
		&"south_wall", &"south":
			return Vector2i(center.x, rect.end.y - 2)
		&"east_wall", &"east":
			return Vector2i(rect.end.x - 2, center.y)
		&"west_wall", &"west":
			return Vector2i(rect.position.x + 1, center.y)
		&"south_west":
			return Vector2i(rect.position.x + 1, rect.end.y - 2)
		&"south_east":
			return Vector2i(rect.end.x - 2, rect.end.y - 2)
		&"north_west":
			return Vector2i(rect.position.x + 1, rect.position.y + 1)
		&"north_east":
			return Vector2i(rect.end.x - 2, rect.position.y + 1)
		&"west_flank":
			return Vector2i(rect.position.x + 1, center.y)
		&"east_flank":
			return Vector2i(rect.end.x - 2, center.y)
		&"perimeter":
			return Vector2i(rect.position.x + 1, rect.position.y + 1)
		_:
			return center

static func _rotate_location_by_orientation(loc: StringName, orientation: int) -> StringName:
	if orientation == 0:
		return loc
	var dir_map: Dictionary = {
		&"north_wall": [&"north_wall", &"east_wall", &"south_wall", &"west_wall"],
		&"south_wall": [&"south_wall", &"west_wall", &"north_wall", &"east_wall"],
		&"east_wall": [&"east_wall", &"south_wall", &"west_wall", &"north_wall"],
		&"west_wall": [&"west_wall", &"north_wall", &"east_wall", &"south_wall"],
		&"north": [&"north", &"east", &"south", &"west"],
		&"south": [&"south", &"west", &"north", &"east"],
		&"east": [&"east", &"south", &"west", &"north"],
		&"west": [&"west", &"north", &"east", &"south"],
		&"south_west": [&"south_west", &"north_west", &"north_east", &"south_east"],
		&"south_east": [&"south_east", &"south_west", &"north_west", &"north_east"],
		&"west_flank": [&"west_flank", &"north_wall", &"east_flank", &"south_wall"],
		&"east_flank": [&"east_flank", &"south_wall", &"west_flank", &"north_wall"]
	}
	if dir_map.has(loc):
		var list = dir_map[loc]
		return list[posmod(orientation, 4)]
	return loc

static func _find_nearest_walkable_cell(grid: CellGrid, rect: Rect2i, target: Vector2i) -> Vector2i:
	if grid.is_walkable(target):
		return target
	var best_cell: Vector2i = target
	var min_dist: int = 999999
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if grid.is_walkable(cell):
				var dist: int = abs(x - target.x) + abs(y - target.y)
				if dist < min_dist:
					min_dist = dist
					best_cell = cell
	return best_cell

static func _set_wall_if_not_entrance(grid: CellGrid, pos: Vector2i, entrances: Array[Vector2i]) -> void:
	for ent in entrances:
		if abs(ent.x - pos.x) <= 1 and abs(ent.y - pos.y) <= 1:
			return # Do not block or place wall near entrance
	grid.set_cell(pos, CellGrid.CellType.WALL)

static func _is_on_boundary(rect: Rect2i, p: Vector2i) -> bool:
	return p.x == rect.position.x or p.x == rect.end.x - 1 or p.y == rect.position.y or p.y == rect.end.y - 1

static func _is_adjacent_to_wall(grid: CellGrid, pos: Vector2i) -> bool:
	for offset in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
		var neighbor: Vector2i = pos + offset
		if not grid.is_walkable(neighbor):
			return true
	return false

static func _ensure_path_to_center(grid: CellGrid, rect: Rect2i, from_pos: Vector2i, to_pos: Vector2i) -> void:
	var cur := from_pos
	while cur.x != to_pos.x:
		cur.x += 1 if to_pos.x > cur.x else -1
		if rect.has_point(cur):
			grid.set_cell(cur, CellGrid.CellType.FLOOR)
	while cur.y != to_pos.y:
		cur.y += 1 if to_pos.y > cur.y else -1
		if rect.has_point(cur):
			grid.set_cell(cur, CellGrid.CellType.FLOOR)
