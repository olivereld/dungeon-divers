class_name WallOpeningManifest
extends Resource

## Manifiesto de vanos de pared por arista perimetral orientada (Fase 9).
## Actúa como contrato neutro entre la topología de puertas y el generador de muros continuos.
## Garantiza la invariante de unicidad estricta por (cell, side).

class WallOpening:
	var cell: Vector2i = Vector2i.ZERO
	var side: int = 0
	var connection_id: String = ""

	func _init(p_cell: Vector2i = Vector2i.ZERO, p_side: int = 0, p_conn_id: String = "") -> void:
		cell = p_cell
		side = p_side
		connection_id = p_conn_id

	func to_debug_string() -> String:
		return "WallOpening(Cell: %s, Side: %d, Conn: %s)" % [str(cell), side, connection_id]

var openings: Array[WallOpening] = []

## Registra un vano garantizando unicidad estricta. Devuelve false si ya existía un vano en (cell, side).
func add_opening(cell: Vector2i, side: int, connection_id: String = "") -> bool:
	if has_opening(cell, side):
		return false
	var op := WallOpening.new(cell, side, connection_id)
	openings.append(op)
	return true

## Comprueba si existe un vano registrado en la arista orientada (cell, side).
func has_opening(cell: Vector2i, side: int) -> bool:
	for op in openings:
		if op.cell == cell and op.side == side:
			return true
	return false

## Obtiene todos los vanos registrados para una celda.
func get_openings_for_cell(cell: Vector2i) -> Array[WallOpening]:
	var result: Array[WallOpening] = []
	for op in openings:
		if op.cell == cell:
			result.append(op)
	return result

## Número total de vanos registrados.
func size() -> int:
	return openings.size()

## Limpia todos los vanos registrados.
func clear() -> void:
	openings.clear()
