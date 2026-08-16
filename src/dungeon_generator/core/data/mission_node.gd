class_name MissionNode
extends RefCounted

## Nodo semántico del grafo de misiones.
## Maneja la lógica abstracta de tareas, requerimientos y dependencias (cerraduras/llaves genéricas).

enum ActionType {
	START,              # Punto de inicio
	EXPLORE,            # Explorar área
	FIND_KEY,           # Encontrar llave genérica
	UNLOCK,             # Desbloquear puerta/celda genérica
	COMBAT,             # Encuentro de combate
	MINI_BOSS,          # Mini-jefe
	BOSS,               # Jefe principal
	PUZZLE,             # Puzzle ambiental
	TREASURE,           # Cofre de tesoro
	GOAL,               # Objetivo final del nivel
	PASSAGE_DOWN,       # Pasaje al siguiente piso
}

var action: ActionType = ActionType.EXPLORE
var required_items: Array[StringName] = []      # e.g. [&"cell_key"] - se consumen al resolverse
var grants_items: Array[StringName] = []        # e.g. [&"cell_key"] - se adquieren al resolverse
var difficulty_weight: float = 1.0
var is_optional: bool = false
var room_type_hint: StringName = &""

func _init(p_action: ActionType = ActionType.EXPLORE) -> void:
	action = p_action
	_apply_default_hints()

func _apply_default_hints() -> void:
	match action:
		ActionType.START:
			room_type_hint = &"start"
		ActionType.EXPLORE:
			room_type_hint = &"explore"
		ActionType.FIND_KEY:
			room_type_hint = &"treasure"
		ActionType.UNLOCK:
			room_type_hint = &"puzzle"
		ActionType.COMBAT:
			room_type_hint = &"combat"
		ActionType.MINI_BOSS:
			room_type_hint = &"combat"
		ActionType.BOSS:
			room_type_hint = &"boss"
		ActionType.PUZZLE:
			room_type_hint = &"puzzle"
		ActionType.TREASURE:
			room_type_hint = &"treasure"
		ActionType.GOAL:
			room_type_hint = &"goal"
		ActionType.PASSAGE_DOWN:
			room_type_hint = &"goal"

func to_dictionary() -> Dictionary:
	return {
		"action": action,
		"action_name": ActionType.keys()[action],
		"required_items": required_items.duplicate(),
		"grants_items": grants_items.duplicate(),
		"difficulty_weight": difficulty_weight,
		"is_optional": is_optional,
		"room_type_hint": room_type_hint
	}

static func from_dictionary(dict: Dictionary) -> MissionNode:
	var node := MissionNode.new()
	if dict.has("action"):
		node.action = dict["action"] as ActionType
	elif dict.has("action_name"):
		var key_idx: int = ActionType.keys().find(dict["action_name"])
		if key_idx != -1:
			node.action = key_idx as ActionType
	if dict.has("required_items"):
		node.required_items = Array(dict["required_items"], TYPE_STRING_NAME, &"", null)
	if dict.has("grants_items"):
		node.grants_items = Array(dict["grants_items"], TYPE_STRING_NAME, &"", null)
	node.difficulty_weight = float(dict.get("difficulty_weight", 1.0))
	node.is_optional = bool(dict.get("is_optional", false))
	node.room_type_hint = StringName(dict.get("room_type_hint", &""))
	return node
