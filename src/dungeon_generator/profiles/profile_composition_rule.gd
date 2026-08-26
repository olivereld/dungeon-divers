class_name ProfileCompositionRule
extends RefCounted

## Regla de colocación de composición para props primarios o secundarios.

var rule_id: StringName = &""
var asset_tags: Array[StringName] = []
var forbidden_tags: Array[StringName] = []
var placement_mode: StringName = &"floor" # "center", "floor", "wall", "corner"
var orientation: StringName = &"face_room" # "face_room", "fixed", "random"
var min_count: int = 1
var max_count: int = 1
var clearance: int = 0

func _init(
	p_rule_id: StringName = &"",
	p_tags: Array[StringName] = [],
	p_forbidden: Array[StringName] = [],
	p_mode: StringName = &"floor",
	p_orientation: StringName = &"face_room",
	p_min: int = 1,
	p_max: int = 1,
	p_clearance: int = 0
) -> void:
	rule_id = p_rule_id
	asset_tags = p_tags
	forbidden_tags = p_forbidden
	placement_mode = p_mode
	orientation = p_orientation
	min_count = p_min
	max_count = p_max
	clearance = p_clearance
