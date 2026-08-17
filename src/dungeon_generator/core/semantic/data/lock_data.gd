class_name LockData
extends RefCounted

## Contrato de datos lógico: Representa una cerradura sobre una conexión concreta entre dos salas.
## Bloquea el tránsito bidireccionalmente (room_a <-> room_b) hasta que el jugador posea la llave requerida.
## 100% puro: no depende de nodos visuales ni renderizado.

var lock_id: int = 0
var connection_id: int = -1             # ID de la RoomConnection bloqueada (Autoridad Estructural Única)
var room_a_id: int = -1                 # Sala origen
var room_b_id: int = -1                 # Sala destino
var required_key_id: int = -1           # ID de la KeyData requerida para cruzar

func _init(
	p_lock_id: int = 0,
	p_conn_id: int = -1,
	p_room_a: int = -1,
	p_room_b: int = -1,
	p_req_key_id: int = -1
) -> void:
	lock_id = p_lock_id
	connection_id = p_conn_id
	room_a_id = p_room_a
	room_b_id = p_room_b
	required_key_id = p_req_key_id

func connects_room(room_id: int) -> bool:
	return room_id == room_a_id or room_id == room_b_id

func get_other_room_id(room_id: int) -> int:
	if room_id == room_a_id:
		return room_b_id
	if room_id == room_b_id:
		return room_a_id
	return -1

func to_debug_string() -> String:
	return "LockData(id: %d, conn_id: %d, rooms: %d <-> %d, req_key: %d)" % [
		lock_id, connection_id, room_a_id, room_b_id, required_key_id
	]
