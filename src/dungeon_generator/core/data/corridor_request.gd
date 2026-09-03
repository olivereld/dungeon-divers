class_name CorridorRequest
extends RefCounted

## Contrato de datos lógico: Petición atómica de tallado de corredor para una conexión entre dos salas.
## Enriquecido en Fase 5 (Corridor Planning) para transportar la intención espacial de corredor
## derivada del MissionGraph y SpatialIntent hacia el AStarCarver.

const ROLE_MAIN_PATH: StringName = &"main_path"
const ROLE_SIDE_PATH: StringName = &"side_path"
const ROLE_OPTIONAL: StringName = &"optional"
const ROLE_SHORTCUT: StringName = &"shortcut"

const ROUTING_DIRECT: StringName = &"direct"
const ROUTING_AVOID_ROOMS: StringName = &"avoid_rooms"
const ROUTING_MANHATTAN: StringName = &"manhattan"

# Identificación de conexión y salas
var connection_id: int = -1
var room_a_id: int = -1
var room_b_id: int = -1

# Coordenadas de entradas y salidas
var start: Vector2i = Vector2i.ZERO # outer_cell de Entrance A
var goal: Vector2i = Vector2i.ZERO  # outer_cell de Entrance B
var start_boundary: Vector2i = Vector2i.ZERO # boundary_cell de Entrance A
var goal_boundary: Vector2i = Vector2i.ZERO  # boundary_cell de Entrance B
var start_direction: Vector2i = Vector2i.ZERO # outward vector de Entrance A
var goal_direction: Vector2i = Vector2i.ZERO  # outward vector de Entrance B

# Requisitos de conectividad
var is_required: bool = true

# Intención semántica y espacial (Fase 5: Corridor Planning)
var mission_edge: Vector2i = Vector2i(-1, -1) # (from_node_id, to_node_id)
var corridor_role: StringName = ROLE_MAIN_PATH
var preferred_length: float = 0.0
var min_length: int = 1
var max_length: int = 64
var routing_preference: StringName = ROUTING_DIRECT

# Aliases de compatibilidad
var from_room: int:
	get:
		return room_a_id
	set(val):
		room_a_id = val

var to_room: int:
	get:
		return room_b_id
	set(val):
		room_b_id = val

var preferred_entrance: Vector2i:
	get:
		return start
	set(val):
		start = val

var preferred_exit: Vector2i:
	get:
		return goal
	set(val):
		goal = val

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
	p_required: bool = true,
	p_role: StringName = ROLE_MAIN_PATH,
	p_mission_edge: Vector2i = Vector2i(-1, -1)
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
	corridor_role = p_role
	mission_edge = p_mission_edge
	preferred_length = float(start.distance_to(goal))

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

func to_debug_string() -> String:
	return "[CorridorRequest conn=%d (%d <-> %d) role=%s edge=%s len=%.1f pref=%s req=%s]" % [
		connection_id, room_a_id, room_b_id, corridor_role, str(mission_edge), preferred_length, routing_preference, str(is_required)
	]
