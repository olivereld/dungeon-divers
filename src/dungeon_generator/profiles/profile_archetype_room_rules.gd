class_name ProfileArchetypeRoomRules
extends RefCounted

## Reglas de distribución y restricciones de salas para un arquetipo.

var allow_duplicate_purposes: bool = true
var max_same_purpose_consecutive: int = 2
var guaranteed: Array[StringName] = []
var rare: Array[StringName] = []

func _init(
	p_allow_dupes: bool = true,
	p_max_consec: int = 2,
	p_guaranteed: Array[StringName] = [],
	p_rare: Array[StringName] = []
) -> void:
	allow_duplicate_purposes = p_allow_dupes
	max_same_purpose_consecutive = p_max_consec
	guaranteed = p_guaranteed
	rare = p_rare
