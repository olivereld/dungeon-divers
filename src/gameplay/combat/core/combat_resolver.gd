class_name CombatResolver
extends RefCounted


var hit_resolver: HitResolver
var critical_resolver: CriticalResolver
var block_resolver: BlockResolver
var damage_calculator: DamageCalculator


func _init(
	p_hit_resolver: HitResolver,
	p_critical_resolver: CriticalResolver,
	p_block_resolver: BlockResolver,
	p_damage_calculator: DamageCalculator
) -> void:
	assert(p_hit_resolver != null)
	assert(p_critical_resolver != null)
	assert(p_block_resolver != null)
	assert(p_damage_calculator != null)

	hit_resolver = p_hit_resolver
	critical_resolver = p_critical_resolver
	block_resolver = p_block_resolver
	damage_calculator = p_damage_calculator


func resolve_attack(request: AttackRequest) -> AttackResult:
	assert(request != null)
	assert(request.attacker_stats != null)
	assert(request.defender_stats != null)
	assert(request.attack_data != null)

	var critical_outcome := critical_resolver.resolve(
		request.attacker_stats.critical_chance
	)

	if critical_outcome == CombatTypes.CriticalOutcome.CRITICAL:
		return _resolve_critical_attack(request)

	var hit_outcome := hit_resolver.resolve(
		request.attacker_stats.accuracy,
		request.defender_stats.evasion
	)

	if hit_outcome == CombatTypes.HitOutcome.MISS:
		return AttackResult.new(
			CombatTypes.HitOutcome.MISS,
			CombatTypes.CriticalOutcome.NORMAL
		)

	return _resolve_normal_hit(request)


func _resolve_critical_attack(
	request: AttackRequest
) -> AttackResult:
	var blocked_amount := block_resolver.resolve(
		request.defender_stats
	)

	var damage_result := _calculate_damage(
		request,
		true,
		blocked_amount
	)

	return AttackResult.new(
		CombatTypes.HitOutcome.HIT,
		CombatTypes.CriticalOutcome.CRITICAL,
		damage_result
	)


func _resolve_normal_hit(
	request: AttackRequest
) -> AttackResult:
	var blocked_amount := block_resolver.resolve(
		request.defender_stats
	)

	var damage_result := _calculate_damage(
		request,
		false,
		blocked_amount
	)

	return AttackResult.new(
		CombatTypes.HitOutcome.HIT,
		CombatTypes.CriticalOutcome.NORMAL,
		damage_result
	)


func _calculate_damage(
	request: AttackRequest,
	is_critical: bool,
	blocked_amount: float
) -> DamageResult:
	var damage_request := DamageRequest.new(
		request.attacker_stats,
		request.defender_stats,
		request.attack_data.base_damage,
		request.attack_data.damage_type,
		is_critical,
		blocked_amount
	)

	return damage_calculator.calculate(
		damage_request
	)