class_name AttackResult
extends RefCounted


var hit_outcome: CombatTypes.HitOutcome
var critical_outcome: CombatTypes.CriticalOutcome


func _init(
	p_hit_outcome: CombatTypes.HitOutcome,
	p_critical_outcome: CombatTypes.CriticalOutcome
) -> void:
	hit_outcome = p_hit_outcome
	critical_outcome = p_critical_outcome


func did_hit() -> bool:
	return hit_outcome == CombatTypes.HitOutcome.HIT


func was_critical() -> bool:
	return did_hit() and critical_outcome == CombatTypes.CriticalOutcome.CRITICAL