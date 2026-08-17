class_name CorridorRequest
extends RefCounted

## Contrato de datos lógico: Petición atómica de tallado de corredor para una conexión entre dos salas.

var connection_id: int = -1
var room_a_id: int = -1
var room_b_id: int = -1
var start: Vector2i = Vector2i.ZERO # outer_cell de Entrance A
var goal: Vector2i = Vector2i.ZERO  # outer_cell de Entrance B
var start_boundary: Vector2i = Vector2i.ZERO # boundary_cell de Entrance A
var goal_boundary: Vector2i = Vector2i.ZERO  # boundary_cell de Entrance B
var start_direction: Vector2i = Vector2i.ZERO # outward vector de Entrance A
var goal_direction: Vector2i = Vector2i.ZERO  # outward vector de Entrance B
var is_required: bool = true

func _init(
	p_conn_id: int = -1,
	p_a_id: int = -1,
	p_b_id: int = -1,
	p_start: Vector2i = Vector2i.ZERO,
	p_goal: Vector2i = Vector2i.ZERO,
	p_start_b: Vector2i = Vector2i.ZERO,
	p_goal_b: Vector2i = Vector2i.ZERO,
	p_start_dir: Vector2i = Vector2i.ZERO,
	p_goal_dir: Vector2i = Vector2i.ZERO,
	p_required: bool = true
) -> void:
	connection_id = p_conn_id
	room_a_id = p_a_id
	room_b_id = p_b_id
	start = p_start
	goal = p_goal
	start_boundary = p_start_b
	goal_boundary = p_goal_b
	start_direction = p_start_dir
	goal_direction = p_goal_dir
	is_required = p_required

static func from_entrance_pair(pair: EntrancePair, is_required_conn: bool = true) -> CorridorRequest:
	if pair == null or pair.entrance_a == null or pair.entrance_b == null:
		return null
	return CorridorRequest.new(
		pair.connection_id,
		pair.entrance_a.room_id,
		pair.entrance_b.room_id,
		pair.entrance_a.outer_cell,
		pair.entrance_b.outer_cell,
		pair.entrance_a.boundary_cell,
		pair.entrance_b.boundary_cell,
		pair.entrance_a.get_outward_direction(),
		pair.entrance_b.get_outward_direction(),
		is_required_conn
	)
