class_name DamageCalculator
extends RefCounted

func calculate(
	request: DamageRequest
) -> DamageResult:

	match request.damage_type:

		DamageType.Type.PHYSICAL:
			return _calculate_physical_damage(request)

		DamageType.Type.MAGICAL:
			return _calculate_magical_damage(request)

	push_error("Unknown damage type.")

	return DamageResult.new(
		0,
		0,
		0,
		request.damage_type,
		false
	)

func _calculate_physical_damage(
	request: DamageRequest
) -> DamageResult:

	var damage := (
		request.base_damage
		+ request.attacker_stats.physical_power
	)

	if request.is_critical:
		damage *= DamageConstants.CRITICAL_DAMAGE_MULTIPLIER

	var resilience := clampf(
		request.defender_stats.physical_resilience,
		0.0,
		DamageConstants.PHYSICAL_RESILIENCE_CAP
	)

	var mitigated := damage * resilience

	var final_damage := maxf(
		DamageConstants.MIN_DAMAGE,
		damage - mitigated
	)

	return DamageResult.new(
		damage,
		mitigated,
		final_damage,
		DamageType.Type.PHYSICAL,
		request.is_critical
	)

func _calculate_magical_damage(
	request: DamageRequest
) -> DamageResult:

	var damage := (
		request.base_damage
		+ request.attacker_stats.spell_power
	)

	if request.is_critical:
		damage *= DamageConstants.CRITICAL_DAMAGE_MULTIPLIER

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

	var effective_resistance := resistance * (1.0 - piercing)

	var mitigated := damage * effective_resistance

	var final_damage := maxf(
		DamageConstants.MIN_DAMAGE,
		damage - mitigated
	)

	return DamageResult.new(
		damage,
		mitigated,
		final_damage,
		DamageType.Type.MAGICAL,
		request.is_critical
	)