class_name RoomTemplateGeometryPolicy
extends RefCounted

## Política de restricciones geométricas para RoomTemplates.
## Controla formas permitidas, dimensiones (ancho y profundidad), áreas mínimas/máximas
## y límites de aspecto (aspect ratio) para evitar habitaciones degeneradas.

var allowed_shapes: Array[StringName] = [&"rectangle"]
var min_width: int = 5
var max_width: int = 15
var min_depth: int = 5
var max_depth: int = 15
var min_area: int = 25
var max_area: int = 225
var min_aspect_ratio: float = 0.5
var max_aspect_ratio: float = 2.0

func _init(
	p_allowed_shapes: Array[StringName] = [&"rectangle"],
	p_min_width: int = 5,
	p_max_width: int = 15,
	p_min_depth: int = 5,
	p_max_depth: int = 15,
	p_min_area: int = 25,
	p_max_area: int = 225,
	p_min_aspect_ratio: float = 0.5,
	p_max_aspect_ratio: float = 2.0
) -> void:
	if not p_allowed_shapes.is_empty():
		allowed_shapes = p_allowed_shapes
	min_width = p_min_width
	max_width = p_max_width
	min_depth = p_min_depth
	max_depth = p_max_depth
	min_area = p_min_area
	max_area = p_max_area
	min_aspect_ratio = p_min_aspect_ratio
	max_aspect_ratio = p_max_aspect_ratio

func allows_shape(shape: StringName) -> bool:
	return allowed_shapes.has(shape)
