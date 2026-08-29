class_name CommandHistory
extends RefCounted

## Administrador de pila de comandos con soporte de Undo/Redo y profundidad configurable.

signal history_changed()

var _undo_stack: Array[LabCommand] = []
var _redo_stack: Array[LabCommand] = []
var _max_depth: int = 100

func _init(max_depth: int = 100) -> void:
	_max_depth = max_depth

func execute(cmd: LabCommand) -> void:
	if cmd == null:
		return
	cmd.execute()
	_undo_stack.append(cmd)
	_redo_stack.clear()

	if _undo_stack.size() > _max_depth:
		_undo_stack.pop_front()

	history_changed.emit()

func undo() -> void:
	if _undo_stack.is_empty():
		return
	var cmd = _undo_stack.pop_back()
	cmd.undo()
	_redo_stack.append(cmd)
	history_changed.emit()

func redo() -> void:
	if _redo_stack.is_empty():
		return
	var cmd = _redo_stack.pop_back()
	cmd.execute()
	_undo_stack.append(cmd)
	history_changed.emit()

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()
	history_changed.emit()
