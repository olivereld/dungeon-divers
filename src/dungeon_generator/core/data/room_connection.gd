class_name RoomConnection
extends RefCounted

## Contrato de datos lógico: relación topológica entre dos habitaciones.
## Representa la intención de conectar dos salas sin mezclar geometría ni paths A*.

var id: int = 0
var room_a_id: int = -1
var room_b_id: int = -1
var is_required: bool = true
var connection_type: StringName = &"corridor"

func _init(p_id: int = 0, p_a: int = -1, p_b: int = -1, p_required: bool = true, p_type: StringName = &"corridor") -> void:
	id = p_id
	room_a_id = p_a
	room_b_id = p_b
	is_required = p_required
	connection_type = p_type

func get_other_room_id(room_id: int) -> int:
	if room_id == room_a_id:
		return room_b_id
	if room_id == room_b_id:
		return room_a_id
	return -1

func connects_room(room_id: int) -> bool:
	return room_id == room_a_id or room_id == room_b_id
