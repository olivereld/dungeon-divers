class_name StairData
extends Resource

## Contrato de punto de anclaje de escalera en un piso específico (Fase 10 - Verticalidad).
## Representa el endpoint físico de una conexión vertical en un CellGrid determinado.

@export var stair_id: String = ""
@export var floor_number: int = 0
@export var cell: Vector2i = Vector2i.ZERO
@export var orientation: float = 0.0 ## Rotación en radianes (0, PI/2, PI, -PI/2)
@export var connection_id: String = "" ## Vínculo topológico con su FloorConnection
@export var is_downward: bool = false ## true = desciende al piso inferior, false = asciende al superior

func _init(
	p_stair_id: String = "",
	p_floor_number: int = 0,
	p_cell: Vector2i = Vector2i.ZERO,
	p_orientation: float = 0.0,
	p_connection_id: String = "",
	p_is_downward: bool = false
) -> void:
	stair_id = p_stair_id
	floor_number = p_floor_number
	cell = p_cell
	orientation = p_orientation
	connection_id = p_connection_id
	is_downward = p_is_downward

## Valida las invariantes fundamentales del StairData.
func is_valid() -> bool:
	return not stair_id.is_empty() and not connection_id.is_empty() and floor_number >= 0

func _to_string() -> String:
	return "StairData(id='%s', floor=%d, cell=%s, dir=%s, conn='%s')" % [
		stair_id, floor_number, str(cell), "DOWN" if is_downward else "UP", connection_id
	]
