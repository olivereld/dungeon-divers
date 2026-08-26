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

static func from_profile(p) -> DungeonArchetypeProfile:
	var d := DungeonArchetypeProfile.new()
	if p == null:
		return d

	d.archetype = _DungeonArchetypeScript.from_name(str(p.id))

	# Convertir purpose_weights de StringName/String -> int (RoomPurpose.Type)
	for pid in p.purpose_weights:
		var purp_enum = _RoomPurposeScript.from_name(str(pid))
		d.purpose_weights[int(purp_enum)] = float(p.purpose_weights[pid])

	# Convertir gameplay_purpose_map de String -> Array[int]
	for role in p.gameplay_purpose_map:
		var role_key = str(role).to_upper()
		var list = p.gameplay_purpose_map[role]
		var converted_arr: Array = []
		for item in list:
			var purp_enum = _RoomPurposeScript.from_name(str(item))
			converted_arr.append(int(purp_enum))
		d.gameplay_purpose_map[role_key] = converted_arr

	return d

