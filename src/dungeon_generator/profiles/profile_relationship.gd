class_name ProfileRelationship
extends RefCounted

## Relación espacial declarativa (ej. Prop -> Fixture).

var id: StringName = &""
var source: Array[StringName] = []
var targets: Array[StringName] = []
var forbidden_targets: Array[StringName] = []
var placement: StringName = &"near" # "near", "above", "flanking"
var min_count: int = 1
var max_count: int = 2
var min_distance: float = 1.0
var max_distance: float = 2.0

func _init(
	p_id: StringName = &"",
	p_source: Array[StringName] = [],
	p_targets: Array[StringName] = [],
	p_forbidden: Array[StringName] = [],
	p_placement: StringName = &"near",
	p_min: int = 1,
	p_max: int = 2,
	p_min_dist: float = 1.0,
	p_max_dist: float = 2.0
) -> void:
	id = p_id
	source = p_source
	targets = p_targets
	forbidden_targets = p_forbidden
	placement = p_placement
	min_count = p_min
	max_count = p_max
	min_distance = p_min_dist
	max_distance = p_max_dist
