class_name PlaceEntranceCommand
extends LabCommand

## Comando atómico para añadir o remover entradas en el canvas.

var _state: RoomTemplateLabState
var _pos: Vector2i
var _add_mode: bool = true
var _was_present: bool = false

func _init(state: RoomTemplateLabState, pos: Vector2i, add_mode: bool = true) -> void:
	_state = state
	_pos = pos
	_add_mode = add_mode
	_was_present = _state.get_entrances().has(pos)

func execute() -> void:
	if _state == null:
		return
	if _add_mode:
		_state.add_entrance(_pos)
	else:
		_state.remove_entrance(_pos)

func undo() -> void:
	if _state == null:
		return
	if _was_present:
		_state.add_entrance(_pos)
	else:
		_state.remove_entrance(_pos)
