class_name SolidRegion
extends RefCounted

## Representa una región de masa sólida continua (conjunto conexo de celdas WALL).
## Modela la geometría volumétrica completa de los muros sin depender de cáscaras perimetrales delgadas.

var id: int = -1
var cells: Array[Vector2i] = []
var cell_set: Dictionary = {} # Vector2i -> true
var exterior_faces: Array[Dictionary] = [] # Array de diccionarios {cell, side, neighbor, is_opening, room_owner}

func _init(p_id: int = -1) -> void:
	id = p_id

func add_cell(cell: Vector2i) -> void:
	if not cell_set.has(cell):
		cell_set[cell] = true
		cells.append(cell)

func has_cell(cell: Vector2i) -> bool:
	return cell_set.has(cell)

func get_cell_count() -> int:
	return cells.size()

func add_exterior_face(cell: Vector2i, side: int, neighbor: Vector2i, is_opening: bool = false, room_owner: int = -1) -> void:
	exterior_faces.append({
		"cell": cell,
		"side": side,
		"neighbor": neighbor,
		"is_opening": is_opening,
		"room_owner": room_owner
	})
