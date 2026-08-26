class_name AssetPropEntry
extends RefCounted

## Definición tipada de un elemento de Prop en el AssetRegistry.
## Deserializado desde resources/dungeon_profiles/assets/props.json.

var id: StringName = &""
var scene_path: String = ""
var tags: Array[StringName] = []
var placement_modes: Array[StringName] = []
var footprint: Vector2i = Vector2i.ONE # width, depth en celdas
var collision: StringName = &"blocking" # "blocking", "footprint", "interactive", "none"
var anchors: Array[StringName] = [] # "floor", "wall", "ceiling", "surface"

func _init(
	p_id: StringName = &"",
	p_scene: String = "",
	p_tags: Array[StringName] = [],
	p_placement: Array[StringName] = [],
	p_footprint: Vector2i = Vector2i.ONE,
	p_collision: StringName = &"blocking",
	p_anchors: Array[StringName] = []
) -> void:
	id = p_id
	scene_path = p_scene
	tags = p_tags
	placement_modes = p_placement
	footprint = p_footprint
	collision = p_collision
	anchors = p_anchors

func has_tag(p_tag: StringName) -> bool:
	return tags.has(p_tag)

func supports_placement(p_mode: StringName) -> bool:
	return placement_modes.has(p_mode)
