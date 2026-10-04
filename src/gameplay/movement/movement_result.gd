class_name MovementResult
extends RefCounted

## Resultado tipado de una solicitud o evaluación de movimiento por celdas.

const REASON_OK: StringName = &"ok"
const REASON_OUT_OF_BOUNDS: StringName = &"out_of_bounds"
const REASON_UNWALKABLE: StringName = &"unwalkable"
const REASON_ELEVATION_TOO_HIGH: StringName = &"elevation_too_high"
const REASON_ELEVATION_TOO_LOW: StringName = &"elevation_too_low"
const REASON_WATER_BLOCKED: StringName = &"water_blocked"
const REASON_OCCUPIED: StringName = &"occupied"
const REASON_BLOCKED_BY_OBSTACLE: StringName = &"blocked_by_obstacle"
const REASON_DIRECTION_NOT_ALLOWED: StringName = &"direction_not_allowed"
const REASON_ALREADY_MOVING: StringName = &"already_moving"
const REASON_INVALID_SOURCE_CELL: StringName = &"invalid_source_cell"

var accepted: bool = false
var reason: StringName = &""
var from_cell: Vector2i = Vector2i.ZERO
var to_cell: Vector2i = Vector2i.ZERO

func _init(
	p_accepted: bool = false,
	p_reason: StringName = &"",
	p_from_cell: Vector2i = Vector2i.ZERO,
	p_to_cell: Vector2i = Vector2i.ZERO
) -> void:
	accepted = p_accepted
	reason = p_reason
	from_cell = p_from_cell
	to_cell = p_to_cell

static func accept(p_from: Vector2i, p_to: Vector2i) -> MovementResult:
	return MovementResult.new(true, REASON_OK, p_from, p_to)

static func reject(p_reason: StringName, p_from: Vector2i, p_to: Vector2i) -> MovementResult:
	return MovementResult.new(false, p_reason, p_from, p_to)
