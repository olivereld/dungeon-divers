class_name DungeonArchetypeProfile
extends Resource

## Perfil de configuración de arquetipo arquitectónico de mazmorra.
## Define los pesos de propósitos de sala y el mapeo de compatibilidad con roles de gameplay.

const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

@export var archetype: _DungeonArchetypeScript.Type = _DungeonArchetypeScript.Type.GENERIC
@export var purpose_weights: Dictionary = {} # RoomPurpose.Type (int) -> float weight
@export var gameplay_purpose_map: Dictionary = {} # String ("START", "BOSS", "TREASURE", "COMBAT", "EXPLORE") -> Array[int]

func get_allowed_purposes_for_gameplay(gameplay_role: String) -> Array:
	if gameplay_purpose_map.has(gameplay_role):
		return gameplay_purpose_map[gameplay_role]
	return [_RoomPurposeScript.Type.GENERIC]
