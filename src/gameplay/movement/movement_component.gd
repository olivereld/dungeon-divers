class_name MovementComponent
extends Node

## Máquina de estados discreta de movimiento por celdas (Cell-Based Movement).
## Autoridad lógica estricta: current_cell -> target_cell.
## La posición 3D únicamente presenta e interpola la transición física.

signal movement_started(from_cell: Vector2i, to_cell: Vector2i)
signal movement_finished(from_cell: Vector2i, to_cell: Vector2i)
signal movement_failed(request: MovementRequest, result: MovementResult)
signal drop_started(from_cell: Vector2i, to_cell: Vector2i)
signal drop_takeoff(from_cell: Vector2i, to_cell: Vector2i)
signal drop_finished(from_cell: Vector2i, to_cell: Vector2i)
signal jump_up_started(from_cell: Vector2i, to_cell: Vector2i)
signal jump_up_finished(from_cell: Vector2i, to_cell: Vector2i)
signal fall_started(from_cell: Vector2i, to_cell: Vector2i)
signal fall_finished(from_cell: Vector2i, to_cell: Vector2i)
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
var grid: Object = null
var occupancy: MovementOccupancy = null
var rules: MovementRules = null
var target_actor: Node3D = null

# --- Estado Lógico de Movimiento ---
var current_cell: Vector2i = Vector2i.ZERO
var target_cell: Vector2i = Vector2i.ZERO
var is_moving: bool = false
var progress: float = 0.0
var facing: Vector2i = Vector2i(0, 1) # Default: Sur (+Z)
var current_transition_type: int = _ResultScript.TransitionType.WALK
var _drop_windup_remaining: float = 0.0

## Buffer de una sola solicitud siguiente
var buffered_request: MovementRequest = null

## Solicitud pendiente en espera de que un chunk se vuelva READY (sin polling por frame)
var pending_unavailable_request: MovementRequest = null

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
	_disconnect_grid_signals()
	if occupancy != null and target_actor != null:
		occupancy.unregister_entity(target_actor)

## Configura el componente conectándolo con el grid y sistemas de movimiento.
func setup(
	p_grid: Object,
	p_occupancy: MovementOccupancy = null,
	p_rules: MovementRules = null,
	p_initial_cell: Vector2i = Vector2i.ZERO,
	p_y_offset: float = 0.0
) -> void:
	_disconnect_grid_signals()
	grid = p_grid
	_connect_grid_signals()

	occupancy = p_occupancy
	rules = p_rules if p_rules != null else _RulesScript.new()
	y_offset = p_y_offset
	current_cell = p_initial_cell
	target_cell = p_initial_cell
	is_moving = false
	progress = 0.0
	buffered_request = null
	pending_unavailable_request = null

	if occupancy != null and target_actor != null:
		occupancy.occupy(current_cell, target_actor)

	_teleport_actor_to_cell(current_cell)

func _connect_grid_signals() -> void:
	if grid != null and grid.has_signal("chunk_registered"):
		if not grid.chunk_registered.is_connected(_on_grid_chunk_registered):
			grid.chunk_registered.connect(_on_grid_chunk_registered)
	if grid != null and grid.has_signal("chunk_unregistered"):
		if not grid.chunk_unregistered.is_connected(_on_grid_chunk_unregistered):
			grid.chunk_unregistered.connect(_on_grid_chunk_unregistered)

func _disconnect_grid_signals() -> void:
	if grid != null and grid.has_signal("chunk_registered"):
		if grid.chunk_registered.is_connected(_on_grid_chunk_registered):
			grid.chunk_registered.disconnect(_on_grid_chunk_registered)
	if grid != null and grid.has_signal("chunk_unregistered"):
		if grid.chunk_unregistered.is_connected(_on_grid_chunk_unregistered):
			grid.chunk_unregistered.disconnect(_on_grid_chunk_unregistered)

func _on_grid_chunk_registered(_coord: Vector2i) -> void:
	if is_moving or pending_unavailable_request == null:
		return
	var target_candidate := current_cell + pending_unavailable_request.direction
	if grid.has_method("get_cell_availability"):
		if grid.get_cell_availability(target_candidate) == 0: # READY
			var req: MovementRequest = pending_unavailable_request
			pending_unavailable_request = null
			_attempt_transition(req)

func _on_grid_chunk_unregistered(_coord: Vector2i) -> void:
	if pending_unavailable_request != null:
		var target_candidate := current_cell + pending_unavailable_request.direction
		if grid.has_method("get_cell_availability"):
			if grid.get_cell_availability(target_candidate) != 0:
				pending_unavailable_request = null

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
	_drop_windup_remaining = 0.0
	buffered_request = null

	_teleport_actor_to_cell(cell)
	cell_changed.emit(current_cell)
	state_changed.emit(false)

## Limpia cualquier solicitud pendiente en buffer.
func clear_buffer() -> void:
	buffered_request = null

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
		target_actor,
		request.is_jump
	)

	if not res.accepted:
		if res.reason == _ResultScript.REASON_CHUNK_UNAVAILABLE:
			pending_unavailable_request = request
		else:
			pending_unavailable_request = null
		movement_failed.emit(request, res)
		return res

	pending_unavailable_request = null

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
	current_transition_type = res.transition_type

	if current_transition_type == _ResultScript.TransitionType.DROP:
		_drop_windup_remaining = profile.drop_windup_time if profile != null else 0.0
		drop_started.emit(current_cell, target_cell)
	elif current_transition_type == _ResultScript.TransitionType.JUMP_UP:
		jump_up_started.emit(current_cell, target_cell)
	elif current_transition_type == _ResultScript.TransitionType.FALL:
		fall_started.emit(current_cell, target_cell)
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

	if current_transition_type == _ResultScript.TransitionType.DROP and _drop_windup_remaining > 0.0:
		_drop_windup_remaining -= delta
		_turn_actor_towards_facing(delta)
		if _drop_windup_remaining <= 0.0:
			_drop_windup_remaining = 0.0
			drop_takeoff.emit(current_cell, target_cell)
		else:
			_update_presentation(0.0, delta)
			return

	var cps: float = profile.cells_per_second if profile != null else 4.0
	if current_transition_type == _ResultScript.TransitionType.DROP:
		if profile != null and profile.drop_flight_time > 0.0:
			var drop_levels: int = 1
			if grid != null and grid.has_method("get_cell_elevation"):
				drop_levels = maxi(1, int(abs(grid.get_cell_elevation(current_cell) - grid.get_cell_elevation(target_cell))))
			var total_flight: float = profile.drop_flight_time + float(drop_levels - 1) * 0.06
			progress += delta / maxf(total_flight, 0.05)
		else:
			var mult: float = profile.drop_speed_multiplier if profile != null else 1.2
			cps *= mult
			progress += cps * delta
	elif current_transition_type == _ResultScript.TransitionType.JUMP_UP:
		var mult: float = profile.jump_up_speed_multiplier if profile != null else 1.0
		cps *= mult
		progress += cps * delta
	elif current_transition_type == _ResultScript.TransitionType.FALL:
		var mult: float = profile.fall_speed_multiplier if profile != null else 1.4
		cps *= mult
		progress += cps * delta
	else:
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
	var finished_type: int = current_transition_type
	current_cell = target_cell
	is_moving = false
	progress = 0.0
	_drop_windup_remaining = 0.0
	current_transition_type = _ResultScript.TransitionType.WALK

	cell_changed.emit(current_cell)
	if finished_type == _ResultScript.TransitionType.DROP:
		drop_finished.emit(from_c, target_cell)
	elif finished_type == _ResultScript.TransitionType.JUMP_UP:
		jump_up_finished.emit(from_c, target_cell)
	elif finished_type == _ResultScript.TransitionType.FALL:
		fall_finished.emit(from_c, target_cell)
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

	var target_pos: Vector3
	if current_transition_type == _ResultScript.TransitionType.DROP:
		# Trayectoria parabólica en arco hacia superficie inferior
		# Impulso inicial manteniéndose en cota alta y aceleración por gravedad al descender
		var t: float = clampf(p, 0.0, 1.0)
		var horiz_x: float = lerpf(world_from.x, world_to.x, t)
		var horiz_z: float = lerpf(world_from.z, world_to.z, t)
		var fall_t: float = clampf((t - 0.2) / 0.8, 0.0, 1.0)
		var base_y: float = lerpf(world_from.y, world_to.y, fall_t * fall_t)
		var arc_h: float = profile.drop_arc_height if profile != null else 0.35
		var arc: float = 4.0 * arc_h * t * (1.0 - t)
		target_pos = Vector3(horiz_x, base_y + arc, horiz_z)
	elif current_transition_type == _ResultScript.TransitionType.JUMP_UP:
		var t: float = clampf(p, 0.0, 1.0)
		var base_pos: Vector3 = world_from.lerp(world_to, t)
		var arc_h: float = profile.drop_arc_height if profile != null else 0.35
		var arc: float = 4.0 * arc_h * t * (1.0 - t)
		target_pos = base_pos + Vector3.UP * arc
	elif current_transition_type == _ResultScript.TransitionType.FALL:
		# Trayectoria de caída: desplazamiento horizontal con caída vertical acelerada
		var horiz_x: float = lerpf(world_from.x, world_to.x, p)
		var horiz_z: float = lerpf(world_from.z, world_to.z, p)
		var drop_t: float = clampf((p - 0.2) / 0.8, 0.0, 1.0)
		var vert_y: float = lerpf(world_from.y, world_to.y, drop_t * drop_t)
		target_pos = Vector3(horiz_x, vert_y, horiz_z)
	else:
		target_pos = world_from.lerp(world_to, p)

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
		var target_pos: Vector3 = grid.cell_to_world(cell, y_offset)
		if target_actor.is_inside_tree():
			target_actor.global_position = target_pos
		else:
			target_actor.position = target_pos
		_turn_actor_towards_facing(0.0)

## Busca la mejor dirección de salto (DROP hacia abajo o JUMP_UP hacia arriba),
## priorizando la orientación donde mira el actor (siempre que la celda destino esté desocupada).
func find_best_jump_direction(p_facing: Vector2 = Vector2.ZERO) -> Vector2i:
	if grid == null:
		return Vector2i.ZERO

	var facing_v := p_facing
	if facing_v == Vector2.ZERO:
		if facing != Vector2i.ZERO:
			facing_v = Vector2(facing.x, facing.y).normalized()
		elif target_actor != null:
			var rot_y: float = target_actor.rotation.y
			facing_v = Vector2(-sin(rot_y), -cos(rot_y)).normalized()
		else:
			facing_v = Vector2(0, 1)

	var active_rules: MovementRules = rules if rules != null else _RulesScript.new()
	var active_profile: MovementProfile = profile if profile != null else _ProfileScript.new()
	var cur_level: int = grid.get_elevation_level(current_cell) if grid.has_method("get_elevation_level") else 0

	var candidate_dirs: Array[Vector2i] = [
		Vector2i(0, -1), # Norte
		Vector2i(0, 1),  # Sur
		Vector2i(1, 0),  # Este
		Vector2i(-1, 0), # Oeste
	]

	var best_dir := Vector2i.ZERO
	var best_dot: float = -999.0
	var best_delta_abs: int = 999

	for dir in candidate_dirs:
		var target: Vector2i = current_cell + dir
		var res: MovementResult = active_rules.validate_transition(
			current_cell,
			target,
			grid,
			active_profile,
			occupancy,
			target_actor,
			true # is_jump
		)

		if not res.accepted:
			continue

		var target_level: int = grid.get_elevation_level(target) if grid.has_method("get_elevation_level") else cur_level
		var delta_level: int = target_level - cur_level
		if delta_level == 0:
			continue

		var dir_v := Vector2(dir.x, dir.y).normalized()
		var dot: float = facing_v.dot(dir_v)
		var delta_abs: int = absi(delta_level)

		# Mayor prioridad a la orientación donde mira el personaje (dot),
		# y ante alineaciones equivalentes, menor desnivel (más próxima).
		if dot > best_dot or (is_equal_approx(dot, best_dot) and delta_abs < best_delta_abs):
			best_dot = dot
			best_delta_abs = delta_abs
			best_dir = dir

	return best_dir

## Ejecuta un salto hacia una celda con desnivel (arriba o abajo). Si no se especifica dirección,
## busca automáticamente la mejor según la orientación del personaje.
func request_jump(p_direction: Vector2i = Vector2i.ZERO) -> MovementResult:
	if is_moving:
		return null

	var jump_dir := p_direction
	if jump_dir != Vector2i.ZERO:
		# Comprobar si la dirección indicada tiene un desnivel válido desocupado
		var active_rules: MovementRules = rules if rules != null else _RulesScript.new()
		var active_profile: MovementProfile = profile if profile != null else _ProfileScript.new()
		var test_res = active_rules.validate_transition(
			current_cell,
			current_cell + jump_dir,
			grid,
			active_profile,
			occupancy,
			target_actor,
			true
		)
		var cur_level: int = grid.get_elevation_level(current_cell) if grid.has_method("get_elevation_level") else 0
		var tgt_level: int = grid.get_elevation_level(current_cell + jump_dir) if grid.has_method("get_elevation_level") else cur_level
		if not test_res.accepted or tgt_level == cur_level:
			# Si la dirección presionada no es un desnivel saltable válido, buscar la mejor dirección alternativa
			jump_dir = Vector2i.ZERO

	if jump_dir == Vector2i.ZERO:
		jump_dir = find_best_jump_direction()

	if jump_dir == Vector2i.ZERO:
		return null

	var req := _RequestScript.new(jump_dir, &"player", true)
	return request_movement(req)

func is_in_drop_windup() -> bool:
	return is_moving and current_transition_type == _ResultScript.TransitionType.DROP and _drop_windup_remaining > 0.0
