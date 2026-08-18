class_name DungeonChecksumCalculator
extends RefCounted

## Calculador canónico de checksums deterministas para DungeonResult (Fase 4).
## Genera un hash SHA-256 determinista e independiente del orden de almacenamiento en memoria
## cubriendo el estado espacial completo, topología y umbrales de puerta.

## Calcula el checksum SHA-256 en formato hex del resultado de una mazmorra.
static func compute_checksum(result: DungeonResult) -> String:
	if result == null or result.grid == null:
		return ""

	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)

	# 1. Rejilla Espacial (Ancho, Alto y Buffer plano de celdas)
	var w: int = result.grid.get_width()
	var h: int = result.grid.get_height()
	var grid_header := "%d,%d:" % [w, h]
	ctx.update(grid_header.to_utf8_buffer())

	var cell_bytes := PackedByteArray()
	cell_bytes.resize(w * h * 4)
	for y in range(h):
		for x in range(w):
			var idx: int = (y * w + x) * 4
			var cell_val: int = int(result.grid.get_cell(Vector2i(x, y)))
			cell_bytes.encode_s32(idx, cell_val)
	ctx.update(cell_bytes)

	# 2. Habitaciones (Ordenadas canónicamente por id)
	var sorted_rooms: Array[RoomData] = result.rooms.duplicate()
	sorted_rooms.sort_custom(func(a: RoomData, b: RoomData) -> bool:
		return a.id < b.id
	)
	var rooms_str := "|ROOMS:"
	for r in sorted_rooms:
		rooms_str += "[%d:%d,%d,%d,%d:%s]" % [
			r.id, r.rect.position.x, r.rect.position.y, r.rect.size.x, r.rect.size.y, str(r.room_type)
		]
	ctx.update(rooms_str.to_utf8_buffer())

	# 3. Conexiones (Ordenadas canónicamente por id)
	var sorted_conns: Array = result.connections.duplicate()
	sorted_conns.sort_custom(func(a, b) -> bool:
		return a.id < b.id
	)
	var conns_str := "|CONNS:"
	for c in sorted_conns:
		conns_str += "[%d:%d-%d:%s]" % [
			c.id, c.room_a_id, c.room_b_id, str(c.is_required)
		]
	ctx.update(conns_str.to_utf8_buffer())

	# 4. Puertas (Ordenadas canónicamente por connection_id y room_id)
	var sorted_doors: Array = result.doors.duplicate()
	sorted_doors.sort_custom(func(a, b) -> bool:
		if a.connection_id != b.connection_id:
			return a.connection_id < b.connection_id
		return a.room_id < b.room_id
	)
	var doors_str := "|DOORS:"
	for d in sorted_doors:
		doors_str += "[%d:%d:%d,%d:%d:%d]" % [
			d.connection_id, d.room_id, d.position.x, d.position.y, d.side, d.door_type
		]
	ctx.update(doors_str.to_utf8_buffer())

	var digest := ctx.finish()
	return digest.hex_encode()
