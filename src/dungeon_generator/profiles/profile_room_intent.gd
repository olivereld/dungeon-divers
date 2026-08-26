class_name ProfileRoomIntent
extends RefCounted

## Intención semántica declarativa de una sala.

var type: StringName = &"transition"
var focal: bool = false
var symmetry: bool = false
var player_clearance_level: int = 1
var allowed_tags: Array[StringName] = []
var forbidden_tags: Array[StringName] = []

func _init(
	p_type: StringName = &"transition",
	p_focal: bool = false,
	p_symmetry: bool = false,
	p_clearance: int = 1,
	p_allowed_tags: Array[StringName] = [],
	p_forbidden_tags: Array[StringName] = []
) -> void:
	type = p_type
	focal = p_focal
	symmetry = p_symmetry
	player_clearance_level = p_clearance
	allowed_tags = p_allowed_tags
	forbidden_tags = p_forbidden_tags

func is_tag_allowed(tag: StringName) -> bool:
	if forbidden_tags.has(tag):
		return false
	if allowed_tags.is_empty():
		return true
	return allowed_tags.has(tag)
