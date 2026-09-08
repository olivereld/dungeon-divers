class_name CombatResolver
extends RefCounted


var hit_resolver: HitResolver
var critical_resolver: CriticalResolver


func _init(
	p_hit_resolver: HitResolver,
	p_critical_resolver: CriticalResolver
) -> void:
	assert(p_hit_resolver != null)
	assert(p_critical_resolver != null)

	hit_resolver = p_hit_resolver
	critical_resolver = p_critical_resolver


func resolve_attack(request: AttackRequest) -> AttackResult:
	assert(request != null)
	assert(request.attacker_stats != null)
	assert(request.defender_stats != null)

	var hit_outcome := hit_resolver.resolve(
		request.attacker_stats.accuracy,
		request.defender_stats.evasion
	)

	if hit_outcome == CombatTypes.HitOutcome.MISS:
		return AttackResult.new(
			hit_outcome,
			CombatTypes.CriticalOutcome.NORMAL
		)

	var critical_outcome := critical_resolver.resolve(
		request.attacker_stats.critical_chance
	)

	return AttackResult.new(
		hit_outcome,
		critical_outcome
	)