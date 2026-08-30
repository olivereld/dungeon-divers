class_name DungeonLabGridTransform
extends RefCounted

var offset: Vector2 = Vector2.ZERO
var zoom: float = 1.0
var min_zoom: float = 0.1
var max_zoom: float = 10.0
var cell_size: float = 16.0

func screen_to_world(screen_pos: Vector2) -> Vector2:
	return (screen_pos - offset) / zoom

func world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos * zoom) + offset

func cell_to_screen_rect(cell_pos: Vector2i) -> Rect2:
	var top_left = world_to_screen(Vector2(cell_pos) * cell_size)
	var size = Vector2(cell_size, cell_size) * zoom
	return Rect2(top_left, size)

func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var world_pos = screen_to_world(screen_pos)
	return Vector2i(floor(world_pos.x / cell_size), floor(world_pos.y / cell_size))

func visible_world_rect(viewport_size: Vector2) -> Rect2:
	var top_left = screen_to_world(Vector2.ZERO)
	var bottom_right = screen_to_world(viewport_size)
	return Rect2(top_left, bottom_right - top_left)

func visible_cell_rect(viewport_size: Vector2) -> Rect2i:
	var w_rect = visible_world_rect(viewport_size)
	var min_c = Vector2i(floor(w_rect.position.x / cell_size), floor(w_rect.position.y / cell_size))
	var max_c = Vector2i(ceil(w_rect.end.x / cell_size), ceil(w_rect.end.y / cell_size))
	return Rect2i(min_c, max_c - min_c)

func pan(delta: Vector2) -> void:
	offset += delta

func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom = zoom
	var new_zoom = clampf(old_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(old_zoom, new_zoom):
		return

	# Mantener el punto de pantalla anclado en el mismo punto de mundo
	var world_anchor = (screen_pos - offset) / old_zoom
	zoom = new_zoom
	offset = screen_pos - (world_anchor * new_zoom)

func reset() -> void:
	offset = Vector2.ZERO
	zoom = 1.0
