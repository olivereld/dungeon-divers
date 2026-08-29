class_name PaintCellsCommand
extends LabCommand

## Comando atómico para pintar o borrar múltiples celdas en el canvas.

var _state: RoomTemplateLabState
var _mutations: Dictionary = {} # Vector2i -> { "old": int, "new": int }

func _init(state: RoomTemplateLabState, new_cells: Dictionary) -> void:
	_state = state
	for pos in new_cells:
		var n_val: int = new_cells[pos]
		var o_val: int = _state.get_cell(pos)
		_mutations[pos] = { "old": o_val, "new": n_val }

func execute() -> void:
	if _state == null:
		return
	for pos in _mutations:
		var entry = _mutations[pos]
		_state.set_cell(pos, entry["new"])

func undo() -> void:
	if _state == null:
		return
	for pos in _mutations:
		var entry = _mutations[pos]
		_state.set_cell(pos, entry["old"])

func merge_with(other: LabCommand) -> bool:
	if not (other is PaintCellsCommand):
		return false
	var paint_other = other as PaintCellsCommand
	if paint_other._state != _state:
		return false

	for pos in paint_other._mutations:
		var other_entry = paint_other._mutations[pos]
		if _mutations.has(pos):
			_mutations[pos]["new"] = other_entry["new"]
		else:
			_mutations[pos] = other_entry
	return true
