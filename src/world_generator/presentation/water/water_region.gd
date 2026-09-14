class_name WaterRegion
extends RefCounted

## Representa un sistema hidrológico conectado continuo (ríos de entrada, lago, deltas y emisario).
## Actúa como la unidad atómica de mallado para WaterMeshBuilder, garantizando una superficie
## sin fracturas, solapamientos ni duplicación de vértices.

const _WaterCellScript = preload("res://src/world_generator/presentation/water/water_cell.gd")

var id: int = -1
var cells: Dictionary = {} # Vector2i -> WaterCell
var bounds_min: Vector2i = Vector2i(999999, 999999)
var bounds_max: Vector2i = Vector2i(-999999, -999999)

var river_ids: Array[int] = []
var lake_ids: Array[int] = []
var inlet_rivers: Array[int] = []
var outflow_rivers: Array[int] = []

var has_lakes: bool = false
var has_rivers: bool = false

func _init(p_id: int = -1) -> void:
	id = p_id

func add_cell(cell: RefCounted) -> void:
	if cell == null:
		return
	var pos: Vector2i = cell.position
	cells[pos] = cell
	cell.region_id = id

	bounds_min.x = mini(bounds_min.x, pos.x)
	bounds_min.y = mini(bounds_min.y, pos.y)
	bounds_max.x = maxi(bounds_max.x, pos.x)
	bounds_max.y = maxi(bounds_max.y, pos.y)

	if cell.is_river() or cell.is_transition() or cell.is_outlet():
		has_rivers = true
		if cell.river_id >= 0 and not river_ids.has(cell.river_id):
			river_ids.append(cell.river_id)

	if cell.is_lake() or cell.is_transition() or cell.is_outlet():
		has_lakes = true
		if cell.lake_id >= 0 and not lake_ids.has(cell.lake_id):
			lake_ids.append(cell.lake_id)

func get_cell(pos: Vector2i) -> RefCounted:
	return cells.get(pos, null)

func has_cell(pos: Vector2i) -> bool:
	return cells.has(pos)

func get_cells() -> Array:
	return cells.values()

func cell_count() -> int:
	return cells.size()

func get_bounding_box_world(cell_size: float = 1.0) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var origin := Vector2(float(bounds_min.x), float(bounds_min.y)) * cell_size
	var size := Vector2(float(bounds_max.x - bounds_min.x + 1), float(bounds_max.y - bounds_min.y + 1)) * cell_size
	return Rect2(origin, size)

func to_dict() -> Dictionary:
	return {
		"id": id,
		"cell_count": cells.size(),
		"bounds_min": bounds_min,
		"bounds_max": bounds_max,
		"river_ids": river_ids.duplicate(),
		"lake_ids": lake_ids.duplicate(),
		"inlet_rivers": inlet_rivers.duplicate(),
		"outflow_rivers": outflow_rivers.duplicate(),
		"has_lakes": has_lakes,
		"has_rivers": has_rivers
	}
