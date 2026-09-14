class_name WaterCell
extends RefCounted

## Unidad hidrológica elemental para el mallado topológico continuo de superficies de agua.
## Encapsula cotas, dirección de flujo, tipo de cuerpo de agua y adyacencias.

enum Type {
	RIVER,
	LAKE,
	TRANSITION,
	OUTLET
}

var position: Vector2i = Vector2i(-1, -1)
var water_height: float = 0.0
var bed_height: float = 0.0
var depth: float = 0.0
var flow_dir: Vector2 = Vector2.ZERO
var water_type: Type = Type.RIVER
var neighbors: Array[Vector2i] = []

var river_id: int = -1
var lake_id: int = -1
var region_id: int = -1
var shoreline_height: float = 0.0
var channel_width: float = 1.0
var flow_speed: float = 1.0

func _init(
	p_pos: Vector2i = Vector2i(-1, -1),
	p_water_h: float = 0.0,
	p_bed_h: float = 0.0,
	p_depth: float = 0.0,
	p_flow: Vector2 = Vector2.ZERO,
	p_type: Type = Type.RIVER
) -> void:
	position = p_pos
	water_height = p_water_h
	bed_height = p_bed_h
	depth = p_depth
	flow_dir = p_flow
	water_type = p_type

func is_river() -> bool:
	return water_type == Type.RIVER

func is_lake() -> bool:
	return water_type == Type.LAKE

func is_transition() -> bool:
	return water_type == Type.TRANSITION

func is_outlet() -> bool:
	return water_type == Type.OUTLET

func to_dict() -> Dictionary:
	return {
		"position": position,
		"water_height": water_height,
		"bed_height": bed_height,
		"depth": depth,
		"flow_dir": flow_dir,
		"water_type": water_type,
		"neighbors": neighbors.duplicate(),
		"river_id": river_id,
		"lake_id": lake_id,
		"region_id": region_id,
		"shoreline_height": shoreline_height,
		"channel_width": channel_width,
		"flow_speed": flow_speed
	}
