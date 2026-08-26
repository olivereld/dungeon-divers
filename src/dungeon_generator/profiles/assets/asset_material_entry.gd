class_name AssetMaterialEntry
extends RefCounted

## Definición tipada de un perfil de materiales en el AssetRegistry.
## Deserializado desde resources/dungeon_profiles/assets/materials.json.

var id: StringName = &""
var floor_path: String = ""
var wall_path: String = ""
var trim_path: String = ""

func _init(
	p_id: StringName = &"",
	p_floor: String = "",
	p_wall: String = "",
	p_trim: String = ""
) -> void:
	id = p_id
	floor_path = p_floor
	wall_path = p_wall
	trim_path = p_trim
