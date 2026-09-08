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

	# 1. Regla de juego: Un impacto crítico NUNCA falla (acierto automático).
	# Se evalúa primero el crítico. Si se activa, impacta de forma garantizada.
	var critical_outcome := critical_resolver.resolve(
		request.attacker_stats.critical_chance
	)

	if critical_outcome == CombatTypes.CriticalOutcome.CRITICAL:
		return AttackResult.new(
			CombatTypes.HitOutcome.HIT,
			CombatTypes.CriticalOutcome.CRITICAL
		)

	# 2. Si no fue crítico, se resuelve la puntería vs evasión habitual.
	var hit_outcome := hit_resolver.resolve(
		request.attacker_stats.accuracy,
		request.defender_stats.evasion
	)

	return AttackResult.new(
		hit_outcome,
		CombatTypes.CriticalOutcome.NORMAL
	)