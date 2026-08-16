class_name BSPPartitioner
extends RefCounted

## Partición Binaria del Espacio (BSP) para generación de mazmorras estructuradas/cuadriculadas.

var min_room_size: Vector2i = Vector2i(6, 6)
var max_room_size: Vector2i = Vector2i(14, 14)
var min_split_ratio: float = 0.4
var max_split_ratio: float = 0.6
var max_depth: int = 4

func partition(grid: CellGrid, area: Rect2i, rng: RandomNumberGenerator) -> Array[RoomData]:
	var rooms: Array[RoomData] = []
	var leaves: Array[Rect2i] = _split_recursive(area, 0, rng)

	for i in range(leaves.size()):
		var leaf: Rect2i = leaves[i]
		# Reducir tamaño de la habitación dentro de la hoja del BSP
		var max_w: int = mini(leaf.size.x - 2, max_room_size.x)
		var max_h: int = mini(leaf.size.y - 2, max_room_size.y)
		var min_w: int = mini(min_room_size.x, max_w)
		var min_h: int = mini(min_room_size.y, max_h)

		if max_w < min_w or max_h < min_h:
			continue

		var room_w: int = rng.randi_range(min_w, max_w)
		var room_h: int = rng.randi_range(min_h, max_h)
		var room_x: int = leaf.position.x + rng.randi_range(1, leaf.size.x - room_w - 1)
		var room_y: int = leaf.position.y + rng.randi_range(1, leaf.size.y - room_h - 1)

		var room_rect := Rect2i(room_x, room_y, room_w, room_h)
		var room := RoomData.new(rooms.size(), room_rect, &"explore")

		# Rellenar con suelo el grid
		grid.fill_rect(room_rect, CellGrid.CellType.FLOOR)
		rooms.append(room)

	return rooms

func _split_recursive(area: Rect2i, depth: int, rng: RandomNumberGenerator) -> Array[Rect2i]:
	var result: Array[Rect2i] = []

	if depth >= max_depth or (area.size.x < min_room_size.x * 2 + 4 and area.size.y < min_room_size.y * 2 + 4):
		result.append(area)
		return result

	# Decidir dirección de corte (horizontal o vertical)
	var split_horizontally := rng.randf() > 0.5
	if area.size.x > area.size.y * 1.25:
		split_horizontally = false
	elif area.size.y > area.size.x * 1.25:
		split_horizontally = true

	var split_ratio := rng.randf_range(min_split_ratio, max_split_ratio)

	if split_horizontally:
		var split_y: int = int(area.size.y * split_ratio)
		if split_y < min_room_size.y + 2 or (area.size.y - split_y) < min_room_size.y + 2:
			result.append(area)
			return result

		var top := Rect2i(area.position.x, area.position.y, area.size.x, split_y)
		var bottom := Rect2i(area.position.x, area.position.y + split_y, area.size.x, area.size.y - split_y)

		result.append_array(_split_recursive(top, depth + 1, rng))
		result.append_array(_split_recursive(bottom, depth + 1, rng))
	else:
		var split_x: int = int(area.size.x * split_ratio)
		if split_x < min_room_size.x + 2 or (area.size.x - split_x) < min_room_size.x + 2:
			result.append(area)
			return result

		var left := Rect2i(area.position.x, area.position.y, split_x, area.size.y)
		var right := Rect2i(area.position.x + split_x, area.position.y, area.size.x - split_x, area.size.y)

		result.append_array(_split_recursive(left, depth + 1, rng))
		result.append_array(_split_recursive(right, depth + 1, rng))

	return result
