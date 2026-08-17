class_name StructuralValidator
extends RefCounted

## Validador estructural del modelo de datos de la mazmorra (Fase 2).
## Comprueba la integridad formal del CellGrid, RoomData y RoomConnection sin mezclar lógica de conectividad.

class ValidationReport extends RefCounted:
	var is_valid: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []

	func add_error(msg: String) -> void:
		is_valid = false
		errors.append(msg)

	func add_warning(msg: String) -> void:
		warnings.append(msg)

func validate_structure(grid: CellGrid, rooms: Array[RoomData], connections: Array = []) -> ValidationReport:
	var report := ValidationReport.new()

	# 1. Validación de CellGrid
	if grid == null:
		report.add_error("CellGrid is null")
		return report

	if grid.width <= 0 or grid.height <= 0:
		report.add_error("Invalid CellGrid dimensions: %dx%d" % [grid.width, grid.height])

	# 2. Validación de Habitaciones
	if rooms.is_empty():
		report.add_warning("Rooms array is empty")

	var seen_room_ids: Dictionary = {}
	for i in range(rooms.size()):
		var room: RoomData = rooms[i]
		if room == null:
			report.add_error("Room at index %d is null" % i)
			continue

		if seen_room_ids.has(room.id):
			report.add_error("Duplicate Room ID: %d at index %d" % [room.id, i])
		seen_room_ids[room.id] = true

		if room.rect.size.x <= 0 or room.rect.size.y <= 0:
			report.add_error("Room %d has invalid size: %s" % [room.id, str(room.rect.size)])

		# Verificar que la sala esté contenida en el CellGrid
		if not grid.get_bounds().encloses(room.rect):
			report.add_error("Room %d bounds %s exceed grid bounds %s" % [room.id, str(room.rect), str(grid.get_bounds())])

		var center := room.get_center()
		if not grid.is_in_bounds(center):
			report.add_error("Room %d center %s is outside grid bounds" % [room.id, str(center)])

	# 3. Validación de Conexiones
	var seen_conn_ids: Dictionary = {}
	for i in range(connections.size()):
		var conn = connections[i]
		if conn == null:
			report.add_error("Connection at index %d is null" % i)
			continue

		if seen_conn_ids.has(conn.id):
			report.add_error("Duplicate Connection ID: %d" % conn.id)
		seen_conn_ids[conn.id] = true

		if conn.room_a_id == conn.room_b_id:
			report.add_error("Connection %d is a self-connection (room %d to %d)" % [conn.id, conn.room_a_id, conn.room_b_id])

		if not seen_room_ids.has(conn.room_a_id):
			report.add_error("Connection %d references non-existent room_a_id: %d" % [conn.id, conn.room_a_id])
		if not seen_room_ids.has(conn.room_b_id):
			report.add_error("Connection %d references non-existent room_b_id: %d" % [conn.id, conn.room_b_id])

	return report

## Valida que una habitación individual tenga estrictamente una única región transitable conexa (sin islas).
static func validate_room_internal_connectivity(grid: CellGrid, room: RoomData) -> Dictionary:
	if grid == null or room == null:
		return {
			"is_valid": false,
			"reason": "NULL_INPUT",
			"room_id": -1,
			"region_count": 0,
			"regions": []
		}

	var rect := room.rect
	var visited: Dictionary = {}
	var regions: Array = []

	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var pos := Vector2i(x, y)
			if grid.is_walkable(pos) and not visited.has(pos):
				var region: Array[Vector2i] = []
				var stack: Array[Vector2i] = [pos]
				visited[pos] = true

				while not stack.is_empty():
					var curr: Vector2i = stack.pop_back()
					region.append(curr)

					for n in grid.get_neighbors_4(curr):
						if rect.has_point(n) and grid.is_walkable(n) and not visited.has(n):
							visited[n] = true
							stack.append(n)

				if not region.is_empty():
					regions.append(region)

	var is_valid: bool = (regions.size() == 1)
	var reason: String = "OK" if is_valid else ("EMPTY_ROOM" if regions.is_empty() else "FRAGMENTED_ROOM")

	return {
		"is_valid": is_valid,
		"reason": reason,
		"room_id": room.id,
		"region_count": regions.size(),
		"regions": regions
	}
