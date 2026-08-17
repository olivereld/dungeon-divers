class_name DoorTransitionValidator
extends RefCounted

## Validador local y global de transiciones arquitectónicas ROOM <-> DOOR <-> CORRIDOR.

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _DoorPlacementScript = preload("res://src/dungeon_generator/core/data/door_placement.gd")
const _DoorPairScript = preload("res://src/dungeon_generator/core/data/door_pair.gd")

## Valida la transición local ROOM ↔ DOOR ↔ CORRIDOR para un DoorPlacement individual.
static func validate_local_transition(grid: CellGrid, door: DoorPlacement, room: RoomData) -> Dictionary:
	if door == null:
		return {"is_valid": false, "reason": "NULL_DOOR"}

	var pos := door.position
	var r_cell := door.room_cell
	var c_cell := door.corridor_cell

	# 1. Bounds de grid
	if not grid.is_in_bounds(pos):
		return {"is_valid": false, "reason": "DOOR_OUT_OF_BOUNDS"}
	if not grid.is_in_bounds(r_cell):
		return {"is_valid": false, "reason": "ROOM_CELL_OUT_OF_BOUNDS"}
	if not grid.is_in_bounds(c_cell):
		return {"is_valid": false, "reason": "CORRIDOR_CELL_OUT_OF_BOUNDS"}

	# 2. Protección de celdas especiales y obstáculos
	var current_cell_type := grid.get_cell(pos)
	if current_cell_type in [
		CellGrid.CellType.SPAWN,
		CellGrid.CellType.OBJECTIVE,
		CellGrid.CellType.STAIRS_DOWN,
		CellGrid.CellType.STAIRS_UP,
		CellGrid.CellType.COLUMN,
		CellGrid.CellType.OBSTACLE,
		CellGrid.CellType.VOID
	]:
		return {"is_valid": false, "reason": "DOOR_OVER_SPECIAL_CELL"}

	# 3. Comprobar que room_cell pertenezca a la habitación y sea transitable
	if room != null:
		if not room.rect.has_point(r_cell):
			return {"is_valid": false, "reason": "ROOM_CELL_NOT_IN_ROOM"}
		if room.rect.has_point(pos):
			return {"is_valid": false, "reason": "DOOR_INSIDE_ROOM_RECT"}
		if not room.expanded(1).has_point(pos):
			return {"is_valid": false, "reason": "DOOR_NOT_ON_PERIMETER"}

	var room_type := grid.get_cell(r_cell)
	if room_type != CellGrid.CellType.FLOOR and not grid.is_walkable(r_cell):
		return {"is_valid": false, "reason": "ROOM_CELL_NOT_WALKABLE"}

	# 4. Comprobar que corridor_cell sea un corredor válido
	var corr_type := grid.get_cell(c_cell)
	if corr_type != CellGrid.CellType.CORRIDOR and not grid.is_walkable(c_cell):
		return {"is_valid": false, "reason": "NO_CORRIDOR_AT_ENTRANCE"}

	# 5. Coherencia de orientación cardinal
	var dir := _RoomEntranceScript.side_to_direction(door.side)
	if (pos - r_cell) != dir:
		return {"is_valid": false, "reason": "INVALID_INWARD_DIRECTION"}
	if (c_cell - pos) != dir:
		return {"is_valid": false, "reason": "INVALID_OUTWARD_DIRECTION"}

	return {"is_valid": true, "reason": "OK"}

## Valida la consistencia global y ausencia de conflictos entre todas las puertas propuestas.
static func validate_global(
	grid: CellGrid,
	candidate_pairs: Array,
	connections: Array,
	rooms: Array[RoomData]
) -> Dictionary:
	var room_map: Dictionary = {}
	for r in rooms:
		if r != null:
			room_map[r.id] = r

	var conn_map: Dictionary = {}
	for c in connections:
		if c != null:
			conn_map[c.id] = c

	var seen_positions: Dictionary = {}
	var resolved_conn_ids: Dictionary = {}

	for pair in candidate_pairs:
		if pair == null:
			return {"is_valid": false, "reason": "NULL_DOOR_PAIR"}

		var conn = conn_map.get(pair.connection_id, null)
		if conn == null:
			return {"is_valid": false, "reason": "ORPHAN_DOOR_NO_CONNECTION"}

		resolved_conn_ids[pair.connection_id] = true

		var d_a: DoorPlacement = pair.door_a
		var d_b: DoorPlacement = pair.door_b

		if d_a == null or d_b == null:
			return {"is_valid": false, "reason": "INCOMPLETE_DOOR_PAIR"}

		# 1. Unicidad de posiciones (no dos puertas en la misma celda)
		if seen_positions.has(d_a.position):
			return {"is_valid": false, "reason": "DOOR_CONFLICT", "pos": d_a.position}
		seen_positions[d_a.position] = true

		if seen_positions.has(d_b.position):
			return {"is_valid": false, "reason": "DOOR_CONFLICT", "pos": d_b.position}
		seen_positions[d_b.position] = true

		# 2. Validación local de cada puerta
		var val_a := validate_local_transition(grid, d_a, room_map.get(d_a.room_id, null))
		if not val_a["is_valid"]:
			return val_a

		var val_b := validate_local_transition(grid, d_b, room_map.get(d_b.room_id, null))
		if not val_b["is_valid"]:
			return val_b

	# 3. Validar que todas las conexiones obligatorias tengan sus puertas
	for c in connections:
		if c != null and c.is_required:
			if not resolved_conn_ids.has(c.id):
				return {"is_valid": false, "reason": "MANDATORY_CONNECTION_MISSING_DOORS", "connection_id": c.id}

	return {"is_valid": true, "reason": "OK"}
