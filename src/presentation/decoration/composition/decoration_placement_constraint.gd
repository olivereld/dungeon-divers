class_name DecorationPlacementConstraint
extends Resource

## Restricciones duras (Hard Constraints) y de despeje para validación de colocación de props y fixtures.

@export var cannot_overlap: bool = true
@export var cannot_touch_door: bool = true
@export var cannot_touch_stairs: bool = true
@export var must_be_floor: bool = true
@export var must_have_clear_approach: bool = false
@export var min_clearance_cells: int = 0

## Evalúa las restricciones duras contra el contexto geométrico y de ocupación.
## Retorna una lista de identificadores de violación (vacía si es 100% válido).
func check_hard_constraints(
	footprint_cells: Array[Vector2i],
	floor_cells_map: Dictionary,
	reserved_cells_map: Dictionary,
	occupied_cells_map: Dictionary,
	door_cells: Array[Vector2i] = [],
	stair_cells: Array[Vector2i] = []
) -> Array[StringName]:
	var violations: Array[StringName] = []

	for cell in footprint_cells:
		if must_be_floor and not floor_cells_map.has(cell):
			violations.append(&"MUST_BE_FLOOR")
			break

		if cannot_overlap and occupied_cells_map.has(cell):
			violations.append(&"CANNOT_OVERLAP")
			break

		if cannot_touch_door:
			if door_cells.has(cell) or (reserved_cells_map.has(cell) and reserved_cells_map[cell] == &"door_approach"):
				violations.append(&"CANNOT_TOUCH_DOOR")
				break

		if cannot_touch_stairs:
			if stair_cells.has(cell) or (reserved_cells_map.has(cell) and reserved_cells_map[cell] == &"stair_approach"):
				violations.append(&"CANNOT_TOUCH_STAIRS")
				break

	return violations
