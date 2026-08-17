class_name DoorPair
extends RefCounted

## Contrato de datos lógico: Relaciona las dos puertas asociadas a una RoomConnection aceptada.

var connection_id: int = -1
var door_a: DoorPlacement = null
var door_b: DoorPlacement = null

func _init(
	p_conn_id: int = -1,
	p_a: DoorPlacement = null,
	p_b: DoorPlacement = null
) -> void:
	connection_id = p_conn_id
	door_a = p_a
	door_b = p_b

func is_valid() -> bool:
	return door_a != null and door_b != null and door_a.room_id != door_b.room_id and door_a.position != door_b.position

func to_debug_string() -> String:
	var s_a := door_a.to_debug_string() if door_a != null else "null"
	var s_b := door_b.to_debug_string() if door_b != null else "null"
	return "DoorPair(Conn: %d, A: %s, B: %s)" % [connection_id, s_a, s_b]
