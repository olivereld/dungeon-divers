class_name DecorationRoomIntent
extends Resource

## Intención semántica, directivas y restricciones duras para la composición de una sala.

const _DecorationRoomZoneScript = preload("res://src/presentation/decoration/composition/decoration_room_zone.gd")

@export var focal_zone: int = _DecorationRoomZoneScript.ZoneType.FOCAL
@export var symmetry_required: bool = false
@export var player_clearance_level: int = 1
@export var lighting_budget: float = 6.0
@export var combat_space_ratio: float = 0.2
@export var preferred_density: float = 0.4
@export var allowed_tags: Array[StringName] = []
@export var forbidden_tags: Array[StringName] = []
@export var forbidden_zones: Array[int] = [_DecorationRoomZoneScript.ZoneType.ENTRY]

func is_tag_allowed(tag: StringName) -> bool:
	if forbidden_tags.has(tag):
		return false
	if allowed_tags.is_empty():
		return true
	return allowed_tags.has(tag)

func can_place_in_zone(zone_type: int) -> bool:
	return not forbidden_zones.has(zone_type)
