class_name KeyData
extends RefCounted

## Contrato de datos lógico: Representa una llave colocada en una sala para desbloquear un LockData.
## Estructura formal de Fase 6: id, room_id, unlocks, progression_index.
## 100% puro: no depende de nodos visuales ni de RoomData.

var id: int:
	get: return key_id
	set(v):
		assert(not _is_sealed, "KeyData is sealed and immutable.")
		if not _is_sealed: key_id = v

var key_id: int = 0
var name: StringName = &"key_iron"
var room_id: int = -1
var position: Vector2i = Vector2i.ZERO # Celda transitable lógica dentro de la sala
var unlocks: int = -1                  # ID explícito del LockData correspondiente (bidireccionalidad estricta)
var progression_index: int = 0
var _is_sealed: bool = false

func seal() -> void:
	_is_sealed = true

func is_sealed() -> bool:
	return _is_sealed

func _init(
	p_key_id: int = 0,
	p_name: StringName = &"key_iron",
	p_room_id: int = -1,
	p_position: Vector2i = Vector2i.ZERO,
	p_unlocks: int = -1,
	p_progression_index: int = 0
) -> void:
	key_id = p_key_id
	name = p_name
	room_id = p_room_id
	position = p_position
	unlocks = p_unlocks
	progression_index = p_progression_index

func to_debug_string() -> String:
	return "KeyData(id: %d, name: %s, room: %d, unlocks_lock: %d, prog: %d, pos: %s)" % [
		key_id, name, room_id, unlocks, progression_index, str(position)
	]
