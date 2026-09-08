class_name CombatOutcomeResolver
extends RefCounted


func apply_attack(
	attack_result: AttackResult,
	target_health: Health
) -> CombatOutcome:
	assert(attack_result != null)
	assert(target_health != null)

	var hp_before := target_health.current_hp

	if not attack_result.has_damage():
		return CombatOutcome.new(
			0.0,
			hp_before,
			hp_before,
			target_health.is_dead()
		)

	var damage_result := attack_result.damage_result

	assert(
		not damage_result.was_miss,
		"An attack with damage must not be marked as a miss."
	)

	var damage_applied := target_health.apply_damage(
		damage_result.final_damage
	)

	return CombatOutcome.new(
		damage_applied,
		hp_before,
		target_health.current_hp,
		target_health.is_dead()
	)