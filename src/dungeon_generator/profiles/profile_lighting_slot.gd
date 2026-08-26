class_name ProfileLightingSlot
extends RefCounted

## Ranura de iluminación (wall, floor, hanging).

var min_count: int = 0
var max_count: int = 0
var allowed: Array[StringName] = []

func _init(p_min: int = 0, p_max: int = 0, p_allowed: Array[StringName] = []) -> void:
	min_count = p_min
	max_count = p_max
	allowed = p_allowed
