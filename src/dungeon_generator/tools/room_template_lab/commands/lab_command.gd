class_name LabCommand
extends RefCounted

## Interfaz base para comandos ejecutables y reversibles (Undo/Redo) en el Lab.

func execute() -> void:
	pass

func undo() -> void:
	pass

func merge_with(_other: LabCommand) -> bool:
	return false
