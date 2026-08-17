class_name CellGridJournal
extends RefCounted

## Gestor de transacciones y rollback atómico para CellGrid.
## Garantiza que únicamente se registre el estado inicial previo a cualquier mutación.
## Si una celda se modifica varias veces durante una reparación, solo se preserva el estado original.

var _original_entries: Dictionary = {} # Vector2i -> { "type": CellGrid.CellType, "metadata": Dictionary }

## Registra el estado original de una celda si no ha sido registrada previamente en esta transacción.
func record_cell(grid: CellGrid, pos: Vector2i) -> void:
	if grid == null or not grid.is_in_bounds(pos):
		return
	if _original_entries.has(pos):
		return # Ya guardamos el estado original inicial
	_original_entries[pos] = {
		"type": grid.get_cell(pos),
		"metadata": grid.get_cell_metadata_dict(pos)
	}

## Registra todas las celdas dentro de un rectángulo.
func record_rect(grid: CellGrid, rect: Rect2i) -> void:
	if grid == null:
		return
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var pos := Vector2i(x, y)
			if grid.is_in_bounds(pos) and not _original_entries.has(pos):
				_original_entries[pos] = {
					"type": grid.get_cell(pos),
					"metadata": grid.get_cell_metadata_dict(pos)
				}

## Revierte todas las celdas modificadas a su estado original exacto.
func rollback(grid: CellGrid) -> void:
	if grid == null:
		_original_entries.clear()
		return
	for pos: Vector2i in _original_entries:
		var entry: Dictionary = _original_entries[pos]
		grid.set_cell(pos, entry["type"])
		grid.set_cell_metadata_dict(pos, entry["metadata"])
	_original_entries.clear()

## Confirma los cambios realizados, descartando el registro de rollback.
func commit() -> void:
	_original_entries.clear()

## Retorna verdadero si hay entradas registradas en la transacción actual.
func has_changes() -> bool:
	return not _original_entries.is_empty()

## Retorna la cantidad de celdas originales registradas.
func get_modified_cells_count() -> int:
	return _original_entries.size()
