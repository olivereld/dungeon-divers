class_name DoorPlacement
extends RefCounted

## Contrato de datos lógico: Representa una puerta estructural colocada en la frontera entre una sala y un corredor.

const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const _DoorTypeScript = preload("res://src/dungeon_generator/core/data/door_type.gd")

var connection_id: int = -1
var room_id: int = -1
var position: Vector2i = Vector2i.ZERO
var side: int = 0 # _RoomEntranceScript.NORTH, SOUTH, WEST, EAST
var room_cell: Vector2i = Vector2i.ZERO     # Celda interior transitable (FLOOR)
var corridor_cell: Vector2i = Vector2i.ZERO # Celda exterior transitable (CORRIDOR)
var door_type: int = _DoorTypeScript.DoorType.CLOSED_DOOR
var reason: String = "DEFAULT"

func is_open_passage() -> bool:
	return door_type == _DoorTypeScript.DoorType.OPEN_PASSAGE

func _init(
	p_conn_id: int = -1,
	p_room_id: int = -1,
	p_pos: Vector2i = Vector2i.ZERO,
	p_side: int = 0,
	p_room_cell: Vector2i = Vector2i.ZERO,
	p_corr_cell: Vector2i = Vector2i.ZERO
) -> void:
	connection_id = p_conn_id
	room_id = p_room_id
	position = p_pos
	side = p_side
	room_cell = p_room_cell
	corridor_cell = p_corr_cell

func to_debug_string() -> String:
	return "DoorPlacement(Conn: %d, Room: %d, Pos: %s, Side: %s, RoomCell: %s, CorrCell: %s)" % [
		connection_id, room_id, str(position), _RoomEntranceScript.side_to_string(side), str(room_cell), str(corridor_cell)
	]
