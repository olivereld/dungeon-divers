class_name WallSection
extends RefCounted

## Unidad arquitectónica discreta de muro entre puntos significativos (esquinas, puertas, límites).

const INVALID_NEIGHBOR := Vector2i(999999, 999999)

var id: int = 0
var component_id: int = 0
var room_id: int = -1
var start_point: Vector2i = Vector2i.ZERO
var end_point: Vector2i = Vector2i.ZERO
var points: Array[Vector2i] = []
var orientation: Vector2i = Vector2i.ZERO
var length: float = 0.0
var variant_id: StringName = &"normal"
var is_closed_loop: bool = false
var bounds: Rect2i = Rect2i()

# Metadatos para uniones suaves continuas en esquinas
var start_miter_neighbor: Vector2i = INVALID_NEIGHBOR
var end_miter_neighbor: Vector2i = INVALID_NEIGHBOR
var has_start_cap: bool = false
var has_end_cap: bool = false

# Representación topológica de continuidad de esquinas compartidas
var start_corner_id: int = -1
var end_corner_id: int = -1
var corner_ids: Array[int] = []
var start_corner_desc: Dictionary = {}
var end_corner_desc: Dictionary = {}

func set_start_corner(c_id: int, prev_pt: Vector2i = INVALID_NEIGHBOR, is_corner: bool = true) -> void:
	start_corner_id = c_id
	if prev_pt != INVALID_NEIGHBOR:
		start_miter_neighbor = prev_pt
	start_corner_desc = {
		"id": c_id,
		"point": start_point,
		"prev_point": start_miter_neighbor,
		"is_corner": is_corner
	}

func set_end_corner(c_id: int, next_pt: Vector2i = INVALID_NEIGHBOR, is_corner: bool = true) -> void:
	end_corner_id = c_id
	if next_pt != INVALID_NEIGHBOR:
		end_miter_neighbor = next_pt
	end_corner_desc = {
		"id": c_id,
		"point": end_point,
		"next_point": end_miter_neighbor,
		"is_corner": is_corner
	}

func _init(
	p_id: int = 0,
	p_comp_id: int = 0,
	p_pts: Array[Vector2i] = [],
	p_room_id: int = -1,
	p_variant: StringName = &"normal",
	p_is_loop: bool = false
) -> void:
	id = p_id
	component_id = p_comp_id
	points = p_pts
	room_id = p_room_id
	variant_id = p_variant
	is_closed_loop = p_is_loop
	if not points.is_empty():
		start_point = points[0]
		end_point = points[points.size() - 1]
		_calculate_bounds_and_metrics()

func _calculate_bounds_and_metrics() -> void:
	if points.is_empty():
		return
	bounds = Rect2i(points[0], Vector2i.ONE)
	var total_len: float = 0.0
	for i in range(points.size()):
		bounds = bounds.expand(points[i])
		if i > 0:
			total_len += float(points[i - 1].distance_to(points[i]))
	length = total_len
	if points.size() >= 2:
		var diff = points[points.size() - 1] - points[0]
		orientation = Vector2i(signi(diff.x), signi(diff.y))
