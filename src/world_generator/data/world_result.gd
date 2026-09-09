class_name WorldResult
extends RefCounted

var dimensions: Vector2i = Vector2i.ZERO
var master_seed: int = 0
var cells: Dictionary = {}  # Vector2i -> WorldCell
var vegetation: Array = []  # Array[WorldVegetationItem]
var spawn_position: Vector3 = Vector3.ZERO
var hydrology: RefCounted = null  # HydrologyResult
var metadata: Dictionary = {}

func get_cell(pos: Vector2i) -> WorldCell:
	return cells.get(pos, null)

func has_cell(pos: Vector2i) -> bool:
	return cells.has(pos)
