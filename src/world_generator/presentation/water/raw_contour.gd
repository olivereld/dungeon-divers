class_name RawContour
extends RefCounted

## Contorno geométrico cerrado extraído de WaterField mediante Marching Squares.
## Representa la línea perimetral exacta (shoreline, isolínea field = 0) de un cuerpo de agua.

var points: PackedVector2Array = PackedVector2Array()
var component_id: int = 0
var is_closed: bool = true
var is_hole: bool = false
var area: float = 0.0
var bounds: Rect2 = Rect2()

func _init(p_points: PackedVector2Array = PackedVector2Array(), p_component_id: int = 0) -> void:
	points = p_points
	component_id = p_component_id
	_compute_metrics()

func _compute_metrics() -> void:
	if points.size() < 3:
		area = 0.0
		bounds = Rect2()
		return

	# Comprobar cierre
	if points[0].distance_squared_to(points[-1]) < 0.0001:
		is_closed = true
	else:
		is_closed = false

	# Bounding box
	var min_pt := points[0]
	var max_pt := points[0]
	for p in points:
		min_pt.x = minf(min_pt.x, p.x)
		min_pt.y = minf(min_pt.y, p.y)
		max_pt.x = maxf(max_pt.x, p.x)
		max_pt.y = maxf(max_pt.y, p.y)
	bounds = Rect2(min_pt, max_pt - min_pt)

	# Área con signo (Fórmula Shoelace)
	var signed_area: float = 0.0
	var n: int = points.size()
	for i in range(n - 1):
		signed_area += points[i].x * points[i + 1].y - points[i + 1].x * points[i].y
	area = signed_area * 0.5
	is_hole = (area < 0.0)

## Retorna la longitud perimetral del contorno
func get_perimeter() -> float:
	var total: float = 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total

func to_dict() -> Dictionary:
	return {
		"component_id": component_id,
		"point_count": points.size(),
		"is_closed": is_closed,
		"is_hole": is_hole,
		"area": area,
		"bounds": bounds,
		"points": points
	}

func _to_string() -> String:
	return "RawContour(comp=%d, pts=%d, closed=%s, hole=%s, area=%.2f)" % [
		component_id, points.size(), str(is_closed), str(is_hole), area
	]
