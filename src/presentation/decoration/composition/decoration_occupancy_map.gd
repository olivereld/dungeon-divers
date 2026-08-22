class_name DecorationOccupancyMap
extends RefCounted

## Mapa unificado de ocupación espacial, despejes y superficies de decoración (sin alterar CellGrid).

var occupied_cells: Dictionary = {}   ## Vector2i -> Dictionary { "owner_id": StringName, "layer": int }
var clearance_cells: Dictionary = {}  ## Vector2i -> Array[StringName]
var surfaces: Dictionary = {}         ## Vector2i -> Dictionary { "surface_type": StringName, "height": float, "owner_id": StringName }

func add_footprint(cells: Array[Vector2i], owner_id: StringName, layer: int = 0) -> bool:
	for cell in cells:
		if occupied_cells.has(cell):
			return false

	for cell in cells:
		occupied_cells[cell] = {
			"owner_id": owner_id,
			"layer": layer
		}
	return true

func add_clearance(cells: Array[Vector2i], owner_id: StringName) -> void:
	for cell in cells:
		if not clearance_cells.has(cell):
			clearance_cells[cell] = []
		var arr: Array = clearance_cells[cell]
		if not arr.has(owner_id):
			arr.append(owner_id)

func is_cell_occupied(cell: Vector2i) -> bool:
	return occupied_cells.has(cell)

func has_clearance(cell: Vector2i) -> bool:
	return clearance_cells.has(cell)

func is_cell_available(cell: Vector2i, check_clearance: bool = false) -> bool:
	if occupied_cells.has(cell):
		return false
	if check_clearance and clearance_cells.has(cell):
		return false
	return true

func is_area_available(cells: Array[Vector2i], check_clearance: bool = false) -> bool:
	for cell in cells:
		if not is_cell_available(cell, check_clearance):
			return false
	return true

func register_surface(cell: Vector2i, surface_type: StringName, height: float, owner_id: StringName) -> void:
	surfaces[cell] = {
		"surface_type": surface_type,
		"height": height,
		"owner_id": owner_id
	}

func has_surface(cell: Vector2i) -> bool:
	return surfaces.has(cell)

func get_surface(cell: Vector2i) -> Dictionary:
	return surfaces.get(cell, {})
