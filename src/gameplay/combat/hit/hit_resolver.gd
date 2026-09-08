class_name HitResolver
extends RefCounted


var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator) -> void:
	assert(p_rng != null)

	rng = p_rng


func resolve(
	accuracy: float,
	evasion: float
) -> CombatTypes.HitOutcome:
	accuracy = clampf(accuracy, 0.0, 1.0)
	evasion = clampf(evasion, 0.0, 1.0)

	var hit_chance := clampf(
		accuracy - evasion,
		0.0,
		1.0
	)

	var roll := rng.randf()

	if roll < hit_chance:
		return CombatTypes.HitOutcome.HIT

	return CombatTypes.HitOutcome.MISS