class_name PlaceAnchorCommand
extends LabCommand

## Comando atómico para posicionar o remover anclajes en el canvas.

var _state: RoomTemplateLabState
var _anchor_id: StringName
var _new_pos: Vector2i
var _old_pos: Vector2i
var _had_old: bool = false
var _is_required: bool = true
var _loc_hint: StringName = &"center"

func _init(state: RoomTemplateLabState, anchor_id: StringName, new_pos: Vector2i, is_required: bool = true, loc_hint: StringName = &"center") -> void:
	_state = state
	_anchor_id = anchor_id
	_new_pos = new_pos
	_is_required = is_required
	_loc_hint = loc_hint
	_had_old = _state.has_anchor(anchor_id)
	if _had_old:
		_old_pos = _state.get_anchor(anchor_id)

func execute() -> void:
	if _state == null:
		return
	_state.set_anchor(_anchor_id, _new_pos, _is_required, _loc_hint)

func undo() -> void:
	if _state == null:
		return
	if _had_old:
		_state.set_anchor(_anchor_id, _old_pos, _is_required, _loc_hint)
	else:
		_state.remove_anchor(_anchor_id)
