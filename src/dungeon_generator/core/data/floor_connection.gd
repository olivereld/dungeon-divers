class_name FloorConnection
extends Resource

## Autoridad topológica de enlace vertical entre dos pisos (Fase 10 - Verticalidad).
## Conecta bidireccionalmente dos endpoints de escalera (StairData) en diferentes pisos.

@export var connection_id: String = ""
@export var from_floor: int = 0
@export var to_floor: int = 0
@export var from_stair_id: String = ""
@export var to_stair_id: String = ""
@export var from_cell: Vector2i = Vector2i.ZERO
@export var to_cell: Vector2i = Vector2i.ZERO

func _init(
	p_connection_id: String = "",
	p_from_floor: int = 0,
	p_to_floor: int = 0,
	p_from_stair_id: String = "",
	p_to_stair_id: String = "",
	p_from_cell: Vector2i = Vector2i.ZERO,
	p_to_cell: Vector2i = Vector2i.ZERO
) -> void:
	connection_id = p_connection_id
	from_floor = p_from_floor
	to_floor = p_to_floor
	from_stair_id = p_from_stair_id
	to_stair_id = p_to_stair_id
	from_cell = p_from_cell
	to_cell = p_to_cell

## Retorna true si la conexión desciende de un piso superior a uno inferior.
func is_downward() -> bool:
	return to_floor < from_floor

## Retorna true si la conexión asciende de un piso inferior a uno superior.
func is_upward() -> bool:
	return to_floor > from_floor

## Valida las invariantes fundamentales de enlace vertical.
func is_valid() -> bool:
	if connection_id.is_empty():
		return false
	if from_floor == to_floor:
		return false
	if from_floor < 0 or to_floor < 0:
		return false
	if from_stair_id.is_empty() or to_stair_id.is_empty():
		return false
	if from_stair_id == to_stair_id:
		return false
	return true

## Crea un par coherente de StairData para ambos extremos de la conexión.
func create_stair_pair(from_orientation: float = 0.0, to_orientation: float = 0.0) -> Array[StairData]:
	var from_stair := StairData.new(
		from_stair_id,
		from_floor,
		from_cell,
		from_orientation,
		connection_id,
		is_downward(),
		to_floor
	)
	var to_stair := StairData.new(
		to_stair_id,
		to_floor,
		to_cell,
		to_orientation,
		connection_id,
		not is_downward(),
		from_floor
	)
	return [from_stair, to_stair]

func _to_string() -> String:
	return "FloorConnection(id='%s', F%d(%s) ➔ F%d(%s))" % [
		connection_id, from_floor, str(from_cell), to_floor, str(to_cell)
	]
