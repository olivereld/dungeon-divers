extends SceneTree

# ---------------------------------------------------------------------------
# Test Runner & Damage System Verification Suite
# ---------------------------------------------------------------------------

var _test_count: int = 0
var _assert_count: int = 0
var _failed_asserts: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  SUITE DE PRUEBAS: SISTEMA DE DAÑO (Dungeon Divers)")
	print("=".repeat(70))

	# Pruebas de daño físico
	test_physical_damage_basic()
	test_physical_damage_with_resilience()
	test_physical_damage_critical()
	test_physical_damage_resilience_cap()
	test_physical_damage_minimum_guaranteed()

	# Pruebas de daño mágico
	test_magical_damage_basic()
	test_magical_damage_with_resistance_and_piercing()
	test_magical_damage_critical_with_piercing()
	test_magical_damage_caps()
	test_magical_damage_minimum_guaranteed()

	# Escenarios de demostración con números reales
	showcase_damage_scenarios()

	print("\n" + "=".repeat(70))
	print("  RESUMEN FINAL DE PRUEBAS DE DAÑO")
	print("=".repeat(70))
	print("  Total de pruebas ejecutadas: %d" % _test_count)
	print("  Total de aserciones:         %d" % _assert_count)
	print("  Aserciones exitosas:         %d" % (_assert_count - _failed_asserts))
	print("  Aserciones fallidas:         %d" % _failed_asserts)

	if _failed_asserts == 0:
		print("\n  >>> [EXITO] Todos los tests de daño pasaron y los cálculos son 100% correctos. <<<\n")
		quit(0)
	else:
		push_error("Se encontraron %d aserciones fallidas en la suite de daño." % _failed_asserts)
		print("\n  >>> [ERROR] Fallaron %d aserciones. <<<\n" % _failed_asserts)
		quit(1)


# ---------------------------------------------------------------------------
# Helpers de Aserción
# ---------------------------------------------------------------------------

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


func _assert_approx(actual: float, expected: float, label: String, tolerance: float = 0.0001) -> void:
	_assert_count += 1
	if is_equal_approx(actual, expected) or abs(actual - expected) <= tolerance:
		print("  [PASS] %s = %s (esperado ~%s)" % [label, str(snapped(actual, 0.0001)), str(expected)])
	else:
		_failed_asserts += 1
		push_error("FAIL: %s | Esperado: ~%s | Obtenido: %s" % [label, str(expected), str(actual)])
		print("  [FAIL] %s | Esperado: ~%s | Obtenido: %s" % [label, str(expected), str(actual)])


func _assert_true(condition: bool, label: String, detail: String = "") -> void:
	_assert_count += 1
	if condition:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failed_asserts += 1
		push_error("FAIL: %s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


# ---------------------------------------------------------------------------
# Casos de Prueba: Daño Físico
# ---------------------------------------------------------------------------

func test_physical_damage_basic() -> void:
	_start_test("Daño Físico Básico sin mitigación (Base + Physical Power)")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.physical_power = 20.0

	var defender := DerivedStats.new()
	defender.physical_resilience = 0.0

	# 10 base + 20 power = 30 bruto, 0 mitigado = 30 final
	var req := DamageRequest.new(attacker, defender, 10.0, DamageType.Type.PHYSICAL, false)
	var res := calculator.calculate(req)

	_assert_approx(res.raw_damage, 30.0, "Daño bruto (10 base + 20 power)")
	_assert_approx(res.mitigated_damage, 0.0, "Daño mitigado (0% resiliencia)")
	_assert_approx(res.final_damage, 30.0, "Daño final")
	_assert_eq(res.damage_type, DamageType.Type.PHYSICAL, "Tipo de daño PHYSICAL")
	_assert_true(not res.was_critical, "was_critical es false")


func test_physical_damage_with_resilience() -> void:
	_start_test("Daño Físico mitigado por Resiliencia Física (25% resiliencia)")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.physical_power = 30.0

	var defender := DerivedStats.new()
	defender.physical_resilience = 0.25 # 25%

	# 10 base + 30 power = 40 bruto
	# Mitigado = 40 * 0.25 = 10
	# Final = 40 - 10 = 30
	var req := DamageRequest.new(attacker, defender, 10.0, DamageType.Type.PHYSICAL, false)
	var res := calculator.calculate(req)

	_assert_approx(res.raw_damage, 40.0, "Daño bruto (10 + 30)")
	_assert_approx(res.mitigated_damage, 10.0, "Daño mitigado (40 * 0.25)")
	_assert_approx(res.final_damage, 30.0, "Daño final (40 - 10)")


func test_physical_damage_critical() -> void:
	_start_test("Daño Físico Crítico (Multiplicador x1.5)")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.physical_power = 20.0

	var defender := DerivedStats.new()
	defender.physical_resilience = 0.20 # 20%

	# (10 base + 20 power) * 1.5 = 45.0 bruto
	# Mitigado = 45 * 0.20 = 9.0
	# Final = 45 - 9 = 36.0
	var req := DamageRequest.new(attacker, defender, 10.0, DamageType.Type.PHYSICAL, true)
	var res := calculator.calculate(req)

	_assert_approx(res.raw_damage, 45.0, "Daño bruto con crítico x1.5 ((10+20)*1.5)")
	_assert_approx(res.mitigated_damage, 9.0, "Daño mitigado (45 * 0.20)")
	_assert_approx(res.final_damage, 36.0, "Daño final crítico (45 - 9)")
	_assert_true(res.was_critical, "was_critical es true")


func test_physical_damage_resilience_cap() -> void:
	_start_test("Límite máximo de Resiliencia Física (Cap del 75%)")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.physical_power = 90.0

	var defender := DerivedStats.new()
	defender.physical_resilience = 0.95 # 95% -> debe limitarse a 75%

	# 10 base + 90 power = 100 bruto
	# Resiliencia limitada a 0.75
	# Mitigado = 100 * 0.75 = 75
	# Final = 100 - 75 = 25
	var req := DamageRequest.new(attacker, defender, 10.0, DamageType.Type.PHYSICAL, false)
	var res := calculator.calculate(req)

	_assert_approx(res.raw_damage, 100.0, "Daño bruto (10 + 90)")
	_assert_approx(res.mitigated_damage, 75.0, "Daño mitigado limitado al cap del 75% (100 * 0.75)")
	_assert_approx(res.final_damage, 25.0, "Daño final (100 - 75)")


func test_physical_damage_minimum_guaranteed() -> void:
	_start_test("Garantía de Daño Mínimo (MIN_DAMAGE = 1.0)")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.physical_power = 0.0

	var defender := DerivedStats.new()
	defender.physical_resilience = 0.75

	# Base 0 + power 0 = 0 bruto
	# Final debe ser al menos 1.0
	var req := DamageRequest.new(attacker, defender, 0.0, DamageType.Type.PHYSICAL, false)
	var res := calculator.calculate(req)

	_assert_approx(res.final_damage, DamageConstants.MIN_DAMAGE, "Daño final respeta MIN_DAMAGE (1.0)")


# ---------------------------------------------------------------------------
# Casos de Prueba: Daño Mágico
# ---------------------------------------------------------------------------

func test_magical_damage_basic() -> void:
	_start_test("Daño Mágico Básico sin resistencia (Base + Spell Power)")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.spell_power = 25.0
	attacker.magic_piercing = 0.0

	var defender := DerivedStats.new()
	defender.mental_resilience = 0.0

	# 15 base + 25 spell power = 40 bruto
	var req := DamageRequest.new(attacker, defender, 15.0, DamageType.Type.MAGICAL, false)
	var res := calculator.calculate(req)

	_assert_approx(res.raw_damage, 40.0, "Daño bruto mágico (15 + 25)")
	_assert_approx(res.mitigated_damage, 0.0, "Daño mágico mitigado")
	_assert_approx(res.final_damage, 40.0, "Daño final mágico")
	_assert_eq(res.damage_type, DamageType.Type.MAGICAL, "Tipo de daño MAGICAL")


func test_magical_damage_with_resistance_and_piercing() -> void:
	_start_test("Daño Mágico con Resistencia Mental y Perforación Mágica")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.spell_power = 50.0
	attacker.magic_piercing = 0.25 # 25% perforación

	var defender := DerivedStats.new()
	defender.mental_resilience = 0.40 # 40% resistencia

	# Daño bruto = 50 base + 50 power = 100
	# Resistencia efectiva = 0.40 * (1.0 - 0.25) = 0.40 * 0.75 = 0.30 (30%)
	# Mitigado = 100 * 0.30 = 30
	# Final = 100 - 30 = 70
	var req := DamageRequest.new(attacker, defender, 50.0, DamageType.Type.MAGICAL, false)
	var res := calculator.calculate(req)

	_assert_approx(res.raw_damage, 100.0, "Daño bruto mágico (50 + 50)")
	_assert_approx(res.mitigated_damage, 30.0, "Daño mitigado con perforación (100 * 0.30)")
	_assert_approx(res.final_damage, 70.0, "Daño final mágico (100 - 30)")


func test_magical_damage_critical_with_piercing() -> void:
	_start_test("Daño Mágico Crítico con Perforación")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.spell_power = 30.0
	attacker.magic_piercing = 0.20 # 20%

	var defender := DerivedStats.new()
	defender.mental_resilience = 0.50 # 50%

	# (10 base + 30 power) * 1.5 = 60 bruto
	# Resistencia efectiva = 0.50 * (1.0 - 0.20) = 0.40 (40%)
	# Mitigado = 60 * 0.40 = 24
	# Final = 60 - 24 = 36
	var req := DamageRequest.new(attacker, defender, 10.0, DamageType.Type.MAGICAL, true)
	var res := calculator.calculate(req)

	_assert_approx(res.raw_damage, 60.0, "Daño bruto mágico crítico ((10+30)*1.5)")
	_assert_approx(res.mitigated_damage, 24.0, "Daño mitigado (60 * 0.40)")
	_assert_approx(res.final_damage, 36.0, "Daño final mágico crítico (60 - 24)")
	_assert_true(res.was_critical, "was_critical es true")


func test_magical_damage_caps() -> void:
	_start_test("Límites máximos en Daño Mágico (Resistencia Cap 75%, Piercing Cap 50%)")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.spell_power = 80.0
	attacker.magic_piercing = 0.80 # Debe limitarse a 0.50

	var defender := DerivedStats.new()
	defender.mental_resilience = 0.90 # Debe limitarse a 0.75

	# Daño bruto = 20 base + 80 power = 100
	# Resistencia clamped = 0.75
	# Piercing clamped = 0.50
	# Resistencia efectiva = 0.75 * (1.0 - 0.50) = 0.375 (37.5%)
	# Mitigado = 100 * 0.375 = 37.5
	# Final = 100 - 37.5 = 62.5
	var req := DamageRequest.new(attacker, defender, 20.0, DamageType.Type.MAGICAL, false)
	var res := calculator.calculate(req)

	_assert_approx(res.raw_damage, 100.0, "Daño bruto mágico (20 + 80)")
	_assert_approx(res.mitigated_damage, 37.5, "Daño mitigado aplicando ambos caps (100 * 0.375)")
	_assert_approx(res.final_damage, 62.5, "Daño final aplicando caps (100 - 37.5)")


func test_magical_damage_minimum_guaranteed() -> void:
	_start_test("Garantía de Daño Mágico Mínimo (MIN_DAMAGE = 1.0)")
	var calculator := DamageCalculator.new()

	var attacker := DerivedStats.new()
	attacker.spell_power = 0.0

	var defender := DerivedStats.new()
	defender.mental_resilience = 0.75

	var req := DamageRequest.new(attacker, defender, 0.0, DamageType.Type.MAGICAL, false)
	var res := calculator.calculate(req)

	_assert_approx(res.final_damage, DamageConstants.MIN_DAMAGE, "Daño mágico final respeta MIN_DAMAGE (1.0)")


# ---------------------------------------------------------------------------
# Demostración Visual de Escenarios de Daño
# ---------------------------------------------------------------------------

func showcase_damage_scenarios() -> void:
	print("\n" + "=".repeat(70))
	print("  ESCENARIOS DE DAÑO REAL CALCULADOS")
	print("=".repeat(70))

	var calc := DamageCalculator.new()

	# 1. Guerrero con Espadón ataca a Orco Acorazado
	var war := DerivedStats.new()
	war.physical_power = 33.0
	var orc := DerivedStats.new()
	orc.physical_resilience = 0.30
	var req_war := DamageRequest.new(war, orc, 15.0, DamageType.Type.PHYSICAL, false)
	_print_damage_card("Guerrero ataca a Orco Acorazado con Espadón", req_war, calc.calculate(req_war))

	# 2. Pícaro asesta Golpe Crítico con Daga
	var rogue := DerivedStats.new()
	rogue.physical_power = 21.0
	var goblin := DerivedStats.new()
	goblin.physical_resilience = 0.10
	var req_rogue := DamageRequest.new(rogue, goblin, 12.0, DamageType.Type.PHYSICAL, true)
	_print_damage_card("Pícaro asesta Golpe Crítico con Daga", req_rogue, calc.calculate(req_rogue))

	# 3. Mago lanza Bola de Fuego con Perforación
	var mage := DerivedStats.new()
	mage.spell_power = 33.0
	mage.magic_piercing = 0.20
	var golem := DerivedStats.new()
	golem.mental_resilience = 0.40
	var req_mage := DamageRequest.new(mage, golem, 25.0, DamageType.Type.MAGICAL, false)
	_print_damage_card("Mago lanza Bola de Fuego a Gólem", req_mage, calc.calculate(req_mage))

	# 4. Hechicero lanza Rayo Desintegrador Crítico
	var sorc := DerivedStats.new()
	sorc.spell_power = 45.0
	sorc.magic_piercing = 0.35
	var boss := DerivedStats.new()
	boss.mental_resilience = 0.60
	var req_sorc := DamageRequest.new(sorc, boss, 30.0, DamageType.Type.MAGICAL, true)
	_print_damage_card("Hechicero lanza Rayo Desintegrador Crítico a Jefe", req_sorc, calc.calculate(req_sorc))


func _print_damage_card(title: String, req: DamageRequest, res: DamageResult) -> void:
	var type_name := "FISICO" if res.damage_type == DamageType.Type.PHYSICAL else "MAGICO"
	var crit_str := "SI (x1.5)" if res.was_critical else "NO"

	print("+--------------------------------------------------------------------+")
	print("| %-66s |" % title)
	print("+--------------------------------------------------------------------+")
	print("| Entrada:    Tipo: %-7s | Daño Base: %-5.1f | Crítico: %-15s |" % [type_name, req.base_damage, crit_str])
	if res.damage_type == DamageType.Type.PHYSICAL:
		print("| Atacante:   Poder Físico: %-5.1f                                      |" % req.attacker_stats.physical_power)
		print("| Defensor:   Resiliencia Física: %-5.1f%%                               |" % (req.defender_stats.physical_resilience * 100.0))
	else:
		print("| Atacante:   Poder Mágico: %-5.1f | Perforación Mágica: %-5.1f%%           |" % [req.attacker_stats.spell_power, req.attacker_stats.magic_piercing * 100.0])
		print("| Defensor:   Resistencia Mental: %-5.1f%%                               |" % (req.defender_stats.mental_resilience * 100.0))
	print("|--------------------------------------------------------------------|")
	print("| Resultados: Daño Bruto:     %-5.1f                                      |" % res.raw_damage)
	print("|             Daño Mitigado:  %-5.1f                                      |" % res.mitigated_damage)
	print("|             DAÑO FINAL:     %-5.1f                                      |" % res.final_damage)
	print("+--------------------------------------------------------------------+\n")
