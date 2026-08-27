class_name AssetArchitectureEntry
extends RefCounted

## Entrada deserializada desde resources/dungeon_profiles/assets/architecture.json.

var id: StringName = &""
var category: StringName = &"" # "floor", "wall", "door", "stairs"
var style: StringName = &""
var generator: StringName = &"procedural" # "procedural", "external"
var scene_path: String = ""

func _init(
	p_id: StringName = &"",
	p_category: StringName = &"",
	p_style: StringName = &"",
	p_generator: StringName = &"procedural",
	p_scene: String = ""
) -> void:
	id = p_id
	category = p_category
	style = p_style
	generator = p_generator
	scene_path = p_scene
