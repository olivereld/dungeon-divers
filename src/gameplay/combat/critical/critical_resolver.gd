class_name CriticalResolver
extends RefCounted


var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator) -> void:
	assert(p_rng != null)

	rng = p_rng


func resolve(critical_chance: float) -> CombatTypes.CriticalOutcome:
	critical_chance = clampf(
		critical_chance,
		0.0,
		1.0
	)

	var roll := rng.randf()

	if roll < critical_chance:
		return CombatTypes.CriticalOutcome.CRITICAL

	return CombatTypes.CriticalOutcome.NORMAL