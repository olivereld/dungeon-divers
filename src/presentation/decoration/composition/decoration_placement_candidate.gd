class_name DecorationPlacementCandidate
extends RefCounted

## Estructura evaluable de candidato a colocación espacial de un prop o fixture.

var style_id: StringName = &""
var style: RefCounted = null
var cell: Vector2i = Vector2i.ZERO
var world_position: Vector3 = Vector3.ZERO
var rotation_y: float = 0.0
var occupied_cells: Array[Vector2i] = []
var clearance_cells: Array[Vector2i] = []
var score: float = 0.0
var violations: Array[StringName] = []

func is_valid() -> bool:
	return violations.is_empty()
