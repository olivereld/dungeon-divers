extends SceneTree

# ---------------------------------------------------------------------------
# Test Runner & Stat Calculator Verification Suite
# ---------------------------------------------------------------------------

var _test_count: int = 0
var _assert_count: int = 0
var _failed_asserts: int = 0


func _init() -> void:
	print("\n" + "=".repeat(70))
	print("  SUITE DE PRUEBAS: STAT CALCULATOR (Dungeon Divers)")
	print("=".repeat(70))

	# Pruebas unitarias de reglas de cálculo
	test_nivel_1_atributos_base()
	test_nivel_1_derived_stats()
	test_nivel_30_tanque()
	test_intelligence_controls_spell_power()
	test_wisdom_controls_mana()
	test_dexterity_controls_movement()
	test_all_percentage_caps()
	test_initiative_uses_dexterity_and_level()
	test_strength_controls_equipment_load()
	test_charisma_controls_critical_chance()
	test_attribute_modifiers()
	test_stat_modifiers()
	test_full_pipeline_calculate()

	# Demostración con perfiles y números reales de juego
	showcase_real_archetypes()

	# Resumen final
	print("\n" + "=".repeat(70))
	print("  RESUMEN FINAL DE PRUEBAS")
	print("=".repeat(70))
	print("  Total de pruebas ejecutadas: %d" % _test_count)
	print("  Total de aserciones:         %d" % _assert_count)
	print("  Aserciones exitosas:         %d" % (_assert_count - _failed_asserts))
	print("  Aserciones fallidas:         %d" % _failed_asserts)

	if _failed_asserts == 0:
		print("\n  >>> [EXITO] Todos los tests pasaron y los cálculos son 100% correctos. <<<\n")
		quit(0)
	else:
		push_error("Se encontraron %d aserciones fallidas en la suite." % _failed_asserts)
		print("\n  >>> [ERROR] Fallaron %d aserciones. <<<\n" % _failed_asserts)
		quit(1)


# ---------------------------------------------------------------------------
# Helpers de Aserción y Reporte
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


func _assert_condition(cond: bool, label: String, detail: String = "") -> void:
	_assert_count += 1
	if cond:
		print("  [PASS] %s %s" % [label, detail])
	else:
		_failed_asserts += 1
		push_error("FAIL: %s %s" % [label, detail])
		print("  [FAIL] %s %s" % [label, detail])


# ---------------------------------------------------------------------------
# Casos de Prueba
# ---------------------------------------------------------------------------

func test_nivel_1_atributos_base() -> void:
	_start_test("Nivel 1 con atributos base neutros (10s)")
	var base := AttributeSet.new(10, 10, 10, 10, 10, 10)
	var derived := StatCalculator.calculate_derived_stats(1, base, {})

	_assert_eq(derived.max_hp, 95.0, "HP Nivel 1 (CON 10 * 8 + 1 * 15)")
	_assert_eq(derived.max_mana, 60.0, "Mana Nivel 1 (WIS 10 * 5 + 1 * 10)")
	_assert_eq(derived.max_movement, 3.0, "Movimiento Nivel 1 (Base 3 + floor(DEX 10 / 12))")


func test_nivel_1_derived_stats() -> void:
	_start_test("Nivel 1 estadísticas derivadas completas (Atributos 10s)")
	var base := AttributeSet.new(10, 10, 10, 10, 10, 10)
	var derived := StatCalculator.calculate_derived_stats(1, base, {})

	_assert_eq(derived.physical_power, 21.0, "Poder Físico (STR 10 * 2 + lvl 1)")
	_assert_eq(derived.spell_power, 21.0, "Poder Mágico (INT 10 * 2 + lvl 1)")
	_assert_eq(derived.equip_load_max, 30.0, "Capacidad de Carga (STR 10 * 3)")
	_assert_eq(derived.skill_capacity, 3.0, "Capacidad de Habilidades (2 + floor(INT 10 / 10))")
	_assert_eq(derived.mana_regen, 2.0, "Regeneración de Mana (2 + floor(WIS 10 / 12))")
	_assert_eq(derived.health_regen, 1.0, "Regeneración de Salud (floor(CON 10 / 8))")
	_assert_eq(derived.shield_block_value, 2.0, "Bloqueo con Escudo (floor(STR 10 / 4))")
	_assert_eq(derived.armor_class, 10.0, "Clase de Armadura base (10 + DEX mod 0)")


func test_nivel_30_tanque() -> void:
	_start_test("Nivel 30 Tanque (CON 50, STR 20)")
	var base := AttributeSet.new(20, 15, 50, 12, 14, 10)
	var derived := StatCalculator.calculate_derived_stats(30, base, {})

	_assert_eq(derived.max_hp, 850.0, "HP Nivel 30 CON 50 (50 * 8 + 30 * 15)")
	_assert_eq(derived.health_regen, 6.0, "Regen HP (floor(50 / 8))")
	_assert_approx(derived.physical_resilience, 0.47619, "Resistencia Física (50 / (50 + 30*1.5 + 10))")


func test_intelligence_controls_spell_power() -> void:
	_start_test("Inteligencia escala el Poder Mágico (INT 10 vs INT 30)")
	var low_int := AttributeSet.new(10, 10, 10, 10, 10, 10)
	var high_int := AttributeSet.new(10, 10, 10, 30, 10, 10)

	var low := StatCalculator.calculate_derived_stats(1, low_int, {})
	var high := StatCalculator.calculate_derived_stats(1, high_int, {})

	_assert_condition(high.spell_power > low.spell_power, "INT alta incrementa Spell Power", "(%s > %s)" % [high.spell_power, low.spell_power])
	_assert_eq(high.spell_power, 61.0, "Spell Power con INT 30 (30 * 2 + 1)")
	_assert_eq(high.skill_capacity, 5.0, "Capacidad de Habilidades con INT 30 (2 + floor(30/10))")


func test_wisdom_controls_mana() -> void:
	_start_test("Sabiduría escala el Mana Máximo (WIS 10 vs WIS 30)")
	var low_wis := AttributeSet.new(10, 10, 10, 30, 10, 10)
	var high_wis := AttributeSet.new(10, 10, 10, 10, 30, 10)

	var low := StatCalculator.calculate_derived_stats(1, low_wis, {})
	var high := StatCalculator.calculate_derived_stats(1, high_wis, {})

	_assert_condition(high.max_mana > low.max_mana, "WIS alta incrementa Mana Máximo", "(%s > %s)" % [high.max_mana, low.max_mana])
	_assert_eq(high.max_mana, 160.0, "Mana Máximo con WIS 30 (30 * 5 + 1 * 10)")
	_assert_eq(high.mana_regen, 4.0, "Regen Mana con WIS 30 (2 + floor(30/12))")


func test_dexterity_controls_movement() -> void:
	_start_test("Destreza escala el Movimiento (DEX 48)")
	var base := AttributeSet.new(10, 48, 10, 10, 10, 10)
	var derived := StatCalculator.calculate_derived_stats(1, base, {})

	_assert_eq(derived.max_movement, 7.0, "Movimiento con DEX 48 (3 + floor(48 / 12))")


func test_all_percentage_caps() -> void:
	_start_test("Límites máximos (Caps) con atributos extremos (100,000)")
	var base := AttributeSet.new(100000, 100000, 100000, 100000, 100000, 100000)
	var derived := StatCalculator.calculate_derived_stats(30, base, {})

	_assert_approx(derived.evasion, StatCalculator.EVASION_CAP, "Evasión capped a 50%")
	_assert_approx(derived.accuracy, StatCalculator.ACCURACY_CAP, "Precisión capped a 100%")
	_assert_approx(derived.magic_piercing, StatCalculator.MAGIC_PIERCING_CAP, "Perforación Mágica capped a 50%")
	_assert_approx(derived.physical_resilience, StatCalculator.PHYSICAL_RESILIENCE_CAP, "Resistencia Física capped a 75%")
	_assert_approx(derived.mental_resilience, StatCalculator.MENTAL_RESILIENCE_CAP, "Resistencia Mental capped a 75%")
	_assert_approx(derived.elemental_status_chance, StatCalculator.ELEMENTAL_STATUS_CHANCE_CAP, "Probabilidad de Estado Elemental capped a 75%")
	_assert_approx(derived.vendor_discount, StatCalculator.VENDOR_DISCOUNT_CAP, "Descuento en Tienda capped a 30%")
	_assert_approx(derived.leadership, StatCalculator.LEADERSHIP_CAP, "Liderazgo capped a 50%")
	_assert_approx(derived.critical_chance, StatCalculator.CRITICAL_CHANCE_CAP, "Probabilidad Crítica capped a 50%")


func test_initiative_uses_dexterity_and_level() -> void:
	_start_test("Iniciativa usa Modificador de Destreza y Nivel (Nivel 10, DEX 20)")
	var base := AttributeSet.new(10, 20, 10, 10, 10, 10)
	var derived := StatCalculator.calculate_derived_stats(10, base, {})

	# DEX 20 -> mod D&D = floor((20-10)/2) = +5
	# Iniciativa = mod * 2 + nivel * 0.5 = 5 * 2 + 10 * 0.5 = 15.0
	_assert_eq(derived.dexterity_mod, 5, "Modificador D&D de DEX 20")
	_assert_eq(derived.initiative, 15.0, "Iniciativa calculada (5 * 2 + 10 * 0.5)")


func test_strength_controls_equipment_load() -> void:
	_start_test("Fuerza escala Capacidad de Carga de Equipo (STR 50)")
	var base := AttributeSet.new(50, 10, 10, 10, 10, 10)
	var derived := StatCalculator.calculate_derived_stats(1, base, {})

	_assert_eq(derived.equip_load_max, 150.0, "Capacidad de Carga STR 50 (50 * 3.0)")


func test_charisma_controls_critical_chance() -> void:
	_start_test("Carisma escala Probabilidad Crítica (CHA 40)")
	var base := AttributeSet.new(10, 10, 10, 10, 10, 40)
	var derived := StatCalculator.calculate_derived_stats(1, base, {})

	# 0.05 base + floor(40 / 8) / 100 = 0.05 + 0.05 = 0.10 (10%)
	_assert_approx(derived.critical_chance, 0.10, "Crítico con CHA 40 (5% base + 5%)")


func test_attribute_modifiers() -> void:
	_start_test("Modificadores de Atributos Base (ADD y MULTIPLY)")
	var base := AttributeSet.new(10, 10, 10, 10, 10, 10)

	var mod_add := StatModifier.new(StatModifierType.Type.ADD, 4.0, StatModifierSource.Source.EQUIPMENT, "ring_str")
	var mod_mult := StatModifier.new(StatModifierType.Type.MULTIPLY, 0.50, StatModifierSource.Source.BUFF, "potion_giant")

	var attr_mods := {
		AttributeType.Type.STRENGTH: [mod_add, mod_mult]
	}

	var effective := StatCalculator.calculate_effective_attributes(base, attr_mods)
	# (10 + 4) * (1.0 + 0.50) = 14 * 1.5 = 21.0
	_assert_eq(effective.strength, 21.0, "STR efectiva con +4 y +50% ((10+4)*1.5)")
	_assert_eq(effective.dexterity, 10.0, "DEX permanece sin cambios")


func test_stat_modifiers() -> void:
	_start_test("Modificadores directos a Stats Derivados (ADD a HP y MULTIPLY a Daño Físico)")
	var base := AttributeSet.new(10, 10, 10, 10, 10, 10)

	var hp_mod := StatModifier.new(StatModifierType.Type.ADD, 50.0, StatModifierSource.Source.EQUIPMENT, "amulet_hp")
	var phys_mod := StatModifier.new(StatModifierType.Type.MULTIPLY, 0.20, StatModifierSource.Source.BUFF, "war_cry")

	var stat_mods := {
		StatType.Type.MAX_HP: [hp_mod],
		StatType.Type.PHYSICAL_POWER: [phys_mod]
	}

	var derived := StatCalculator.calculate_derived_stats(1, base, stat_mods)
	# HP base = 95 + 50 = 145.0
	_assert_eq(derived.max_hp, 145.0, "HP con modificador plano +50 (95 + 50)")
	# Physical power = 21.0 * 1.20 = 25.2
	_assert_approx(derived.physical_power, 25.2, "Poder Físico con buff +20% (21 * 1.20)")


func test_full_pipeline_calculate() -> void:
	_start_test("Pipeline Completo: calculate() integrando atributos y stats derivados")
	var base := AttributeSet.new(12, 14, 14, 10, 10, 10)
	var attr_mods := {
		AttributeType.Type.STRENGTH: [StatModifier.new(StatModifierType.Type.ADD, 2.0)] # STR -> 14
	}
	var stat_mods := {
		StatType.Type.ARMOR_CLASS: [StatModifier.new(StatModifierType.Type.ADD, 4.0)] # Escudo CA +4
	}

	var result := StatCalculator.calculate(5, base, attr_mods, stat_mods)
	var effective: AttributeSet = result["effective_attributes"]
	var derived: DerivedStats = result["derived_stats"]

	_assert_eq(effective.strength, 14.0, "Pipeline: STR efectiva (12 + 2)")
	# DEX 14 -> mod +2. CA = 10 + 2 (dex mod) + 4 (escudo) = 16.0
	_assert_eq(derived.armor_class, 16.0, "Pipeline: CA total (10 base + 2 DEX + 4 Escudo)")


# ---------------------------------------------------------------------------
# Demostración Visual de Arquetipos con Valores Reales
# ---------------------------------------------------------------------------

func showcase_real_archetypes() -> void:
	print("\n" + "=".repeat(70))
	print("  MUESTRA DE RESULTADOS REALES: ARQUETIPOS DE PERSONAJES")
	print("=".repeat(70))

	# 1. Guerrero Nivel 1
	var war_attrs := AttributeSet.new(16, 12, 15, 8, 10, 9)
	var war_derived := StatCalculator.calculate_derived_stats(1, war_attrs, {})
	_print_archetype_card("GUERRERO", 1, war_attrs, war_derived)

	# 2. Mago Nivel 1
	var mage_attrs := AttributeSet.new(8, 12, 10, 16, 15, 10)
	var mage_derived := StatCalculator.calculate_derived_stats(1, mage_attrs, {})
	_print_archetype_card("MAGO DE BATALLA", 1, mage_attrs, mage_derived)

	# 3. Pícaro Nivel 1
	var rogue_attrs := AttributeSet.new(10, 16, 12, 10, 10, 14)
	var rogue_derived := StatCalculator.calculate_derived_stats(1, rogue_attrs, {})
	_print_archetype_card("PICARO SOMBRIO", 1, rogue_attrs, rogue_derived)

	# 4. Paladín Nivel 10 Equipado (con modificadores)
	var paladin_base := AttributeSet.new(16, 10, 14, 10, 12, 14)
	var paladin_attr_mods := {
		AttributeType.Type.STRENGTH: [
			StatModifier.new(StatModifierType.Type.ADD, 2.0, StatModifierSource.Source.EQUIPMENT, "guanteletes_ogro")
		]
	}
	var paladin_stat_mods := {
		StatType.Type.ARMOR_CLASS: [
			StatModifier.new(StatModifierType.Type.ADD, 8.0, StatModifierSource.Source.EQUIPMENT, "armadura_placas"),
			StatModifier.new(StatModifierType.Type.ADD, 2.0, StatModifierSource.Source.EQUIPMENT, "escudo_torre")
		],
		StatType.Type.MAX_HP: [
			StatModifier.new(StatModifierType.Type.ADD, 30.0, StatModifierSource.Source.BUFF, "bendicion_divina")
		]
	}
	var paladin_res := StatCalculator.calculate(10, paladin_base, paladin_attr_mods, paladin_stat_mods)
	_print_archetype_card("PALADIN SAGRADO (EQUIPADO + BUFFS)", 10, paladin_res["effective_attributes"], paladin_res["derived_stats"])


func _print_archetype_card(title: String, level: int, base: AttributeSet, d: DerivedStats) -> void:
	print("\n+--------------------------------------------------------------------+")
	print("| %-66s |" % ("ARQUETIPO: %s (Nivel %d)" % [title, level]))
	print("+--------------------------------------------------------------------+")
	print("| Atributos:  STR %-2.0f (%+2d) | DEX %-2.0f (%+2d) | CON %-2.0f (%+2d)             |" % [
		base.strength, d.strength_mod, base.dexterity, d.dexterity_mod, base.constitution, d.constitution_mod
	])
	print("|             INT %-2.0f (%+2d) | WIS %-2.0f (%+2d) | CHA %-2.0f (%+2d)             |" % [
		base.intelligence, d.intelligence_mod, base.wisdom, d.wisdom_mod, base.charisma, d.charisma_mod
	])
	print("|--------------------------------------------------------------------|")
	print("| Combate:    Puntos de Vida (HP): %-5.1f  | Mana: %-5.1f                |" % [d.max_hp, d.max_mana])
	print("|             Clase Armadura (CA): %-5.1f  | Movimiento: %-2.0f casillas     |" % [d.armor_class, d.max_movement])
	print("|             Iniciativa:          %-5.1f  | Capacidad Habilidades: %-2.0f   |" % [d.initiative, d.skill_capacity])
	print("|--------------------------------------------------------------------|")
	print("| Ofensivo:   Poder Fisico:   %-5.1f       | Poder Magico:       %-5.1f   |" % [d.physical_power, d.spell_power])
	print("|             Poder Curativo: %-5.1f       | Precision:          %-4.1f%%  |" % [d.healing_power, d.accuracy * 100.0])
	print("|             Prob. Critico:  %-4.1f%%      | Perforacion Magica: %-4.1f%%  |" % [d.critical_chance * 100.0, d.magic_piercing * 100.0])
	print("|--------------------------------------------------------------------|")
	print("| Defensivo:  Evasion:            %-4.1f%%  | Bloqueo Escudo:     %-4.1f   |" % [d.evasion * 100.0, d.shield_block_value])
	print("|             Resistencia Fisica: %-4.1f%%  | Resistencia Mental: %-4.1f%%  |" % [d.physical_resilience * 100.0, d.mental_resilience * 100.0])
	print("|             Resistencia Magica: %-5.1f   | Estado Elemental:   %-4.1f%%  |" % [d.magic_resistance, d.elemental_status_chance * 100.0])
	print("|--------------------------------------------------------------------|")
	print("| Utilidad:   Carga Maxima:       %-5.1fkg | Regeneracion HP:    %-4.1f/t |" % [d.equip_load_max, d.health_regen])
	print("|             Regeneracion Mana:  %-4.1f/t  | Descuento Tienda:   %-4.1f%%  |" % [d.mana_regen, d.vendor_discount * 100.0])
	print("|             Liderazgo:          %-4.1f%%                                  |" % [d.leadership * 100.0])
	print("+--------------------------------------------------------------------+")