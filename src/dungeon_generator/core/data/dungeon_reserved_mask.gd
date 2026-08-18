class_name DungeonReservedMask
extends RefCounted

## Máscara canónica de reserva espacial de la mazmorra (Fase 12).
## Es la ÚNICA fuente de verdad para impedir solapamientos entre puertas, zonas de paso/despeje,
## columnas, antorchas, escombros, cofres, santuarios y puntos de spawn/boss.

var _reservations: Dictionary = {} # Vector2i -> String (reason)

## Intenta reservar una celda específica con un motivo determinado.
## Retorna true si se reservó con éxito, false si ya estaba ocupada.
func reserve(pos: Vector2i, reason: String) -> bool:
	if _reservations.has(pos):
		return false
	_reservations[pos] = reason
	return true

## Fuerza la reserva incluso si existía una previa (ej. DOOR sobre DOORWAY).
func force_reserve(pos: Vector2i, reason: String) -> void:
	_reservations[pos] = reason

## Verifica si una celda está reservada.
func is_reserved(pos: Vector2i) -> bool:
	return _reservations.has(pos)

## Obtiene el motivo de la reserva de una celda.
func get_reason(pos: Vector2i) -> String:
	return _reservations.get(pos, "")

## Intenta reservar un área rectangular completa.
func reserve_rect(rect: Rect2i, reason: String) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var p := Vector2i(x, y)
			if _reservations.has(p):
				return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_reservations[Vector2i(x, y)] = reason
	return true

## Retorna todas las celdas reservadas.
func get_all_reserved_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for k in _reservations.keys():
		cells.append(k)
	return cells

func get_reservation_count() -> int:
	return _reservations.size()
