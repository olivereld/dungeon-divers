class_name CandidateEdge
extends RefCounted

## Arista candidata normalizada para grafos topológicos de mazmorra.
## Garantiza que room_a_id < room_b_id para evitar duplicados invertidos.

var room_a_id: int
var room_b_id: int
var distance_squared: int
var weight: float
var is_mandatory: bool = false

func _init(p_u: int, p_v: int, p_dist_sq: int = 0, p_weight: float = 0.0, p_mandatory: bool = false) -> void:
	room_a_id = mini(p_u, p_v)
	room_b_id = maxi(p_u, p_v)
	distance_squared = p_dist_sq if p_dist_sq > 0 else int(p_weight * p_weight)
	weight = p_weight if p_weight > 0.0 else sqrt(float(distance_squared))
	is_mandatory = p_mandatory

func equals(other: CandidateEdge) -> bool:
	if other == null:
		return false
	return room_a_id == other.room_a_id and room_b_id == other.room_b_id

func get_key() -> String:
	return "%d-%d" % [room_a_id, room_b_id]
