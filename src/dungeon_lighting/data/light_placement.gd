class_name LightPlacement
extends RefCounted

## DTO que describe la colocación de un punto de luz en la mazmorra (Fase Iluminación).
## Almacena las coordenadas en rejilla, la pared de anclaje, el ID de sala/pasillo y tipo.

enum WallSide {
	NORTH = 0,
	SOUTH = 1,
	EAST = 2,
	WEST = 3
}

var light_id: int = 0
var cell: Vector2i = Vector2i.ZERO
var wall_side: WallSide = WallSide.NORTH
var room_id: int = -1
var corridor_id: String = ""
var kind: StringName = &"torch"
var priority: float = 1.0
var world_offset: Vector3 = Vector3.ZERO

func _to_string() -> String:
	return "LightPlacement(id=%d, cell=%s, side=%d, room=%d, corr='%s', kind='%s')" % [
		light_id, cell, wall_side, room_id, corridor_id, kind
	]
