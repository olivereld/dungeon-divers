extends SceneTree

# ---------------------------------------------------------------------------
# Test Runner & Combat Core Verification Suite
# ---------------------------------------------------------------------------

var _test_count: int = 0
var _assert_count: int = 0
var _failed_asserts: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  SUITE DE PRUEBAS: COMBAT CORE (Dungeon Divers)")
	print("=".repeat(70))

	test_guaranteed_hit()
	test_guaranteed_miss()
	test_guaranteed_critical()
	test_guaranteed_normal()
	test_critical_guarantees_hit_ignoring_evasion()
	test_clamping_and_boundaries()
	test_probabilistic_distribution()

	showcase_combat_scenarios()

	print("\n" + "=".repeat(70))
	print("  RESUMEN FINAL DE PRUEBAS DE COMBATE")
	print("=".repeat(70))
	print("  Total de pruebas ejecutadas: %d" % _test_count)
	print("  Total de aserciones:         %d" % _assert_count)
	print("  Aserciones exitosas:         %d" % (_assert_count - _failed_asserts))
	print("  Aserciones fallidas:         %d" % _failed_asserts)

	if _failed_asserts == 0:
		print("\n  >>> [EXITO] Combat core tests passed. Todos los cálculos son 100% correctos. <<<\n")
		quit(0)
	else:
		push_error("Se encontraron %d aserciones fallidas en la suite de combate." % _failed_asserts)
		print("\n  >>> [ERROR] Fallaron %d aserciones. <<<\n" % _failed_asserts)
		quit(1)


func _start_test(test_name: String) -> void:
	_test_count += 1
	print("\n[%d] %s" % [_test_count, test_name])


func _assert_eq(actual: Variant, expected: Variant, label: String) -> void:
	_assert_count += 1
	if actual == expected:
		print("  [PASS] %s = %s" % [label, str(actual)])
	else:
		_failed_asserts += 1
		push_error("FAIL: %s | Esperado: %s | Obtenido: %s" % [label, str(expected), str(actual)])
		print("  [FAIL] %s | Esperado: %s | Obtenido: %s" % [label, str(expected), str(actual)])


func _assert_true(condition: bool, label: String, detail: String = "") -> void:
	_assert_count += 1
	if condition:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failed_asserts += 1
		push_error("FAIL: %s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


# ---------------------------------------------------------------------------
# Implementación de los Tests Requeridos
# ---------------------------------------------------------------------------

func test_guaranteed_hit() -> void:
	_start_test("Impacto Garantizado (Guaranteed Hit: Accuracy 1.0, Evasion 0.0)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var hit_resolver := HitResolver.new(rng)
	var critical_resolver := CriticalResolver.new(rng)
	var combat_resolver := CombatResolver.new(hit_resolver, critical_resolver, BlockResolver.new(), DamageCalculator.new())

	var attacker := DerivedStats.new()
	attacker.accuracy = 1.0
	attacker.critical_chance = 0.0

	var defender := DerivedStats.new()
	defender.evasion = 0.0

	var attack_data := AttackData.new(10.0, DamageType.Type.PHYSICAL)
	var request := AttackRequest.new(attacker, defender, attack_data)

	# Direct HitResolver check
	var direct_outcome := hit_resolver.resolve(1.0, 0.0)
	_assert_eq(direct_outcome, CombatTypes.HitOutcome.HIT, "HitResolver.resolve(1.0, 0.0) produce HIT")

	# CombatResolver 50-sample consistency check
	var all_hit := true
	for i in range(50):
		var res := combat_resolver.resolve_attack(request)
		if not res.did_hit():
			all_hit = false
			break

	_assert_true(all_hit, "50 ataques consecutivos resultan en HIT (100% garantizado)")


func test_guaranteed_miss() -> void:
	_start_test("Fallo Garantizado (Guaranteed Miss: Accuracy 0.0 o Evasion >= Accuracy)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var hit_resolver := HitResolver.new(rng)
	var critical_resolver := CriticalResolver.new(rng)
	var combat_resolver := CombatResolver.new(hit_resolver, critical_resolver, BlockResolver.new(), DamageCalculator.new())

	# Caso 1: Accuracy 0.0 vs Evasion 0.0
	var attacker_zero := DerivedStats.new()
	attacker_zero.accuracy = 0.0
	attacker_zero.critical_chance = 0.0

	var defender_zero := DerivedStats.new()
	defender_zero.evasion = 0.0

	var attack_data := AttackData.new(10.0, DamageType.Type.PHYSICAL)
	var req_zero := AttackRequest.new(attacker_zero, defender_zero, attack_data)
	var res_zero := combat_resolver.resolve_attack(req_zero)
	_assert_eq(res_zero.hit_outcome, CombatTypes.HitOutcome.MISS, "Accuracy 0.0 produce MISS")
	_assert_true(not res_zero.did_hit(), "did_hit() retorna false")

	# Caso 2: Evasion superior a Accuracy (Accuracy 0.5, Evasion 0.8)
	var attacker_mid := DerivedStats.new()
	attacker_mid.accuracy = 0.5

	var defender_high := DerivedStats.new()
	defender_high.evasion = 0.8

	var req_evasion := AttackRequest.new(attacker_mid, defender_high, attack_data)
	var all_miss := true
	for i in range(50):
		var res := combat_resolver.resolve_attack(req_evasion)
		if res.did_hit():
			all_miss = false
			break

	_assert_true(all_miss, "Evasion superior (0.8 > 0.5) produce 50/50 MISS garantizados")


func test_guaranteed_critical() -> void:
	_start_test("Golpe Crítico Garantizado (Guaranteed Critical: Hit + Crit Chance 1.0)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var hit_resolver := HitResolver.new(rng)
	var critical_resolver := CriticalResolver.new(rng)
	var combat_resolver := CombatResolver.new(hit_resolver, critical_resolver, BlockResolver.new(), DamageCalculator.new())

	# Direct CriticalResolver check
	var direct_crit := critical_resolver.resolve(1.0)
	_assert_eq(direct_crit, CombatTypes.CriticalOutcome.CRITICAL, "CriticalResolver.resolve(1.0) produce CRITICAL")

	# CombatResolver attack resolution
	var attacker := DerivedStats.new()
	attacker.accuracy = 1.0
	attacker.critical_chance = 1.0

	var defender := DerivedStats.new()
	defender.evasion = 0.0

	var attack_data := AttackData.new(10.0, DamageType.Type.PHYSICAL)
	var request := AttackRequest.new(attacker, defender, attack_data)

	var all_crit := true
	for i in range(50):
		var res := combat_resolver.resolve_attack(request)
		if not res.did_hit() or not res.was_critical():
			all_crit = false
			break

	_assert_true(all_crit, "50 ataques consecutivos resultan en HIT + CRITICAL garantizado")


func test_guaranteed_normal() -> void:
	_start_test("Golpe Normal Garantizado (Guaranteed Normal: Hit + Crit Chance 0.0)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var hit_resolver := HitResolver.new(rng)
	var critical_resolver := CriticalResolver.new(rng)
	var combat_resolver := CombatResolver.new(hit_resolver, critical_resolver, BlockResolver.new(), DamageCalculator.new())

	# Direct CriticalResolver check
	var direct_normal := critical_resolver.resolve(0.0)
	_assert_eq(direct_normal, CombatTypes.CriticalOutcome.NORMAL, "CriticalResolver.resolve(0.0) produce NORMAL")

	# CombatResolver attack resolution
	var attacker := DerivedStats.new()
	attacker.accuracy = 1.0
	attacker.critical_chance = 0.0

	var defender := DerivedStats.new()
	defender.evasion = 0.0

	var attack_data := AttackData.new(10.0, DamageType.Type.PHYSICAL)
	var request := AttackRequest.new(attacker, defender, attack_data)

	var all_normal := true
	for i in range(50):
		var res := combat_resolver.resolve_attack(request)
		if not res.did_hit() or res.was_critical():
			all_normal = false
			break

	_assert_true(all_normal, "50 ataques consecutivos resultan en HIT + NORMAL (sin crítico)")


func test_critical_guarantees_hit_ignoring_evasion() -> void:
	_start_test("Regla de Oro: Un Golpe Crítico SIEMPRE acierta e ignora la evasión")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var hit_resolver := HitResolver.new(rng)
	var critical_resolver := CriticalResolver.new(rng)
	var combat_resolver := CombatResolver.new(hit_resolver, critical_resolver, BlockResolver.new(), DamageCalculator.new())

	# Atacante con 0% de puntería vs Enemigo con 100% de evasión
	# PERO con 100% de probabilidad crítica
	var attacker := DerivedStats.new()
	attacker.accuracy = 0.0
	attacker.critical_chance = 1.0

	var defender := DerivedStats.new()
	defender.evasion = 1.0

	var attack_data := AttackData.new(10.0, DamageType.Type.PHYSICAL)
	var request := AttackRequest.new(attacker, defender, attack_data)
	var res := combat_resolver.resolve_attack(request)

	_assert_eq(res.hit_outcome, CombatTypes.HitOutcome.HIT, "El golpe crítico impacta aunque la evasión sea 100% y puntería 0%")
	_assert_eq(res.critical_outcome, CombatTypes.CriticalOutcome.CRITICAL, "El golpe es confirmado como CRITICAL")
	_assert_true(res.did_hit(), "did_hit() retorna true")
	_assert_true(res.was_critical(), "was_critical() retorna true")


func test_clamping_and_boundaries() -> void:
	_start_test("Validación de Clamping en límites fuera de rango (< 0.0 y > 1.0)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 100

	var hit_resolver := HitResolver.new(rng)
	var critical_resolver := CriticalResolver.new(rng)

	# Accuracy 2.5 debe clamp a 1.0; Evasion -0.5 debe clamp a 0.0 -> Hit chance 1.0
	var out_hit := hit_resolver.resolve(2.5, -0.5)
	_assert_eq(out_hit, CombatTypes.HitOutcome.HIT, "HitResolver clampa accuracy > 1.0 y evasion < 0.0")

	# Accuracy -1.0 clamp a 0.0 -> Hit chance 0.0 -> MISS
	var out_miss := hit_resolver.resolve(-1.0, 0.0)
	_assert_eq(out_miss, CombatTypes.HitOutcome.MISS, "HitResolver clampa accuracy < 0.0 a 0.0")

	# Crit chance 3.0 clampa a 1.0 -> CRITICAL
	var out_crit := critical_resolver.resolve(3.0)
	_assert_eq(out_crit, CombatTypes.CriticalOutcome.CRITICAL, "CriticalResolver clampa crit > 1.0 a 1.0")

	# Crit chance -2.0 clampa a 0.0 -> NORMAL
	var out_norm := critical_resolver.resolve(-2.0)
	_assert_eq(out_norm, CombatTypes.CriticalOutcome.NORMAL, "CriticalResolver clampa crit < 0.0 a 0.0")


func test_probabilistic_distribution() -> void:
	_start_test("Simulación Probabilística (1000 tiradas: 50% hit normal y 20% crit inicial)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9999

	var hit_resolver := HitResolver.new(rng)
	var critical_resolver := CriticalResolver.new(rng)
	var combat_resolver := CombatResolver.new(hit_resolver, critical_resolver, BlockResolver.new(), DamageCalculator.new())

	var attacker := DerivedStats.new()
	attacker.accuracy = 0.80
	attacker.critical_chance = 0.20

	var defender := DerivedStats.new()
	defender.evasion = 0.30 # Puntería neta = 0.80 - 0.30 = 0.50 (50%)

	var attack_data := AttackData.new(10.0, DamageType.Type.PHYSICAL)
	var request := AttackRequest.new(attacker, defender, attack_data)

	var hits: int = 0
	var crits: int = 0
	var samples: int = 1000

	for i in range(samples):
		var res := combat_resolver.resolve_attack(request)
		if res.did_hit():
			hits += 1
			if res.was_critical():
				crits += 1

	var hit_pct := float(hits) / float(samples) * 100.0
	var crit_of_hits_pct := float(crits) / float(hits) * 100.0 if hits > 0 else 0.0

	# Matemática con Crítico Primero (acierto garantizado):
	# P(Crit) = 20% (acierta automático)
	# P(Normal Hit) = (1 - 0.20) * 0.50 = 40%
	# P(Total Hit) = 20% + 40% = 60%
	# P(Crit / Hits) = 20% / 60% = 33.3%
	print("  Muestra de %d ataques (Crit primero -> Acierto garantizado):" % samples)
	print("  - Impactos totales (HIT): %d (%.1f%%) | Esperado: ~60.0%% (20%% crit + 40%% normal)" % [hits, hit_pct])
	print("  - Críticos del total:     %d (%.1f%%) | Esperado: ~20.0%%" % [crits, float(crits) / float(samples) * 100.0])
	print("  - Críticos s/ impactos:   %.1f%%        | Esperado: ~33.3%%" % crit_of_hits_pct)

	_assert_true(hit_pct >= 55.0 and hit_pct <= 65.0, "Distribución de Hit total dentro del rango esperado 55%-65%", "(%.1f%%)" % hit_pct)
	_assert_true(crit_of_hits_pct >= 28.0 and crit_of_hits_pct <= 38.0, "Proporción de Críticos sobre impactos dentro del rango 28%-38%", "(%.1f%%)" % crit_of_hits_pct)


# ---------------------------------------------------------------------------
# Demostración Visual de Escenarios de Combate
# ---------------------------------------------------------------------------

func showcase_combat_scenarios() -> void:
	print("\n" + "=".repeat(70))
	print("  ESCENARIOS DE COMBATE SIMULADOS")
	print("=".repeat(70))

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var combat_resolver := CombatResolver.new(HitResolver.new(rng), CriticalResolver.new(rng), BlockResolver.new(), DamageCalculator.new())

	_simulate_and_print("Pícaro Ágil ataca a Guerrero Pesado", 0.90, 0.35, 0.25, combat_resolver)
	_simulate_and_print("Guerrero ataca a Monstruo Fantasma (Evasión Alta)", 0.70, 0.65, 0.05, combat_resolver)
	_simulate_and_print("Asesino con Golpe Crítico Mortal", 1.00, 0.10, 0.80, combat_resolver)


func _simulate_and_print(
	scenario_name: String,
	accuracy: float,
	evasion: float,
	critical_chance: float,
	resolver: CombatResolver
) -> void:
	var atk := DerivedStats.new()
	atk.accuracy = accuracy
	atk.critical_chance = critical_chance

	var def := DerivedStats.new()
	def.evasion = evasion

	var attack_data := AttackData.new(10.0, DamageType.Type.PHYSICAL)
	var req := AttackRequest.new(atk, def, attack_data)
	var res := resolver.resolve_attack(req)

	var hit_chance_pct := clampf(accuracy - evasion, 0.0, 1.0) * 100.0
	var outcome_str := ""
	if not res.did_hit():
		outcome_str = "FALLO (MISS)"
	elif res.was_critical():
		outcome_str = "IMPACTO CRITICO (CRITICAL HIT!)"
	else:
		outcome_str = "IMPACTO NORMAL (NORMAL HIT)"

	print("+--------------------------------------------------------------------+")
	print("| %-66s |" % scenario_name)
	print("+--------------------------------------------------------------------+")
	print("| Parámetros: Precisión: %-4.1f%% | Evasión: %-4.1f%% | Prob. Impacto: %-4.1f%% |" % [accuracy * 100.0, evasion * 100.0, hit_chance_pct])
	print("|             Prob. Crítico: %-4.1f%%                                   |" % [critical_chance * 100.0])
	print("| Resultado:  %-54s |" % outcome_str)
	print("+--------------------------------------------------------------------+\n")