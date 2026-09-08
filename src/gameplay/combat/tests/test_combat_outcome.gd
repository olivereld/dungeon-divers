extends SceneTree


var _test_count := 0
var _assert_count := 0
var _failed_asserts := 0


func _init() -> void:
	print("========================================")
	print(" Combat Outcome Tests")
	print("========================================")

	run()

	print("")
	print("Tests: %d" % _test_count)
	print("Assertions: %d" % _assert_count)
	print("Failures: %d" % _failed_asserts)

	if _failed_asserts > 0:
		print("RESULT: FAILED")
		quit(1)
		return

	print("RESULT: PASSED")
	quit(0)


func run() -> void:
	_test_damage_is_applied()
	_test_damage_cannot_kill_beyond_zero()
	_test_miss_does_not_apply_damage()
	_test_attack_without_damage_does_not_change_hp()
	_test_death_is_reported()
	_test_attack_on_already_dead_target_does_not_report_killed()
	_test_miss_on_dead_target_does_not_report_killed()


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
	_test_count += 1
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

	_assert(
		not outcome.killed_target(),
		"Target did not die, killed_target should be false."
	)

	_assert(
		not outcome.is_target_dead(),
		"Target is still alive, is_target_dead should be false."
	)


func _test_damage_cannot_kill_beyond_zero() -> void:
	_test_count += 1
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

	_assert(
		outcome.killed_target(),
		"Attack dealt the lethal blow, killed_target should be true."
	)

	_assert(
		outcome.is_target_dead(),
		"Target is dead, is_target_dead should be true."
	)


func _test_miss_does_not_apply_damage() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	var attack_result := AttackResult.new(
		CombatTypes.HitOutcome.MISS,
		CombatTypes.CriticalOutcome.NORMAL,
		null
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

	_assert(
		not outcome.killed_target(),
		"Miss cannot kill target."
	)

	_assert(
		not outcome.is_target_dead(),
		"Target is not dead after miss."
	)


func _test_attack_without_damage_does_not_change_hp() -> void:
	_test_count += 1
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

	_assert(
		not outcome.killed_target(),
		"Attack without damage cannot kill."
	)


func _test_death_is_reported() -> void:
	_test_count += 1
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
		"Combat outcome should report that this attack killed the target."
	)

	_assert(
		outcome.is_target_dead(),
		"Target should be dead."
	)

	_assert(
		health.is_dead(),
		"Target should be dead after reaching zero HP."
	)


func _test_attack_on_already_dead_target_does_not_report_killed() -> void:
	_test_count += 1
	var health := Health.new(100.0)
	health.apply_damage(100.0)
	assert(health.is_dead())

	var damage_result := _create_damage_result(50.0)

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
		outcome.damage_applied == 0.0,
		"No damage applied because target had 0 HP remaining."
	)

	_assert(
		not outcome.killed_target(),
		"Target was already dead, so this attack did not cause the death."
	)

	_assert(
		outcome.is_target_dead(),
		"Target is currently dead after the attack."
	)


func _test_miss_on_dead_target_does_not_report_killed() -> void:
	_test_count += 1
	var health := Health.new(100.0)
	health.apply_damage(100.0)
	assert(health.is_dead())

	var attack_result := AttackResult.new(
		CombatTypes.HitOutcome.MISS,
		CombatTypes.CriticalOutcome.NORMAL,
		null
	)

	var outcome := CombatOutcomeResolver.new().apply_attack(
		attack_result,
		health
	)

	_assert(
		outcome.damage_applied == 0.0,
		"Miss applies 0 damage."
	)

	_assert(
		not outcome.killed_target(),
		"Miss on already dead target must not report killed_target = true."
	)

	_assert(
		outcome.is_target_dead(),
		"Target is dead."
	)


func _assert(condition: bool, message: String) -> void:
	_assert_count += 1
	if condition:
		print("PASS: " + message)
		return

	_failed_asserts += 1
	push_error("FAIL: " + message)