class_name EntrancePair
extends RefCounted

## Contrato de datos lógico: Relaciona un par de entradas que resuelven una RoomConnection.
## Invariante: entrance_a pertenece a room_a_id y entrance_b pertenece a room_b_id.

var connection_id: int = -1
var entrance_a: RoomEntrance = null
var entrance_b: RoomEntrance = null
var score: float = 0.0

func _init(
	p_conn_id: int = -1,
	p_a: RoomEntrance = null,
	p_b: RoomEntrance = null,
	p_score: float = 0.0
) -> void:
	connection_id = p_conn_id
	entrance_a = p_a
	entrance_b = p_b
	score = p_score

func is_valid() -> bool:
	return entrance_a != null and entrance_b != null and entrance_a.room_id != entrance_b.room_id

func to_debug_string() -> String:
	var s_a := entrance_a.to_debug_string() if entrance_a != null else "null"
	var s_b := entrance_b.to_debug_string() if entrance_b != null else "null"
	return "EntrancePair(Conn: %d, Score: %.2f, A: %s, B: %s)" % [
		connection_id, score, s_a, s_b
	]
