class_name RenderSegment
extends RefCounted

## Segmento lineal normalizado de canal fluvial para renderizado y presentación.
## Desacoplado de la topología compleja de red y sin dependencias de mallas o vértices.

var start_position: Vector3 = Vector3.ZERO
var end_position: Vector3 = Vector3.ZERO
var width_start: float = 0.0
var width_end: float = 0.0
var depth_start: float = 0.0
var depth_end: float = 0.0
var river_id: int = -1
var order: int = 1

func _init(
	p_start_position: Vector3 = Vector3.ZERO,
	p_end_position: Vector3 = Vector3.ZERO,
	p_width_start: float = 0.0,
	p_width_end: float = 0.0,
	p_depth_start: float = 0.0,
	p_depth_end: float = 0.0,
	p_river_id: int = -1,
	p_order: int = 1
) -> void:
	start_position = p_start_position
	end_position = p_end_position
	width_start = p_width_start
	width_end = p_width_end
	depth_start = p_depth_start
	depth_end = p_depth_end
	river_id = p_river_id
	order = p_order

## Retorna la longitud Euclidiana del segmento
func get_length() -> float:
	return start_position.distance_to(end_position)

## Retorna el vector director normalizado del segmento
func get_direction() -> Vector3:
	var delta: Vector3 = end_position - start_position
	var l: float = delta.length()
	return delta / l if l > 0.00001 else Vector3.ZERO

## Interpola la posición a lo largo del tramo (t en [0.0, 1.0])
func get_position_at(t: float) -> Vector3:
	return start_position.lerp(end_position, clampf(t, 0.0, 1.0))

## Interpola el ancho a lo largo del tramo (t en [0.0, 1.0])
func get_width_at(t: float) -> float:
	return lerpf(width_start, width_end, clampf(t, 0.0, 1.0))

## Interpola la profundidad a lo largo del tramo (t en [0.0, 1.0])
func get_depth_at(t: float) -> float:
	return lerpf(depth_start, depth_end, clampf(t, 0.0, 1.0))

func to_dict() -> Dictionary:
	return {
		"start_position": start_position,
		"end_position": end_position,
		"width_start": width_start,
		"width_end": width_end,
		"depth_start": depth_start,
		"depth_end": depth_end,
		"river_id": river_id,
		"order": order
	}

func _to_string() -> String:
	return "RenderSegment(id=%d, order=%d, len=%.2f, w=[%.2f->%.2f], d=[%.2f->%.2f])" % [
		river_id, order, get_length(), width_start, width_end, depth_start, depth_end
	]
