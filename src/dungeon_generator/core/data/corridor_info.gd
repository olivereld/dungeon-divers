class_name CorridorInfo
extends RefCounted

## Métricas estructurales y geométricas de un corredor analizado (Fase Reforced).

var connection_id: int = -1
var length: int = 0
var min_width: int = 1
var max_width: int = 1
var is_short: bool = false
var endpoints: Array[Vector2i] = []
var branch_count: int = 0
var candidate_door_cells: Array[Vector2i] = []

func to_debug_string() -> String:
	return "CorridorInfo(Conn: %d, Length: %d, Short: %s, Endpoints: %s)" % [
		connection_id, length, str(is_short), str(endpoints)
	]
