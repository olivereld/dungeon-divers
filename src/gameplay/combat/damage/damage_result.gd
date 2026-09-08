class_name DamageResult
extends RefCounted


var raw_damage: float
var mitigated_damage: float
var final_damage: float

var damage_type: DamageType.Type

var was_critical: bool
var was_blocked: bool
var was_miss: bool


func _init(
	p_raw_damage: float,
	p_mitigated_damage: float,
	p_final_damage: float,
	p_damage_type: DamageType.Type,
	p_was_critical: bool,
	p_was_blocked: bool = false,
	p_was_miss: bool = false
) -> void:
	assert(p_raw_damage >= 0.0)
	assert(p_mitigated_damage >= 0.0)
	assert(p_final_damage >= 0.0)

	raw_damage = p_raw_damage
	mitigated_damage = p_mitigated_damage
	final_damage = p_final_damage

	damage_type = p_damage_type

	was_critical = p_was_critical
	was_blocked = p_was_blocked
	was_miss = p_was_miss