class_name MovementResult
extends RefCounted

## Resultado tipado de una solicitud o evaluación de movimiento por celdas.

enum TransitionType {
	WALK,      ## Misma elevación (delta_level == 0)
	STEP_UP,   ## Subir escalón (+1 <= max_step_up)
	STEP_DOWN, ## Bajar escalón (-1 >= -max_step_down)
	DROP,      ## Salto/descenso controlado en arco hacia superficie inferior
	FALL,      ## Caída vertical hacia superficie inferior (delta_level < -max_step_down)
	JUMP_UP    ## Salto controlado en arco hacia superficie superior
}

const REASON_OK: StringName = &"ok"
const REASON_OUT_OF_BOUNDS: StringName = &"out_of_bounds"
const REASON_UNWALKABLE: StringName = &"unwalkable"
const REASON_ELEVATION_TOO_HIGH: StringName = &"elevation_too_high"
const REASON_ELEVATION_TOO_LOW: StringName = &"elevation_too_low"
const REASON_DROP_TOO_HIGH: StringName = &"drop_too_high"
const REASON_DROP_NOT_ALLOWED: StringName = &"drop_not_allowed"
const REASON_FALL_TOO_HIGH: StringName = &"fall_too_high"
const REASON_FALL_NOT_ALLOWED: StringName = &"fall_not_allowed"
const REASON_NO_SURFACE_BELOW: StringName = &"no_surface_below"
const REASON_WATER_BLOCKED: StringName = &"water_blocked"
const REASON_OCCUPIED: StringName = &"occupied"
const REASON_BLOCKED_BY_OBSTACLE: StringName = &"blocked_by_obstacle"
const REASON_DIRECTION_NOT_ALLOWED: StringName = &"direction_not_allowed"
const REASON_DIAGONAL_CORNER_BLOCKED: StringName = &"diagonal_corner_blocked"
const REASON_ALREADY_MOVING: StringName = &"already_moving"
const REASON_INVALID_SOURCE_CELL: StringName = &"invalid_source_cell"
const REASON_CHUNK_UNAVAILABLE: StringName = &"chunk_unavailable"
const REASON_JUMP_REQUIRED: StringName = &"jump_required"

var accepted: bool = false
var reason: StringName = &""
var from_cell: Vector2i = Vector2i.ZERO
var to_cell: Vector2i = Vector2i.ZERO
var transition_type: TransitionType = TransitionType.WALK

func _init(
	p_accepted: bool = false,
	p_reason: StringName = &"",
	p_from_cell: Vector2i = Vector2i.ZERO,
	p_to_cell: Vector2i = Vector2i.ZERO,
	p_type: TransitionType = TransitionType.WALK
) -> void:
	accepted = p_accepted
	reason = p_reason
	from_cell = p_from_cell
	to_cell = p_to_cell
	transition_type = p_type

static func accept(p_from: Vector2i, p_to: Vector2i, p_type: TransitionType = TransitionType.WALK) -> MovementResult:
	return MovementResult.new(true, REASON_OK, p_from, p_to, p_type)

static func reject(p_reason: StringName, p_from: Vector2i, p_to: Vector2i) -> MovementResult:
	return MovementResult.new(false, p_reason, p_from, p_to, TransitionType.WALK)
