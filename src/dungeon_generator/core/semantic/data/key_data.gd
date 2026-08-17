class_name KeyData
extends RefCounted

## Contrato de datos lógico: Representa una llave colocada en una sala para desbloquear un LockData.
## 100% puro: no depende de nodos visuales ni renderizado.

var key_id: int = 0
var name: StringName = &"key_iron"
var room_id: int = -1
var position: Vector2i = Vector2i.ZERO # Celda transitable lógica dentro de la sala

func _init(
	p_key_id: int = 0,
	p_name: StringName = &"key_iron",
	p_room_id: int = -1,
	p_position: Vector2i = Vector2i.ZERO
) -> void:
	key_id = p_key_id
	name = p_name
	room_id = p_room_id
	position = p_position

func to_debug_string() -> String:
	return "KeyData(id: %d, name: %s, room: %d, pos: %s)" % [key_id, name, room_id, str(position)]
