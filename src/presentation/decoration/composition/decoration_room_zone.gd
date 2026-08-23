class_name DecorationRoomZone
extends RefCounted

## Particionador espacial de salas en zonas funcionales y semánticas.

enum ZoneType {
	ENTRY = 0,       ## Zona inmediata de acceso/puertas
	TRAVERSAL = 1,   ## Pasillo natural de circulación de jugadores
	FOCAL = 2,       ## Centro de atención visual dominante
	SIDE = 3,        ## Flanco lateral intermedio
	CORNER = 4,      ## Rincones y esquinas estructurales
	CENTER = 5,      ## Núcleo central de la sala
	PERIMETER = 6    ## Bordes y zócalos de muro
}

static func zone_to_name(p_zone: int) -> String:
	match p_zone:
		ZoneType.ENTRY:
			return "ENTRY"
		ZoneType.TRAVERSAL:
			return "TRAVERSAL"
		ZoneType.FOCAL:
			return "FOCAL"
		ZoneType.SIDE:
			return "SIDE"
		ZoneType.CORNER:
			return "CORNER"
		ZoneType.CENTER:
			return "CENTER"
		ZoneType.PERIMETER:
			return "PERIMETER"
		_:
			return "UNKNOWN"

func partition_room(room_geom, tile_size: float = 2.0) -> Dictionary:
	var result: Dictionary = {} # Vector2i -> ZoneType

	if room_geom == null or room_geom.floor_cells.is_empty():
		return result

	var floor_map: Dictionary = {}
	for fc in room_geom.floor_cells:
		floor_map[fc] = true

	var door_cells: Array[Vector2i] = []
	if "door_positions" in room_geom and room_geom.door_positions != null:
		for d in room_geom.door_positions:
			door_cells.append(d as Vector2i)
	elif "door_cells" in room_geom and room_geom.door_cells != null:
		for d in room_geom.door_cells:
			door_cells.append(d as Vector2i)

	# Calcular centroide geométrico
	var sum_x: int = 0
	var sum_y: int = 0
	for c in room_geom.floor_cells:
		sum_x += c.x
		sum_y += c.y
	var center_cell := Vector2i(sum_x / room_geom.floor_cells.size(), sum_y / room_geom.floor_cells.size())

	for cell in room_geom.floor_cells:
		# 1. Puertas y acceso directo
		var min_door_dist: int = 999
		for d in door_cells:
			var d_dist = absi(cell.x - d.x) + absi(cell.y - d.y)
			if d_dist < min_door_dist:
				min_door_dist = d_dist

		if min_door_dist == 0:
			result[cell] = ZoneType.ENTRY
			continue
		elif min_door_dist == 1:
			result[cell] = ZoneType.ENTRY
			continue
		elif min_door_dist == 2:
			result[cell] = ZoneType.TRAVERSAL
			continue

		# 2. Esquinas y perímetro
		var neighbor_walls: int = 0
		var is_corner: bool = false
		var has_north_wall = not floor_map.has(cell + Vector2i(0, -1))
		var has_south_wall = not floor_map.has(cell + Vector2i(0, 1))
		var has_west_wall = not floor_map.has(cell + Vector2i(-1, 0))
		var has_east_wall = not floor_map.has(cell + Vector2i(1, 0))

		if (has_north_wall and has_west_wall) or (has_north_wall and has_east_wall) or \
		   (has_south_wall and has_west_wall) or (has_south_wall and has_east_wall):
			result[cell] = ZoneType.CORNER
			continue

		if has_north_wall or has_south_wall or has_west_wall or has_east_wall:
			result[cell] = ZoneType.PERIMETER
			continue

		# 3. Centro focal vs flancos
		var dist_to_center: float = Vector2(cell).distance_to(Vector2(center_cell))
		if dist_to_center <= 1.2:
			result[cell] = ZoneType.FOCAL
		elif dist_to_center <= 2.2:
			result[cell] = ZoneType.CENTER
		else:
			result[cell] = ZoneType.SIDE

	return result
