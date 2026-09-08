class_name AttackResult
extends RefCounted

var hit_outcome: CombatTypes.HitOutcome
var critical_outcome: CombatTypes.CriticalOutcome
var damage_result: DamageResult

func _init(
	p_hit_outcome: CombatTypes.HitOutcome,
	p_critical_outcome: CombatTypes.CriticalOutcome,
	p_damage_result: DamageResult = null
) -> void:
	hit_outcome = p_hit_outcome
	critical_outcome = p_critical_outcome
	damage_result = p_damage_result

func did_hit() -> bool:
	return hit_outcome == CombatTypes.HitOutcome.HIT

func was_critical() -> bool:
	return critical_outcome == CombatTypes.CriticalOutcome.CRITICAL

func has_damage() -> bool:
	return damage_result != null