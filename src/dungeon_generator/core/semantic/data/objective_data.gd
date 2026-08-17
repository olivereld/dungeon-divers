class_name ObjectiveData
extends RefCounted

## Contrato de datos lógico: Representa puntos de interés y objetivos de misión en la mazmorra.
## Diferencia formalmente entre objetivos obligatorios (SPAWN, BOSS, MAIN_QUEST_ITEM, STAIRS_DOWN)
## y objetivos opcionales (TREASURE, LORE, SIDE_QUEST).

enum ObjectiveType {
	SPAWN,
	BOSS,
	QUEST_ITEM,
	TREASURE,
	STAIRS_DOWN,
	STAIRS_UP,
	LORE
}

var objective_id: int = 0
var type: ObjectiveType = ObjectiveType.QUEST_ITEM
var room_id: int = -1
var position: Vector2i = Vector2i.ZERO
var is_mandatory: bool = true          # true: Obligatorio para completar el nivel; false: Opcional
var required_key_id: int = -1          # -1 si no requiere llave previa directa

func _init(
	p_id: int = 0,
	p_type: ObjectiveType = ObjectiveType.QUEST_ITEM,
	p_room_id: int = -1,
	p_position: Vector2i = Vector2i.ZERO,
	p_is_mandatory: bool = true,
	p_req_key_id: int = -1
) -> void:
	objective_id = p_id
	type = p_type
	room_id = p_room_id
	position = p_position
	is_mandatory = p_is_mandatory
	required_key_id = p_req_key_id

static func type_to_string(p_type: ObjectiveType) -> String:
	match p_type:
		ObjectiveType.SPAWN: return "SPAWN"
		ObjectiveType.BOSS: return "BOSS"
		ObjectiveType.QUEST_ITEM: return "QUEST_ITEM"
		ObjectiveType.TREASURE: return "TREASURE"
		ObjectiveType.STAIRS_DOWN: return "STAIRS_DOWN"
		ObjectiveType.STAIRS_UP: return "STAIRS_UP"
		ObjectiveType.LORE: return "LORE"
		_: return "UNKNOWN"

func to_debug_string() -> String:
	return "ObjectiveData(id: %d, type: %s, room: %d, pos: %s, mandatory: %s, req_key: %d)" % [
		objective_id, type_to_string(type), room_id, str(position), str(is_mandatory), required_key_id
	]
