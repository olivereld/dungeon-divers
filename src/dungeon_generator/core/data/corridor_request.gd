class_name CorridorRequest
extends RefCounted

## Contrato de datos lógico: Petición atómica de tallado de corredor para una conexión entre dos salas.
## Enriquecido en Fase 5 (Corridor Planning) para transportar la intención espacial de corredor
## derivada del MissionGraph y SpatialIntent hacia el AStarCarver.
## Soporta sellado estricto (seal) para garantizar inmutabilidad post-planificación.

const ROLE_MAIN_PATH: StringName = &"main_path"
const ROLE_SIDE_PATH: StringName = &"side_path"
const ROLE_OPTIONAL: StringName = &"optional"
const ROLE_SHORTCUT: StringName = &"shortcut"

const ROUTING_DIRECT: StringName = &"direct"
const ROUTING_AVOID_ROOMS: StringName = &"avoid_rooms"
const ROUTING_MANHATTAN: StringName = &"manhattan"

var _is_sealed: bool = false

# Identificación de conexión y salas
var _connection_id: int = -1
var _room_a_id: int = -1
var _room_b_id: int = -1

# Coordenadas de entradas y salidas
var _start: Vector2i = Vector2i.ZERO # outer_cell de Entrance A
var _goal: Vector2i = Vector2i.ZERO  # outer_cell de Entrance B
var _start_boundary: Vector2i = Vector2i.ZERO # boundary_cell de Entrance A
var _goal_boundary: Vector2i = Vector2i.ZERO  # boundary_cell de Entrance B
var _start_direction: Vector2i = Vector2i.ZERO # outward vector de Entrance A
var _goal_direction: Vector2i = Vector2i.ZERO  # outward vector de Entrance B

# Requisitos de conectividad
var _is_required: bool = true

# Intención semántica y espacial
var _mission_edge: Vector2i = Vector2i(-1, -1) # (from_node_id, to_node_id)
var _corridor_role: StringName = ROLE_MAIN_PATH
var _preferred_length: float = 0.0
var _min_length: int = 1
var _max_length: int = 64
var _routing_preference: StringName = ROUTING_DIRECT

# Properties con control de inmutabilidad
var connection_id: int:
	get: return _connection_id
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _connection_id = val

var room_a_id: int:
	get: return _room_a_id
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _room_a_id = val

var room_b_id: int:
	get: return _room_b_id
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _room_b_id = val

var start: Vector2i:
	get: return _start
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _start = val

var goal: Vector2i:
	get: return _goal
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _goal = val

var start_boundary: Vector2i:
	get: return _start_boundary
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _start_boundary = val

var goal_boundary: Vector2i:
	get: return _goal_boundary
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _goal_boundary = val

var start_direction: Vector2i:
	get: return _start_direction
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _start_direction = val

var goal_direction: Vector2i:
	get: return _goal_direction
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _goal_direction = val

var is_required: bool:
	get: return _is_required
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _is_required = val

var mission_edge: Vector2i:
	get: return _mission_edge
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _mission_edge = val

var corridor_role: StringName:
	get: return _corridor_role
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _corridor_role = val

var preferred_length: float:
	get: return _preferred_length
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _preferred_length = val

var min_length: int:
	get: return _min_length
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _min_length = val

var max_length: int:
	get: return _max_length
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _max_length = val

var routing_preference: StringName:
	get: return _routing_preference
	set(val):
		assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
		if not _is_sealed: _routing_preference = val

# Aliases de compatibilidad
var from_room: int:
	get: return _room_a_id
	set(val): room_a_id = val

var to_room: int:
	get: return _room_b_id
	set(val): room_b_id = val

var preferred_entrance: Vector2i:
	get: return _start
	set(val): start = val

var preferred_exit: Vector2i:
	get: return _goal
	set(val): goal = val

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
	_connection_id = p_conn_id
	_room_a_id = p_a_id
	_room_b_id = p_b_id
	_start = p_start
	_goal = p_goal
	_start_boundary = p_start_b
	_goal_boundary = p_goal_b
	_start_direction = p_start_dir
	_goal_direction = p_goal_dir
	_is_required = p_required
	_corridor_role = p_role
	_mission_edge = p_mission_edge
	_preferred_length = float(p_start.distance_to(p_goal))

## Fábrica completa en un solo paso para peticiones planificadas
static func create_planned(
	p_conn_id: int,
	p_a_id: int,
	p_b_id: int,
	p_start: Vector2i,
	p_goal: Vector2i,
	p_start_b: Vector2i,
	p_goal_b: Vector2i,
	p_start_dir: Vector2i,
	p_goal_dir: Vector2i,
	p_required: bool,
	p_role: StringName,
	p_mission_edge: Vector2i,
	p_pref_len: float,
	p_min_len: int,
	p_max_len: int,
	p_routing_pref: StringName
) -> CorridorRequest:
	var req := CorridorRequest.new(
		p_conn_id, p_a_id, p_b_id, p_start, p_goal, p_start_b, p_goal_b,
		p_start_dir, p_goal_dir, p_required, p_role, p_mission_edge
	)
	req._preferred_length = p_pref_len
	req._min_length = p_min_len
	req._max_length = p_max_len
	req._routing_preference = p_routing_pref
	return req

## [DEPRECATED / NO PRODUCTIVO] Método legacy de compatibilidad para tests unitarios aislados.
## En el pipeline principal de producción, las peticiones deben crearse exclusivamente
## mediante CorridorPlanner y completarse con bind_physical_entrances().
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

func bind_physical_entrances(pair: EntrancePair) -> void:
	assert(not _is_sealed, "CorridorRequest is sealed and immutable.")
	if not _is_sealed and pair != null and pair.entrance_a != null and pair.entrance_b != null:
		_start = pair.entrance_a.outer_cell
		_goal = pair.entrance_b.outer_cell
		_start_boundary = pair.entrance_a.boundary_cell
		_goal_boundary = pair.entrance_b.boundary_cell
		_start_direction = pair.entrance_a.get_outward_direction()
		_goal_direction = pair.entrance_b.get_outward_direction()
		if _preferred_length <= 0.0:
			_preferred_length = float(_start.distance_to(_goal))

func seal() -> void:
	_is_sealed = true

func is_sealed() -> bool:
	return _is_sealed

func to_debug_string() -> String:
	return "[CorridorRequest conn=%d (%d <-> %d) role=%s edge=%s len=%.1f pref=%s req=%s sealed=%s]" % [
		_connection_id, _room_a_id, _room_b_id, _corridor_role, str(_mission_edge), _preferred_length, _routing_preference, str(_is_required), str(_is_sealed)
	]
