class_name LockData
extends RefCounted

## Contrato de datos lógico: Representa una cerradura sobre una conexión entre salas.
## Estructura formal de Fase 6: id, room_id / edge, required_key_id, progression_index.
## Bloquea el tránsito bidireccionalmente hasta que el jugador posea la llave requerida.
## 100% puro: no depende de nodos visuales ni de RoomData.

var id: int:
	get: return lock_id
	set(v):
		assert(not _is_sealed, "LockData is sealed and immutable.")
		if not _is_sealed: lock_id = v

var lock_id: int = 0
var connection_id: int = -1             # ID de la RoomConnection bloqueada

var room_id: int:
	get: return room_a_id
	set(v):
		assert(not _is_sealed, "LockData is sealed and immutable.")
		if not _is_sealed: room_a_id = v

var edge: Vector2i:
	get: return Vector2i(room_a_id, room_b_id)
	set(v):
		assert(not _is_sealed, "LockData is sealed and immutable.")
		if not _is_sealed:
			room_a_id = v.x
			room_b_id = v.y

var room_a_id: int = -1                 # Sala origen
var room_b_id: int = -1                 # Sala destino
var required_key_id: int = -1           # ID explícito de la KeyData requerida (bidireccionalidad estricta)
var progression_index: int = 0
var _is_sealed: bool = false

func seal() -> void:
	_is_sealed = true

func is_sealed() -> bool:
	return _is_sealed

func _init(
	p_lock_id: int = 0,
	p_conn_id: int = -1,
	p_room_a: int = -1,
	p_room_b: int = -1,
	p_req_key_id: int = -1,
	p_progression_index: int = 0
) -> void:
	lock_id = p_lock_id
	connection_id = p_conn_id
	room_a_id = p_room_a
	room_b_id = p_room_b
	required_key_id = p_req_key_id
	progression_index = p_progression_index

func connects_room(r_id: int) -> bool:
	return r_id == room_a_id or r_id == room_b_id

func get_other_room_id(r_id: int) -> int:
	if r_id == room_a_id:
		return room_b_id
	if r_id == room_b_id:
		return room_a_id
	return -1

func to_debug_string() -> String:
	return "LockData(id: %d, conn_id: %d, rooms: %d <-> %d, req_key: %d, prog: %d)" % [
		lock_id, connection_id, room_a_id, room_b_id, required_key_id, progression_index
	]
