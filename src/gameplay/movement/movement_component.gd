class_name MovementComponent
extends Node

## Máquina de estados discreta de movimiento por celdas (Cell-Based Movement).
## Autoridad lógica estricta: current_cell -> target_cell.
## La posición 3D únicamente presenta e interpola la transición física.

signal movement_started(from_cell: Vector2i, to_cell: Vector2i)
signal movement_finished(from_cell: Vector2i, to_cell: Vector2i)
signal movement_failed(request: MovementRequest, result: MovementResult)
signal cell_changed(new_cell: Vector2i)
signal facing_changed(new_facing: Vector2i)
signal state_changed(is_moving: bool)

const _RequestScript = preload("res://src/gameplay/movement/movement_request.gd")
const _ResultScript = preload("res://src/gameplay/movement/movement_result.gd")
const _ProfileScript = preload("res://src/gameplay/movement/movement_profile.gd")
const _GridScript = preload("res://src/gameplay/movement/movement_grid.gd")
const _RulesScript = preload("res://src/gameplay/movement/movement_rules.gd")
const _OccupancyScript = preload("res://src/gameplay/movement/movement_occupancy.gd")

@export var profile: MovementProfile = null

## Referencias compartidas del sistema de movimiento
var grid: MovementGrid = null
var occupancy: MovementOccupancy = null
var rules: MovementRules = null
var target_actor: Node3D = null

# --- Estado Lógico de Movimiento ---
var current_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
var is_moving: bool = false
var progress: float = 0.0
var facing: Vector2i = Vector2i(0, 1) # Default: Sur (+Z)

## Buffer de una sola solicitud siguiente
var buffered_request: MovementRequest = null

## Desplazamiento Y para alinear visualmente los pies del modelo en la cota del terreno
var y_offset: float = 0.0

func _init() -> void:
	if profile == null:
		profile = _ProfileScript.new()
	if rules == null:
		rules = _RulesScript.new()

func _ready() -> void:
	if target_actor == null and get_parent() is Node3D:
		target_actor = get_parent() as Node3D
	if profile == null:
		profile = _ProfileScript.new()
	if rules == null:
		rules = _RulesScript.new()

func _exit_tree() -> void:
	if occupancy != null and target_actor != null:
		occupancy.unregister_entity(target_actor)

## Configura el componente conectándolo con el grid y sistemas de movimiento.
func setup(
	p_grid: MovementGrid,
	p_occupancy: MovementOccupancy = null,
	p_rules: MovementRules = null,
	p_initial_cell: Vector2i = Vector2i.ZERO,
	p_y_offset: float = 0.0
) -> void:
	grid = p_grid
	occupancy = p_occupancy
	rules = p_rules if p_rules != null else _RulesScript.new()
	y_offset = p_y_offset
	current_cell = p_initial_cell
	target_cell = p_initial_cell
	is_moving = false
	progress = 0.0
	buffered_request = null

	if occupancy != null and target_actor != null:
		occupancy.occupy(current_cell, target_actor)

	_teleport_actor_to_cell(current_cell)

## Teletransporta la entidad a una celda específica sin interpolación.
func teleport_to_cell(cell: Vector2i) -> void:
	if is_moving and occupancy != null and target_actor != null:
		occupancy.cancel_reservation(target_cell, target_actor)

	if occupancy != null and target_actor != null:
		occupancy.release(current_cell, target_actor)
		occupancy.occupy(cell, target_actor)

	current_cell = cell
	target_cell = cell
	is_moving = false
	progress = 0.0
	buffered_request = null

	_teleport_actor_to_cell(cell)
	cell_changed.emit(current_cell)
	state_changed.emit(false)

## Solicita un movimiento. Si ya se está moviendo, almacena en buffer el último input.
func request_movement(request: MovementRequest) -> MovementResult:
	if request == null or not request.is_valid():
		return null

	if is_moving:
		# Input buffering: almacena únicamente la última dirección solicitada
		buffered_request = request
		return _ResultScript.reject(_ResultScript.REASON_ALREADY_MOVING, current_cell, target_cell)

	buffered_request = null
	return _attempt_transition(request)

func _attempt_transition(request: MovementRequest) -> MovementResult:
	var dir: Vector2i = request.direction

	# Actualizar orientación (facing)
	if dir != Vector2i.ZERO and dir != facing:
		facing = dir
		facing_changed.emit(facing)

	var next_cell: Vector2i = current_cell + dir
	var active_rules: MovementRules = rules if rules != null else _RulesScript.new()
	var active_profile: MovementProfile = profile if profile != null else _ProfileScript.new()

	# 1. Validar reglas de movimiento
	var res: MovementResult = active_rules.validate_transition(
		current_cell,
		next_cell,
		grid,
		active_profile,
		occupancy,
		target_actor
	)

	if not res.accepted:
		movement_failed.emit(request, res)
		return res

	# 2. Reservar atómicamente la celda de destino
	if occupancy != null and target_actor != null:
		if not occupancy.reserve(next_cell, target_actor):
			var occ_res = _ResultScript.reject(_ResultScript.REASON_OCCUPIED, current_cell, next_cell)
			movement_failed.emit(request, occ_res)
			return occ_res

	# 3. Transición aceptada
	target_cell = next_cell
	is_moving = true
	progress = 0.0

	movement_started.emit(current_cell, target_cell)
	state_changed.emit(true)
	return res

func _physics_process(delta: float) -> void:
	process_movement(delta)

## Actualiza el avance de la transición o consume el buffer si está inactivo.
func process_movement(delta: float) -> void:
	if not is_moving:
		if buffered_request != null:
			var req: MovementRequest = buffered_request
			buffered_request = null
			_attempt_transition(req)
		_turn_actor_towards_facing(delta)
		return

	var cps: float = profile.cells_per_second if profile != null else 4.0
	progress += cps * delta

	if progress >= 1.0:
		progress = 1.0
		_update_presentation(progress, delta)
		_complete_movement()
	else:
		_update_presentation(progress, delta)

func _complete_movement() -> void:
	if occupancy != null and target_actor != null:
		occupancy.occupy(target_cell, target_actor)
		occupancy.release(current_cell, target_actor)

	var from_c: Vector2i = current_cell
	current_cell = target_cell
	is_moving = false
	progress = 0.0

	cell_changed.emit(current_cell)
	movement_finished.emit(from_c, target_cell)
	state_changed.emit(false)

	# Encadenamiento continuo de movimientos al sostener input
	if buffered_request != null:
		var next_req: MovementRequest = buffered_request
		buffered_request = null
		_attempt_transition(next_req)

func _update_presentation(p: float, delta: float) -> void:
	if target_actor == null or grid == null:
		return

	var world_from: Vector3 = grid.cell_to_world(current_cell, y_offset)
	var world_to: Vector3 = grid.cell_to_world(target_cell, y_offset)
	var target_pos := world_from.lerp(world_to, p)
	if target_actor.is_inside_tree():
		target_actor.global_position = target_pos
	else:
		target_actor.position = target_pos

	_turn_actor_towards_facing(delta)

func _turn_actor_towards_facing(delta: float) -> void:
	if target_actor == null:
		return
	var dir_3d := Vector3(float(facing.x), 0.0, float(facing.y)).normalized()
	if dir_3d != Vector3.ZERO:
		var target_angle: float = atan2(-dir_3d.x, -dir_3d.z)
		var turn_speed: float = profile.turn_speed if profile != null else 14.0
		if delta > 0.0 and turn_speed > 0.0:
			target_actor.rotation.y = lerp_angle(target_actor.rotation.y, target_angle, clampf(turn_speed * delta, 0.0, 1.0))
		else:
			target_actor.rotation.y = target_angle

func _teleport_actor_to_cell(cell: Vector2i) -> void:
	if target_actor != null and grid != null:
		var target_pos := grid.cell_to_world(cell, y_offset)
		if target_actor.is_inside_tree():
			target_actor.global_position = target_pos
		else:
			target_actor.position = target_pos
		_turn_actor_towards_facing(0.0)
