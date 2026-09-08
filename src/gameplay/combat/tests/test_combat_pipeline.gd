extends SceneTree

var _test_count := 0
var _assert_count := 0
var _failed_asserts := 0


func _init() -> void:
	print("========================================")
	print(" Combat Pipeline Tests")
	print("========================================")

	_run_tests()

	print("")
	print("Tests: %d" % _test_count)
	print("Assertions: %d" % _assert_count)
	print("Failures: %d" % _failed_asserts)

	if _failed_asserts > 0:
		print("RESULT: FAILED")
		quit(1)
	else:
		print("RESULT: PASSED")
		quit(0)


func _run_tests() -> void:
	_test_normal_physical_attack()
	_test_critical_attack_ignores_hit_chance()
	_test_missed_attack_has_no_damage()
	_test_magical_attack_uses_magic_resistance()
	_test_magical_attack_uses_magic_piercing()
	_test_critical_multiplier_is_applied()
	_test_attack_does_not_mutate_stats()


func _test_normal_physical_attack() -> void:
	_test_count += 1

	var attacker := _create_stats(
		100.0, # STR
		100.0, # DEX
		10.0,  # CON
		10.0,  # INT
		10.0,  # WIS
		1.0    # CHA
	)

	var defender := _create_stats()

	var attack_data := AttackData.new(
		20.0,
		DamageType.Type.PHYSICAL
	)

	var resolver := _create_guaranteed_resolver()

	var request := AttackRequest.new(
		attacker,
		defender,
		attack_data
	)

	var result := resolver.resolve_attack(request)

	_assert(
		result.did_hit(),
		"Normal physical attack should hit."
	)

	_assert(
		not result.was_critical(),
		"Attack should not be critical."
	)

	_assert(
		result.has_damage(),
		"Successful attack should contain DamageResult."
	)

	_assert(
		result.damage_result.damage_type == DamageType.Type.PHYSICAL,
		"Damage type should be physical."
	)

	_assert(
		result.damage_result.raw_damage > 0.0,
		"Raw damage should be greater than zero."
	)


func _test_critical_attack_ignores_hit_chance() -> void:
	_test_count += 1

	var attacker := _create_stats(
		10.0,
		10.0,
		10.0,
		10.0,
		10.0,
		1000.0
	)

	var defender := _create_stats(
		10.0,
		100.0,
		10.0,
		10.0,
		10.0,
		10.0
	)

	attacker.critical_chance = 1.0
	attacker.accuracy = 0.0
	defender.evasion = 1.0

	var attack_data := AttackData.new(
		10.0,
		DamageType.Type.PHYSICAL
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var resolver := CombatResolver.new(
		HitResolver.new(rng),
		CriticalResolver.new(rng),
		DamageCalculator.new()
	)

	var result := resolver.resolve_attack(
		AttackRequest.new(
			attacker,
			defender,
			attack_data
		)
	)

	_assert(
		result.did_hit(),
		"Critical attack must hit."
	)

	_assert(
		result.was_critical(),
		"Attack must be critical."
	)

	_assert(
		result.has_damage(),
		"Critical hit must contain damage."
	)


func _test_missed_attack_has_no_damage() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.accuracy = 0.0
	attacker.critical_chance = 0.0
	defender.evasion = 1.0

	var attack_data := AttackData.new(
		50.0,
		DamageType.Type.PHYSICAL
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	var resolver := CombatResolver.new(
		HitResolver.new(rng),
		CriticalResolver.new(rng),
		DamageCalculator.new()
	)

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
		"Missed attack must not contain DamageResult."
	)


func _test_magical_attack_uses_magic_resistance() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.spell_power = 100.0
	defender.magic_resistance = 0.50
	attacker.magic_piercing = 0.0

	var attack_data := AttackData.new(
		100.0,
		DamageType.Type.MAGICAL
	)

	var calculator := DamageCalculator.new()

	var result := calculator.calculate(
		DamageRequest.new(
			attacker,
			defender,
			attack_data.base_damage,
			attack_data.damage_type
		)
	)

	_assert(
		result.raw_damage == 200.0,
		"Magical raw damage should include spell power."
	)

	_assert(
		result.mitigated_damage == 100.0,
		"Magic resistance should mitigate 50%."
	)

	_assert(
		result.final_damage == 100.0,
		"Final magical damage should be 100."
	)


func _test_magical_attack_uses_magic_piercing() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.spell_power = 100.0
	attacker.magic_piercing = 0.50
	defender.magic_resistance = 0.50

	var attack_data := AttackData.new(
		100.0,
		DamageType.Type.MAGICAL
	)

	var result := DamageCalculator.new().calculate(
		DamageRequest.new(
			attacker,
			defender,
			attack_data.base_damage,
			attack_data.damage_type
		)
	)

	_assert(
		result.final_damage == 150.0,
		"50% piercing against 50% resistance should leave 25% mitigation."
	)


func _test_critical_multiplier_is_applied() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.physical_power = 100.0
	defender.physical_resilience = 0.0

	var attack_data := AttackData.new(
		100.0,
		DamageType.Type.PHYSICAL
	)

	var result := DamageCalculator.new().calculate(
		DamageRequest.new(
			attacker,
			defender,
			attack_data.base_damage,
			attack_data.damage_type,
			true
		)
	)

	_assert(
		result.raw_damage == 300.0,
		"Critical damage should apply 1.5x multiplier."
	)

	_assert(
		result.final_damage == 300.0,
		"With zero resilience, final damage equals raw damage."
	)

	_assert(
		result.was_critical,
		"DamageResult must preserve critical state."
	)


func _test_attack_does_not_mutate_stats() -> void:
	_test_count += 1

	var attacker := _create_stats()
	var defender := _create_stats()

	attacker.accuracy = 1.0
	attacker.critical_chance = 0.0
	defender.evasion = 0.0

	var original_power := attacker.physical_power
	var original_hp := defender.max_hp
	var original_resilience := defender.physical_resilience

	var attack_data := AttackData.new(
		25.0,
		DamageType.Type.PHYSICAL
	)

	var resolver := _create_guaranteed_resolver()

	resolver.resolve_attack(
		AttackRequest.new(
			attacker,
			defender,
			attack_data
		)
	)

	_assert(
		attacker.physical_power == original_power,
		"Attacker stats must not mutate."
	)

	_assert(
		defender.max_hp == original_hp,
		"Defender max HP must not mutate."
	)

	_assert(
		defender.physical_resilience == original_resilience,
		"Defender resilience must not mutate."
	)


func _create_guaranteed_resolver() -> CombatResolver:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	return CombatResolver.new(
		HitResolver.new(rng),
		CriticalResolver.new(rng),
		DamageCalculator.new()
	)


func _create_stats(
	p_strength: float = 10.0,
	p_dexterity: float = 10.0,
	p_constitution: float = 10.0,
	p_intelligence: float = 10.0,
	p_wisdom: float = 10.0,
	p_charisma: float = 10.0
) -> DerivedStats:
	var stats := DerivedStats.new()

	stats.max_hp = 100.0
	stats.physical_power = p_strength * 2.0
	stats.spell_power = p_intelligence * 2.0

	stats.accuracy = 1.0
	stats.evasion = 0.0
	stats.critical_chance = 0.0

	stats.physical_resilience = 0.0
	stats.magic_resistance = 0.0
	stats.magic_piercing = 0.0

	return stats


func _assert(
	condition: bool,
	message: String
) -> void:
	_assert_count += 1

	if not condition:
		_failed_asserts += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)