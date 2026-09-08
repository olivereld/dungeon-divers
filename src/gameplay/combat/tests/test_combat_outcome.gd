extends RefCounted


func run() -> void:
	_test_damage_is_applied()
	_test_damage_cannot_kill_beyond_zero()
	_test_miss_does_not_apply_damage()
	_test_attack_without_damage_does_not_change_hp()
	_test_death_is_reported()

func _create_damage_result(
	final_damage: float,
	was_miss: bool = false
) -> DamageResult:
	return DamageResult.new(
		final_damage,
		0.0,
		final_damage,
		DamageType.Type.PHYSICAL,
		false,
		false,
		was_miss
	)

func _test_damage_is_applied() -> void:
	var health := Health.new(100.0)

	var damage_result := _create_damage_result(30.0)

	var attack_result := AttackResult.new(
		CombatTypes.HitOutcome.HIT,
		CombatTypes.CriticalOutcome.NORMAL,
		damage_result
	)

	var outcome := CombatOutcomeResolver.new().apply_attack(
		attack_result,
		health
	)

	_assert(
		outcome.damage_applied == 30.0,
		"Combat outcome should report applied damage."
	)

	_assert(
		health.current_hp == 70.0,
		"Combat outcome should reduce target HP."
	)


func _test_damage_cannot_kill_beyond_zero() -> void:
	var health := Health.new(50.0)

	var damage_result := _create_damage_result(100.0)

	var attack_result := AttackResult.new(
		CombatTypes.HitOutcome.HIT,
		CombatTypes.CriticalOutcome.NORMAL,
		damage_result
	)

	var outcome := CombatOutcomeResolver.new().apply_attack(
		attack_result,
		health
	)

	_assert(
		outcome.damage_applied == 50.0,
		"Applied damage should be limited by remaining HP."
	)

	_assert(
		health.current_hp == 0.0,
		"Target HP should reach zero and never become negative."
	)


func _test_miss_does_not_apply_damage() -> void:
	var health := Health.new(100.0)

	var damage_result := _create_damage_result(
		30.0,
		true
	)

	var attack_result := AttackResult.new(
		CombatTypes.HitOutcome.MISS,
		CombatTypes.CriticalOutcome.NORMAL,
		damage_result
	)

	var outcome := CombatOutcomeResolver.new().apply_attack(
		attack_result,
		health
	)

	_assert(
		outcome.damage_applied == 0.0,
		"Miss should never apply damage."
	)

	_assert(
		health.current_hp == 100.0,
		"Miss should leave target HP unchanged."
	)


func _test_attack_without_damage_does_not_change_hp() -> void:
	var health := Health.new(100.0)

	var attack_result := AttackResult.new(
		CombatTypes.HitOutcome.MISS,
		CombatTypes.CriticalOutcome.NORMAL
	)

	var outcome := CombatOutcomeResolver.new().apply_attack(
		attack_result,
		health
	)

	_assert(
		outcome.damage_applied == 0.0,
		"Attack without damage should apply no damage."
	)

	_assert(
		health.current_hp == 100.0,
		"Attack without damage should leave HP unchanged."
	)


func _test_death_is_reported() -> void:
	var health := Health.new(100.0)

	var damage_result := _create_damage_result(100.0)

	var attack_result := AttackResult.new(
		CombatTypes.HitOutcome.HIT,
		CombatTypes.CriticalOutcome.NORMAL,
		damage_result
	)

	var outcome := CombatOutcomeResolver.new().apply_attack(
		attack_result,
		health
	)

	_assert(
		outcome.killed_target(),
		"Combat outcome should report target death."
	)

	_assert(
		health.is_dead(),
		"Target should be dead after reaching zero HP."
	)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)