class_name CombatOutcome
extends RefCounted


var damage_applied: float
var target_hp_before: float
var target_hp_after: float

var target_died: bool


func _init(
	p_damage_applied: float,
	p_target_hp_before: float,
	p_target_hp_after: float,
	p_target_died: bool
) -> void:
	assert(p_damage_applied >= 0.0)
	assert(p_target_hp_before >= 0.0)
	assert(p_target_hp_after >= 0.0)

	damage_applied = p_damage_applied
	target_hp_before = p_target_hp_before
	target_hp_after = p_target_hp_after

	target_died = p_target_died


func did_damage() -> bool:
	return damage_applied > 0.0


func killed_target() -> bool:
	return target_died


func is_target_dead() -> bool:
	return target_hp_after <= 0.0