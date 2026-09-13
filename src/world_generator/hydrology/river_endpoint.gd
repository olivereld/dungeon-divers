class_name RiverEndpoint
extends RefCounted

enum DestinationType {
	UNKNOWN,
	OUT_OF_WORLD,
	JOIN_RIVER,
	LAKE,
	TERMINATE
}

var river_id: int = -1
var position: Vector2i = Vector2i(-1, -1)
var elevation: float = 0.0
var accumulation: float = 1.0
var destination_type: DestinationType = DestinationType.UNKNOWN
var target_river_id: int = -1
var target_lake_id: int = -1

func _init(p_river_id: int = -1, p_pos: Vector2i = Vector2i(-1, -1), p_elev: float = 0.0, p_accum: float = 1.0) -> void:
	river_id = p_river_id
	position = p_pos
	elevation = p_elev
	accumulation = p_accum

func to_dict() -> Dictionary:
	return {
		"river_id": river_id,
		"position": position,
		"elevation": elevation,
		"accumulation": accumulation,
		"destination_type": destination_type,
		"target_river_id": target_river_id,
		"target_lake_id": target_lake_id
	}
