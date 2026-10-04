class_name MovementRequest
extends RefCounted

## Representa una intención de movimiento discreto por celdas.
## No mueve directamente al actor; es evaluado por MovementComponent y MovementRules.

var direction: Vector2i = Vector2i.ZERO
var source: StringName = &""

func _init(p_direction: Vector2i = Vector2i.ZERO, p_source: StringName = &"") -> void:
	direction = p_direction
	source = p_source

func is_valid() -> bool:
	return direction != Vector2i.ZERO and abs(direction.x) <= 1 and abs(direction.y) <= 1

func is_8way() -> bool:
	return is_valid()

func is_cardinal_4way() -> bool:
	return (abs(direction.x) + abs(direction.y) == 1)

func is_diagonal() -> bool:
	return abs(direction.x) == 1 and abs(direction.y) == 1
