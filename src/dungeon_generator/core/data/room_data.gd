class_name RoomData
extends RefCounted

## Descriptor de habitación individual en el layout espacial.

class RoomType:
	const START: StringName = &"start"
	const EXPLORE: StringName = &"explore"
	const COMBAT: StringName = &"combat"
	const BOSS: StringName = &"boss"
	const TREASURE: StringName = &"treasure"
	const PUZZLE: StringName = &"puzzle"
	const GOAL: StringName = &"goal"

var id: int = 0
var rect: Rect2i = Rect2i()
var room_type: StringName = &"explore"   # &"start", &"explore", &"combat", &"boss", &"treasure", &"puzzle", &"goal"
var mission_node_id: int = -1
var is_required: bool = true
var is_placed: bool = false
var region: StringName = &""
var depth_in_graph: int = 0
var custom_data: Dictionary = {}

func _init(p_id: int = 0, p_rect: Rect2i = Rect2i(), p_type: StringName = &"explore") -> void:
	id = p_id
	rect = p_rect
	room_type = p_type

func get_center() -> Vector2i:
	return rect.position + rect.size / 2

func get_center_cell() -> Vector2i:
	return get_center()

func get_inner_rect() -> Rect2i:
	if rect.size.x <= 2 or rect.size.y <= 2:
		return rect
	return Rect2i(rect.position.x + 1, rect.position.y + 1, rect.size.x - 2, rect.size.y - 2)

func get_walkable_point(grid: CellGrid) -> Vector2i:
	var center := get_center()
	if grid.is_walkable(center):
		return center
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := Vector2i(x, y)
			if grid.is_walkable(p):
				return p
	return center

func get_area() -> int:
	return rect.size.x * rect.size.y

func overlaps(other: RoomData) -> bool:
	return rect.intersects(other.rect)

func expanded(margin: int) -> Rect2i:
	return Rect2i(
		rect.position.x - margin,
		rect.position.y - margin,
		rect.size.x + margin * 2,
		rect.size.y + margin * 2
	)

func contains_point(point: Vector2i) -> bool:
	return rect.has_point(point)

## Obtiene el punto en el umbral del muro exterior más cercano a un objetivo exterior.
## Se coloca a 1 celda fuera del rectángulo interior (en la capa de muros) evitando esquinas.
func get_nearest_edge_point(target: Vector2i) -> Vector2i:
	var center := get_center()
	var diff := target - center

	var min_y: int = rect.position.y + 1 if rect.size.y > 3 else center.y
	var max_y: int = rect.end.y - 2 if rect.size.y > 3 else center.y
	var min_x: int = rect.position.x + 1 if rect.size.x > 3 else center.x
	var max_x: int = rect.end.x - 2 if rect.size.x > 3 else center.x

	var edge_x: int = clampi(target.x, min_x, max_x)
	var edge_y: int = clampi(target.y, min_y, max_y)

	# Proyectar hacia el muro exterior exacto en la dirección del objetivo
	if absi(diff.x) * rect.size.y > absi(diff.y) * rect.size.x:
		# Salida Este (+X) u Oeste (-X)
		edge_x = rect.end.x if diff.x > 0 else rect.position.x - 1
	else:
		# Salida Sur (+Y) o Norte (-Y)
		edge_y = rect.end.y if diff.y > 0 else rect.position.y - 1

	return Vector2i(edge_x, edge_y)

func duplicate_room() -> RoomData:
	var copy := RoomData.new(id, rect, room_type)
	copy.mission_node_id = mission_node_id
	copy.is_required = is_required
	copy.is_placed = is_placed
	copy.region = region
	copy.depth_in_graph = depth_in_graph
	copy.custom_data = custom_data.duplicate(true)
	return copy
