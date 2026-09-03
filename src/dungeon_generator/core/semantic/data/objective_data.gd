class_name ObjectiveData
extends RefCounted

## Contrato de datos lógico: Representa puntos de interés y objetivos de misión en la mazmorra.
## Estructura formal de Fase 6: id, mission_node_id, room_id, type, required, progression_index.
## 100% puro y desacoplado de RoomData.

enum ObjectiveType {
	START,
	KEY,
	OBJECTIVE,
	BOSS,
	GOAL,
	TREASURE,
	PUZZLE,
	# Aliases y tipos extendidos para compatibilidad
	SPAWN = 0,
	QUEST_ITEM = 2,
	STAIRS_DOWN = 7,
	STAIRS_UP = 8,
	LORE = 9,
	SHRINE = 10,
	ELITE = 11
}

var id: int:
	get: return objective_id
	set(v):
		assert(not _is_sealed, "ObjectiveData is sealed and immutable.")
		if not _is_sealed: objective_id = v

var objective_id: int = 0
var mission_node_id: int = -1
var room_id: int = -1
var type: int = ObjectiveType.OBJECTIVE

var required: bool:
	get: return is_mandatory
	set(v):
		assert(not _is_sealed, "ObjectiveData is sealed and immutable.")
		if not _is_sealed: is_mandatory = v

var is_mandatory: bool = true          # true: Obligatorio para completar el nivel; false: Opcional
var progression_index: int = 0
var position: Vector2i = Vector2i.ZERO
var required_key_id: int = -1          # -1 si no requiere llave previa directa
var _is_sealed: bool = false

func seal() -> void:
	_is_sealed = true

func is_sealed() -> bool:
	return _is_sealed

func _init(
	p_id: int = 0,
	p_type: int = ObjectiveType.OBJECTIVE,
	p_room_id: int = -1,
	p_position: Vector2i = Vector2i.ZERO,
	p_is_mandatory: bool = true,
	p_req_key_id: int = -1,
	p_mission_node_id: int = -1,
	p_progression_index: int = 0
) -> void:
	objective_id = p_id
	type = p_type
	room_id = p_room_id
	position = p_position
	is_mandatory = p_is_mandatory
	required_key_id = p_req_key_id
	mission_node_id = p_mission_node_id
	progression_index = p_progression_index

static func type_to_string(p_type: int) -> String:
	match p_type:
		ObjectiveType.START: return "START"
		ObjectiveType.KEY: return "KEY"
		ObjectiveType.OBJECTIVE: return "OBJECTIVE"
		ObjectiveType.BOSS: return "BOSS"
		ObjectiveType.GOAL: return "GOAL"
		ObjectiveType.TREASURE: return "TREASURE"
		ObjectiveType.PUZZLE: return "PUZZLE"
		ObjectiveType.STAIRS_DOWN: return "STAIRS_DOWN"
		ObjectiveType.STAIRS_UP: return "STAIRS_UP"
		ObjectiveType.LORE: return "LORE"
		ObjectiveType.SHRINE: return "SHRINE"
		ObjectiveType.ELITE: return "ELITE"
		_: return "UNKNOWN"

func to_debug_string() -> String:
	return "ObjectiveData(id: %d, node: %d, room: %d, type: %s, required: %s, prog: %d, pos: %s, req_key: %d)" % [
		objective_id, mission_node_id, room_id, type_to_string(type), str(is_mandatory), progression_index, str(position), required_key_id
	]
