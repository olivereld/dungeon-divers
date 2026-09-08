extends SceneTree


var _test_count := 0
var _assert_count := 0
var _failed_asserts := 0


func _init() -> void:
	print("========================================")
	print(" Combat Defense Tests")
	print("========================================")

	_run_tests()

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


func _run_tests() -> void:
	_test_block_resolver_without_shield()
	_test_block_resolver_with_shield()
	_test_block_reduces_physical_damage()
	_test_block_occurs_before_resilience()
	_test_block_cannot_exceed_damage()
	_test_critical_attack_can_be_blocked()
	_test_magical_damage_can_be_blocked()
	_test_miss_does_not_resolve_block()


func _test_block_resolver_without_shield() -> void:
	_test_count += 1

	var defender := _create_stats()
	defender.shield_block_value = 0.0

	var result := BlockResolver.new().resolve(defender)

	_assert(
		not result.blocked,
		"Defender without block value should not block."
	)

	_assert(
		result.blocked_amount == 0.0,
		"Block amount should be zero."
	)


func _test_block_resolver_with_shield() -> void:
	_test_count += 1

	var defender := _create_stats()
	defender.shield_block_value = 10.0

	var result := BlockResolver.new().resolve(defender)

	_assert(
		result.blocked,
		"Defender with block value should block."
	)

	_assert(
		result.blocked_amount == 10.0,
		"Block amount should equal shield block value."
	)


func _test_block_reduces_physical_damage() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.physical_power = 20.0
	defender.physical_resilience = 0.0
	defender.shield_block_value = 10.0

	var attack_data := AttackData.new(
		30.0,
		DamageType.Type.PHYSICAL
	)

	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(
		AttackRequest.new(
			attacker,
			defender,
			attack_data
		)
	)

	_assert(
		result.did_hit(),
		"Attack should hit."
	)

	_assert(
		result.has_damage(),
		"Hit should contain damage."
	)

	_assert(
		result.damage_result.raw_damage == 50.0,
		"Raw damage should be 50."
	)

	_assert(
		result.damage_result.final_damage == 40.0,
		"Block should reduce 50 damage to 40."
	)

	_assert(
		result.damage_result.was_blocked,
		"DamageResult should report blocked damage."
	)


func _test_block_occurs_before_resilience() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.physical_power = 0.0

	defender.shield_block_value = 20.0
	defender.physical_resilience = 0.50

	var attack_data := AttackData.new(
		100.0,
		DamageType.Type.PHYSICAL
	)

	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(
		AttackRequest.new(
			attacker,
			defender,
			attack_data
		)
	)

	_assert(
		result.damage_result.raw_damage == 100.0,
		"Raw damage should be 100."
	)

	_assert(
		result.damage_result.final_damage == 40.0,
		"Block must occur before physical resilience."
	)

	_assert(
		result.damage_result.mitigated_damage == 60.0,
		"Total mitigation should be 60."
	)


func _test_block_cannot_exceed_damage() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.physical_power = 0.0
	defender.shield_block_value = 1000.0
	defender.physical_resilience = 0.0

	var attack_data := AttackData.new(
		25.0,
		DamageType.Type.PHYSICAL
	)

	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(
		AttackRequest.new(
			attacker,
			defender,
			attack_data
		)
	)

	_assert(
		result.damage_result.final_damage == DamageConstants.MIN_DAMAGE,
		"Block must never reduce damage below minimum damage."
	)


func _test_critical_attack_can_be_blocked() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.accuracy = 0.0
	attacker.critical_chance = 1.0
	attacker.physical_power = 100.0

	defender.evasion = 1.0
	defender.shield_block_value = 50.0
	defender.physical_resilience = 0.0

	var attack_data := AttackData.new(
		100.0,
		DamageType.Type.PHYSICAL
	)

	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(
		AttackRequest.new(
			attacker,
			defender,
			attack_data
		)
	)

	_assert(
		result.did_hit(),
		"Critical attack must still hit."
	)

	_assert(
		result.was_critical(),
		"Attack must be critical."
	)

	_assert(
		result.damage_result.was_blocked,
		"Critical attack can be blocked."
	)

	_assert(
		result.damage_result.final_damage == 250.0,
		"Critical damage should be reduced by block."
	)


func _test_magical_damage_can_be_blocked() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.accuracy = 1.0
	attacker.critical_chance = 0.0
	attacker.spell_power = 100.0
	attacker.magic_piercing = 0.0

	defender.evasion = 0.0
	defender.shield_block_value = 20.0
	defender.magic_resistance = 0.0

	var attack_data := AttackData.new(
		100.0,
		DamageType.Type.MAGICAL
	)

	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(
		AttackRequest.new(
			attacker,
			defender,
			attack_data
		)
	)

	_assert(
		result.damage_result.raw_damage == 200.0,
		"Raw magical damage should be 200."
	)

	_assert(
		result.damage_result.final_damage == 180.0,
		"Block should reduce magical damage."
	)

	_assert(
		result.damage_result.was_blocked,
		"Magical damage should report block."
	)


func _test_miss_does_not_resolve_block() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.accuracy = 0.0
	attacker.critical_chance = 0.0

	defender.evasion = 1.0
	defender.shield_block_value = 100.0

	var attack_data := AttackData.new(
		50.0,
		DamageType.Type.PHYSICAL
	)

	var resolver := _create_resolver(12345)

	var result := resolver.resolve_attack(
		AttackRequest.new(
			attacker,
			defender,
			attack_data
		)
	)

	_assert(
		result.hit_outcome == CombatTypes.HitOutcome.MISS,
		"Attack should miss."
	)

	_assert(
		not result.has_damage(),
		"Missed attack should not produce damage."
	)


func _create_resolver(seed: int) -> CombatResolver:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed

	return CombatResolver.new(
		HitResolver.new(rng),
		CriticalResolver.new(rng),
		BlockResolver.new(),
		DamageCalculator.new()
	)


func _create_stats() -> DerivedStats:
	var stats := DerivedStats.new()

	stats.accuracy = 1.0
	stats.evasion = 0.0
	stats.critical_chance = 0.0

	stats.physical_power = 10.0
	stats.spell_power = 10.0

	stats.physical_resilience = 0.0
	stats.magic_resistance = 0.0
	stats.magic_piercing = 0.0

	stats.shield_block_value = 0.0

	return stats


func _assert(
	condition: bool,
	message: String
) -> void:
	_assert_count += 1

	if condition:
		print("PASS: " + message)
		return

	_failed_asserts += 1
	push_error("FAIL: " + message)