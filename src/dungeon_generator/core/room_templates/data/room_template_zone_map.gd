class_name RoomTemplateZoneMap
extends RefCounted

## Mapa de zonas de reserva espacial de una sala (focal, entrance_clearance, circulation, perimeter, wall_niche).
## Define particiones funcionales y espaciales sin mezclar decoración ni prop placement concreto.

var room_rect: Rect2i = Rect2i()
var _cell_zones: Dictionary = {} # Vector2i -> StringName

func _init(p_rect: Rect2i = Rect2i()) -> void:
	room_rect = p_rect

func set_zone(cell: Vector2i, zone_type: StringName) -> void:
	_cell_zones[cell] = zone_type

func get_zone(cell: Vector2i) -> StringName:
	return _cell_zones.get(cell, &"unassigned")

func get_cells_in_zone(zone_type: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _cell_zones:
		if _cell_zones[cell] == zone_type:
			result.append(cell)
	return result

func has_zone(zone_type: StringName) -> bool:
	for cell in _cell_zones:
		if _cell_zones[cell] == zone_type:
			return true
	return false

func get_all_assigned_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in _cell_zones:
		result.append(cell)
	return result

func clear() -> void:
	_cell_zones.clear()
