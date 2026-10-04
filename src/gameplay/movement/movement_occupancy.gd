class_name MovementOccupancy
extends RefCounted

## Gestiona la ocupación dinámica de celdas por entidades runtime.
## Totalmente desacoplado de MovementGrid y el terreno estático.

var _occupied_cells: Dictionary = {} # Vector2i -> Object
var _reserved_cells: Dictionary = {} # Vector2i -> Object

## Comprueba si una celda está ocupada o reservada por alguna entidad distinta a entity_to_ignore.
func is_occupied(cell: Vector2i, entity_to_ignore: Object = null) -> bool:
	if _occupied_cells.has(cell):
		if entity_to_ignore == null or _occupied_cells[cell] != entity_to_ignore:
			return true
	if _reserved_cells.has(cell):
		if entity_to_ignore == null or _reserved_cells[cell] != entity_to_ignore:
			return true
	return false

## Retorna la entidad que ocupa o reservó la celda (si existe).
func get_occupant(cell: Vector2i) -> Object:
	if _occupied_cells.has(cell):
		return _occupied_cells[cell]
	if _reserved_cells.has(cell):
		return _reserved_cells[cell]
	return null

## Evalúa si una entidad puede reservar una celda de destino.
func can_reserve(cell: Vector2i, entity: Object) -> bool:
	return not is_occupied(cell, entity)

## Reserva atómicamente la celda de destino para una entidad antes de comenzar la transición.
func reserve(cell: Vector2i, entity: Object) -> bool:
	if is_occupied(cell, entity):
		return false
	_reserved_cells[cell] = entity
	return true

## Asienta la ocupación definitiva de la celda al completarse la transición.
func occupy(cell: Vector2i, entity: Object) -> void:
	_reserved_cells.erase(cell)
	_occupied_cells[cell] = entity

## Libera una celda ocupada o reservada por una entidad (usualmente la celda origen tras moverse).
func release(cell: Vector2i, entity: Object = null) -> void:
	if _occupied_cells.has(cell):
		if entity == null or _occupied_cells[cell] == entity:
			_occupied_cells.erase(cell)
	if _reserved_cells.has(cell):
		if entity == null or _reserved_cells[cell] == entity:
			_reserved_cells.erase(cell)

## Cancela una reserva previa si la transición no pudo completarse.
func cancel_reservation(cell: Vector2i, entity: Object = null) -> void:
	if _reserved_cells.has(cell):
		if entity == null or _reserved_cells[cell] == entity:
			_reserved_cells.erase(cell)

## Remueve todas las reservas y ocupaciones asociadas a una entidad (e.g. al eliminarse el nodo).
func unregister_entity(entity: Object) -> void:
	if entity == null:
		return
	var to_erase_occ: Array[Vector2i] = []
	for c in _occupied_cells:
		if _occupied_cells[c] == entity:
			to_erase_occ.append(c)
	for c in to_erase_occ:
		_occupied_cells.erase(c)

	var to_erase_res: Array[Vector2i] = []
	for c in _reserved_cells:
		if _reserved_cells[c] == entity:
			to_erase_res.append(c)
	for c in to_erase_res:
		_reserved_cells.erase(c)

func clear() -> void:
	_occupied_cells.clear()
	_reserved_cells.clear()
