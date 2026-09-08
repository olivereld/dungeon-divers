extends SceneTree


var _test_count := 0
var _assert_count := 0
var _failed_asserts := 0


func _init() -> void:
	print("========================================")
	print(" Health Tests")
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
	_test_initializes_at_max_hp()
	_test_damage_reduces_hp()
	_test_damage_cannot_reduce_below_zero()
	_test_zero_damage_does_nothing()
	_test_heal_increases_hp()
	_test_heal_cannot_exceed_max_hp()
	_test_dead_when_hp_reaches_zero()
	_test_alive_when_hp_is_above_zero()
	_test_health_ratio()


func _test_initializes_at_max_hp() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	_assert(
		health.current_hp == 100.0,
		"Health should initialize current HP at max HP."
	)


func _test_damage_reduces_hp() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	var applied := health.apply_damage(30.0)

	_assert(
		applied == 30.0,
		"Applied damage should equal requested damage when enough HP exists."
	)

	_assert(
		health.current_hp == 70.0,
		"Damage should reduce current HP."
	)


func _test_damage_cannot_reduce_below_zero() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	var applied := health.apply_damage(150.0)

	_assert(
		applied == 100.0,
		"Applied damage should be capped by remaining HP."
	)

	_assert(
		health.current_hp == 0.0,
		"Current HP should never become negative."
	)


func _test_zero_damage_does_nothing() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	var applied := health.apply_damage(0.0)

	_assert(
		applied == 0.0,
		"Zero damage should apply nothing."
	)

	_assert(
		health.current_hp == 100.0,
		"Zero damage should not change HP."
	)


func _test_heal_increases_hp() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	health.apply_damage(40.0)

	var healed := health.heal(20.0)

	_assert(
		healed == 20.0,
		"Healing should return the amount actually restored."
	)

	_assert(
		health.current_hp == 80.0,
		"Healing should restore current HP."
	)


func _test_heal_cannot_exceed_max_hp() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	health.apply_damage(20.0)

	var healed := health.heal(50.0)

	_assert(
		healed == 20.0,
		"Healing should be capped by missing HP."
	)

	_assert(
		health.current_hp == 100.0,
		"Current HP should never exceed max HP."
	)


func _test_dead_when_hp_reaches_zero() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	health.apply_damage(100.0)

	_assert(
		health.is_dead(),
		"Health should report dead when HP reaches zero."
	)


func _test_alive_when_hp_is_above_zero() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	health.apply_damage(99.0)

	_assert(
		health.is_alive(),
		"Health should report alive while HP is above zero."
	)


func _test_health_ratio() -> void:
	_test_count += 1
	var health := Health.new(100.0)

	health.apply_damage(25.0)

	_assert(
		is_equal_approx(
			health.get_health_ratio(),
			0.75
		),
		"Health ratio should represent current HP divided by max HP."
	)


func _assert(condition: bool, message: String) -> void:
	_assert_count += 1
	if condition:
		print("PASS: " + message)
		return

	_failed_asserts += 1
	push_error("FAIL: " + message)