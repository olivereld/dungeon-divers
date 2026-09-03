class_name RoomPlacementPlan
extends RefCounted

## Contrato estructurado para el plan de colocación espacial.
## Es de solo lectura una vez construido (sellado), evitando mutaciones externas arbitrarias.
## La geometría dimensional (size) se mantiene únicamente en RoomData.

class PlacementEntry:
	var room_id: int
	var position: Vector2i
	var region: StringName
	var priority: int

	func _init(p_room_id: int, p_pos: Vector2i, p_region: StringName = &"", p_priority: int = 0) -> void:
		room_id = p_room_id
		position = p_pos
		region = p_region
		priority = p_priority

	func to_dict() -> Dictionary:
		return {
			"room_id": room_id,
			"position": position,
			"region": region,
			"priority": priority
		}

var _entries: Dictionary = {} # int (room_id) -> PlacementEntry
var _is_sealed: bool = false

## Agrega una decisión de colocación durante la fase de construcción.
## Falla si el plan ya ha sido sellado.
func add_entry(p_room_id: int, p_pos: Vector2i, p_region: StringName = &"", p_priority: int = 0) -> void:
	assert(not _is_sealed, "RoomPlacementPlan is sealed and cannot be modified.")
	var entry := PlacementEntry.new(p_room_id, p_pos, p_region, p_priority)
	_entries[p_room_id] = entry

## Sella el plan convirtiéndolo en un objeto inmutable de solo lectura.
func seal() -> void:
	_is_sealed = true

func is_sealed() -> bool:
	return _is_sealed

func has_placement(p_room_id: int) -> bool:
	return _entries.has(p_room_id)

func get_position(p_room_id: int) -> Vector2i:
	assert(_entries.has(p_room_id), "Room %d has no placement entry in plan." % p_room_id)
	return (_entries[p_room_id] as PlacementEntry).position

func get_region(p_room_id: int) -> StringName:
	assert(_entries.has(p_room_id), "Room %d has no placement entry in plan." % p_room_id)
	return (_entries[p_room_id] as PlacementEntry).region

func get_priority(p_room_id: int) -> int:
	assert(_entries.has(p_room_id), "Room %d has no placement entry in plan." % p_room_id)
	return (_entries[p_room_id] as PlacementEntry).priority

func get_placement(p_room_id: int) -> Dictionary:
	if not _entries.has(p_room_id):
		return {}
	return (_entries[p_room_id] as PlacementEntry).to_dict()

func get_all_room_ids() -> Array[int]:
	var ids: Array[int] = []
	for k in _entries.keys():
		ids.append(int(k))
	ids.sort()
	return ids

func get_rooms_in_region(p_region: StringName) -> Array[int]:
	var result: Array[int] = []
	for room_id in _entries:
		var entry: PlacementEntry = _entries[room_id]
		if entry.region == p_region:
			result.append(entry.room_id)
	result.sort()
	return result

func size() -> int:
	return _entries.size()

func is_empty() -> bool:
	return _entries.is_empty()
