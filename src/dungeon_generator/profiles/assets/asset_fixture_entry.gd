class_name AssetFixtureEntry
extends RefCounted

## Definición tipada de una Luminaria/Fixture en el AssetRegistry.
## Deserializado desde resources/dungeon_profiles/assets/fixtures.json.

var id: StringName = &""
var scene_path: String = ""
var style: StringName = &"torch" # "torch", "lantern", "brazier", "candle_holder", "candle_cluster"
var placement_modes: Array[StringName] = []
var anchors: Array[StringName] = [] # "floor", "wall", "ceiling", "surface"
var tags: Array[StringName] = []

func _init(
	p_id: StringName = &"",
	p_scene: String = "",
	p_style: StringName = &"torch",
	p_placement: Array[StringName] = [],
	p_anchors: Array[StringName] = [],
	p_tags: Array[StringName] = []
) -> void:
	id = p_id
	scene_path = p_scene
	style = p_style
	placement_modes = p_placement
	anchors = p_anchors
	tags = p_tags

func has_tag(p_tag: StringName) -> bool:
	return tags.has(p_tag)

func supports_placement(p_mode: StringName) -> bool:
	return placement_modes.has(p_mode)
