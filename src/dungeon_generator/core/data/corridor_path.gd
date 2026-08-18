class_name CorridorPath
extends RefCounted

## Contrato de datos lógico: Representa el resultado del trazado de un corredor validado.

var connection_id: int = -1
var room_a_id: int = -1
var room_b_id: int = -1
var centerline_cells: Array[Vector2i] = []
var carved_cells: Array[Vector2i] = []
var cost: float = 0.0
var reused_cells_count: int = 0
var turn_count: int = 0
var straight_run_count: int = 0
var longest_straight_run: int = 0
var routing_strategy: String = "Unknown"

func _init(
	p_conn_id: int = -1,
	p_a_id: int = -1,
	p_b_id: int = -1,
	p_centerline: Array[Vector2i] = [],
	p_carved: Array[Vector2i] = [],
	p_cost: float = 0.0,
	p_reused: int = 0,
	p_turns: int = 0,
	p_longest_run: int = 0,
	p_strategy: String = "Unknown"
) -> void:
	connection_id = p_conn_id
	room_a_id = p_a_id
	room_b_id = p_b_id
	centerline_cells = p_centerline
	carved_cells = p_carved
	cost = p_cost
	reused_cells_count = p_reused
	turn_count = p_turns
	longest_straight_run = p_longest_run
	routing_strategy = p_strategy

func to_debug_string() -> String:
	return "CorridorPath(Conn: %d, Rooms: %d<->%d, Centerline: %d, Carved: %d, Reused: %d, Turns: %d, Strat: %s, Cost: %.2f)" % [
		connection_id, room_a_id, room_b_id, centerline_cells.size(), carved_cells.size(), reused_cells_count, turn_count, routing_strategy, cost
	]

