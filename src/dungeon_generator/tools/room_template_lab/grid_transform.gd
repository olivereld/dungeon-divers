class_name GridTransform
extends RefCounted

## Capa matemática pura de transformación y proyecciones Rejilla ↔ Pantalla.
## Desacoplada de nodos de escena para permitir tests unitarios headless deterministas.

var cell_size: float = 32.0
var zoom: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO

func _init(p_cell_size: float = 32.0, p_zoom: float = 1.0, p_pan_offset: Vector2 = Vector2.ZERO) -> void:
	cell_size = p_cell_size
	zoom = p_zoom
	pan_offset = p_pan_offset

func get_effective_cell_size() -> float:
	return cell_size * zoom

func cell_to_screen(cell: Vector2i) -> Vector2:
	var eff := get_effective_cell_size()
	return pan_offset + Vector2(float(cell.x) * eff, float(cell.y) * eff)

func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var eff := get_effective_cell_size()
	var local: Vector2 = (screen_pos - pan_offset) / eff
	return Vector2i(int(floor(local.x)), int(floor(local.y)))

func get_cell_rect(cell: Vector2i) -> Rect2:
	var eff := get_effective_cell_size()
	return Rect2(cell_to_screen(cell), Vector2(eff, eff))

func visible_cell_range(viewport_size: Vector2) -> Rect2i:
	var top_left = screen_to_cell(Vector2.ZERO) - Vector2i(1, 1)
	var bottom_right = screen_to_cell(viewport_size) + Vector2i(1, 1)
	var w: int = (bottom_right.x - top_left.x) + 1
	var h: int = (bottom_right.y - top_left.y) + 1
	return Rect2i(top_left, Vector2i(w, h))

func center_on_bounds(bounds: Rect2i, viewport_size: Vector2, padding: float = 64.0) -> void:
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		pan_offset = viewport_size * 0.5
		zoom = 1.0
		return

	var available_w: float = maxf(100.0, viewport_size.x - padding * 2.0)
	var available_h: float = maxf(100.0, viewport_size.y - padding * 2.0)
	var bounds_w_px: float = float(bounds.size.x) * cell_size
	var bounds_h_px: float = float(bounds.size.y) * cell_size

	var zoom_x: float = available_w / bounds_w_px
	var zoom_y: float = available_h / bounds_h_px
	zoom = clampf(minf(zoom_x, zoom_y), 0.25, 4.0)

	var eff := get_effective_cell_size()
	var center_cell_pos := Vector2(float(bounds.position.x) + float(bounds.size.x) * 0.5, float(bounds.position.y) + float(bounds.size.y) * 0.5)
	pan_offset = (viewport_size * 0.5) - (center_cell_pos * eff)
