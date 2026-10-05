class_name WorldNavigationChunk
extends RefCounted

## Representación inmutable y empaquetada de los datos de navegación para el core_bounds de un chunk.

const _NavCellScript = preload("res://src/world_generator/navigation/world_navigation_cell.gd")

var chunk_coord: Vector2i = Vector2i.ZERO
var core_bounds: Rect2i = Rect2i()
var width: int = 0
var height: int = 0

var walkable: PackedByteArray = PackedByteArray()
var elevation_level: PackedInt32Array = PackedInt32Array()
var height_data: PackedFloat32Array = PackedFloat32Array()

func _init(p_coord: Vector2i = Vector2i.ZERO, p_bounds: Rect2i = Rect2i()) -> void:
	chunk_coord = p_coord
	core_bounds = p_bounds
	width = p_bounds.size.x
	height = p_bounds.size.y

static func from_cells(p_coord: Vector2i, p_bounds: Rect2i, cells_dict: Dictionary) -> WorldNavigationChunk:
	var chunk := WorldNavigationChunk.new(p_coord, p_bounds)
	var total_cells := chunk.width * chunk.height
	if total_cells <= 0:
		return chunk

	var w_arr := PackedByteArray()
	w_arr.resize(total_cells)
	var e_arr := PackedInt32Array()
	e_arr.resize(total_cells)
	var h_arr := PackedFloat32Array()
	h_arr.resize(total_cells)

	var origin_x := p_bounds.position.x
	var origin_y := p_bounds.position.y
	var w := chunk.width

	for ly in range(chunk.height):
		for lx in range(chunk.width):
			var global_pos := Vector2i(origin_x + lx, origin_y + ly)
			var idx := lx + ly * w
			var cell = cells_dict.get(global_pos, null)
			if cell != null:
				w_arr[idx] = 1 if cell.is_walkable else 0
				e_arr[idx] = cell.elevation_level
				h_arr[idx] = cell.height
			else:
				w_arr[idx] = 0
				e_arr[idx] = 0
				h_arr[idx] = 0.0

	chunk.walkable = w_arr
	chunk.elevation_level = e_arr
	chunk.height_data = h_arr
	return chunk

func has_cell(global_cell: Vector2i) -> bool:
	return core_bounds.has_point(global_cell)

func _get_local_index(global_cell: Vector2i) -> int:
	if not core_bounds.has_point(global_cell):
		return -1
	var lx := global_cell.x - core_bounds.position.x
	var ly := global_cell.y - core_bounds.position.y
	return lx + ly * width

func is_walkable(global_cell: Vector2i) -> bool:
	var idx := _get_local_index(global_cell)
	if idx < 0 or idx >= walkable.size():
		return false
	return walkable[idx] == 1

func get_height(global_cell: Vector2i) -> float:
	var idx := _get_local_index(global_cell)
	if idx < 0 or idx >= height_data.size():
		return 0.0
	return height_data[idx]

func get_elevation_level(global_cell: Vector2i) -> int:
	var idx := _get_local_index(global_cell)
	if idx < 0 or idx >= elevation_level.size():
		return 0
	return elevation_level[idx]

func get_cell(global_cell: Vector2i) -> WorldNavigationCell:
	var idx := _get_local_index(global_cell)
	if idx < 0 or idx >= walkable.size():
		return null
	return _NavCellScript.new(
		global_cell,
		height_data[idx],
		elevation_level[idx],
		walkable[idx] == 1
	)
