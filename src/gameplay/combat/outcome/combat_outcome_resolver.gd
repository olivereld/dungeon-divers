class_name CombatOutcomeResolver
extends RefCounted


func apply_attack(
	attack_result: AttackResult,
	target_health: Health
) -> CombatOutcome:
	assert(attack_result != null)
	assert(target_health != null)

	assert(
		target_health.is_alive(),
		"Cannot apply an attack to a dead target."
	)

	var hp_before := target_health.current_hp
	var was_alive := target_health.is_alive()

	if not attack_result.has_damage():
		return CombatOutcome.new(
			0.0,
			hp_before,
			hp_before,
			false
		)

	var damage_result := attack_result.damage_result

	assert(
		not damage_result.was_miss,
		"An attack with damage must not be marked as a miss."
	)

	var damage_applied := target_health.apply_damage(
		damage_result.final_damage
	)

	var target_died := was_alive and target_health.is_dead()

	return CombatOutcome.new(
		damage_applied,
		hp_before,
		target_health.current_hp,
		target_died
	)