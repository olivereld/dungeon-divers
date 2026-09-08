class_name DamageCalculator
extends RefCounted


func calculate(
	request: DamageRequest
) -> DamageResult:
	assert(request != null)
	assert(request.attacker_stats != null)
	assert(request.defender_stats != null)

	match request.damage_type:
		DamageType.Type.PHYSICAL:
			return _calculate_physical_damage(request)

		DamageType.Type.MAGICAL:
			return _calculate_magical_damage(request)

	push_error("Unknown damage type.")

	return DamageResult.new(
		0.0,
		0.0,
		0.0,
		request.damage_type,
		false
	)


func _calculate_physical_damage(
	request: DamageRequest
) -> DamageResult:
	var raw_damage := (
		request.base_damage
		+ request.attacker_stats.physical_power
	)

	if request.is_critical:
		raw_damage *= DamageConstants.CRITICAL_DAMAGE_MULTIPLIER

	var blocked_damage := minf(
		raw_damage,
		request.blocked_amount
	)

	var damage_after_block := maxf(
		0.0,
		raw_damage - blocked_damage
	)

	var resilience := clampf(
		request.defender_stats.physical_resilience,
		0.0,
		DamageConstants.PHYSICAL_RESILIENCE_CAP
	)

	var resistance_mitigation := (
		damage_after_block * resilience
	)

	var final_damage := maxf(
		DamageConstants.MIN_DAMAGE,
		damage_after_block - resistance_mitigation
	)

	var total_mitigated := maxf(
		0.0,
		raw_damage - final_damage
	)

	return DamageResult.new(
		raw_damage,
		total_mitigated,
		final_damage,
		DamageType.Type.PHYSICAL,
		request.is_critical,
		blocked_damage > 0.0
	)


func _calculate_magical_damage(
	request: DamageRequest
) -> DamageResult:
	var raw_damage := (
		request.base_damage
		+ request.attacker_stats.spell_power
	)

	if request.is_critical:
		raw_damage *= DamageConstants.CRITICAL_DAMAGE_MULTIPLIER

	var blocked_damage := minf(
		raw_damage,
		request.blocked_amount
	)

	var damage_after_block := maxf(
		0.0,
		raw_damage - blocked_damage
	)

	var resistance := clampf(
		request.defender_stats.magic_resistance,
		0.0,
		DamageConstants.MAGIC_RESISTANCE_CAP
	)

	var piercing := clampf(
		request.attacker_stats.magic_piercing,
		0.0,
		0.50
	)

	var effective_resistance := (
		resistance * (1.0 - piercing)
	)

	var resistance_mitigation := (
		damage_after_block * effective_resistance
	)

	var final_damage := maxf(
		DamageConstants.MIN_DAMAGE,
		damage_after_block - resistance_mitigation
	)

	var total_mitigated := maxf(
		0.0,
		raw_damage - final_damage
	)

	return DamageResult.new(
		raw_damage,
		total_mitigated,
		final_damage,
		DamageType.Type.MAGICAL,
		request.is_critical,
		blocked_damage > 0.0
	)