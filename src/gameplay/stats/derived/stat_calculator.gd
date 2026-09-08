# stat_calculator.gd
# Única pieza del módulo con fórmulas matemáticas. Todo lo demás (AttributeSet,
# DerivedStats, StatModifier) son contenedores sin comportamiento.
#
# Pipeline explícito, tal como en el diagrama:
#   Base Attributes -> Modifiers -> Effective Attributes -> Derived Stats
#
# 100% RefCounted / static, sin depender de Node ni de la escena: se puede
# generar y probar 1000 entidades en headless sin levantar nada visual.
class_name StatCalculator
extends RefCounted

const MITIGATION_CAP := 0.75
const MITIGATION_LEVEL_SCALING := 8.0
const MITIGATION_BASE_OFFSET := 40.0

enum CastingStat { INTELLIGENCE, WISDOM }

# ---------------------------------------------------------------------------
# Utilidades puras
# ---------------------------------------------------------------------------

# Clásico cálculo de modificador de D&D: floor((Atributo - 10) / 2)
static func get_dnd_modifier(score: float) -> int:
	return int(floor((score - 10.0) / 2.0)) if not is_nan(score) else 0

# Combina modificadores aplicando: (Base + Suma_ADD) * (1 + Suma_MULTIPLY)
# Nota de diseño: el stacking de MULTIPLY es multiplicativo entre sí
# (5 x +20% = x2.49, no x2.0). Es intencional; vigilar en itemización endgame.
static func combine_modifiers(base_val: float, modifiers: Array) -> float:
	var total_add: float = 0.0
	var total_mult: float = 1.0

	for mod in modifiers:
		if mod.type == StatModifierType.Type.ADD:
			total_add += mod.value
		elif mod.type == StatModifierType.Type.MULTIPLY:
			total_mult *= (1.0 + mod.value)

	return (base_val + total_add) * total_mult

# Curva de mitigación compartida por armadura física y resistencia mágica.
static func _mitigation_curve(defense_value: float, lvl: float) -> float:
	var raw: float = defense_value / (defense_value + (lvl * MITIGATION_LEVEL_SCALING) + MITIGATION_BASE_OFFSET)
	return clamp(raw, 0.0, MITIGATION_CAP)

# ---------------------------------------------------------------------------
# Paso 1: Base Attributes + Modifiers -> Effective Attributes
# ---------------------------------------------------------------------------

# attribute_modifiers: Dictionary[AttributeType.Type, Array[StatModifier]]
static func calculate_effective_attributes(
	base_attributes: AttributeSet,
	attribute_modifiers: Dictionary
) -> AttributeSet:
	var effective := AttributeSet.new()
	effective.strength = combine_modifiers(base_attributes.strength, attribute_modifiers.get(AttributeType.Type.STRENGTH, []))
	effective.dexterity = combine_modifiers(base_attributes.dexterity, attribute_modifiers.get(AttributeType.Type.DEXTERITY, []))
	effective.constitution = combine_modifiers(base_attributes.constitution, attribute_modifiers.get(AttributeType.Type.CONSTITUTION, []))
	effective.intelligence = combine_modifiers(base_attributes.intelligence, attribute_modifiers.get(AttributeType.Type.INTELLIGENCE, []))
	effective.wisdom = combine_modifiers(base_attributes.wisdom, attribute_modifiers.get(AttributeType.Type.WISDOM, []))
	effective.charisma = combine_modifiers(base_attributes.charisma, attribute_modifiers.get(AttributeType.Type.CHARISMA, []))
	return effective

# ---------------------------------------------------------------------------
# Paso 2: Effective Attributes + Level + Modifiers -> Derived Stats
# ---------------------------------------------------------------------------

# stat_modifiers: Dictionary[StatType.Type, Array[StatModifier]]
static func calculate_derived_stats(
	level: int,
	effective_attributes: AttributeSet,
	stat_modifiers: Dictionary,
	casting_stat: CastingStat = CastingStat.INTELLIGENCE
) -> DerivedStats:
	var lvl: float = float(clamp(level, 1, 30))
	var derived := DerivedStats.new()

	derived.strength_mod = get_dnd_modifier(effective_attributes.strength)
	derived.dexterity_mod = get_dnd_modifier(effective_attributes.dexterity)
	derived.constitution_mod = get_dnd_modifier(effective_attributes.constitution)
	derived.intelligence_mod = get_dnd_modifier(effective_attributes.intelligence)
	derived.wisdom_mod = get_dnd_modifier(effective_attributes.wisdom)
	derived.charisma_mod = get_dnd_modifier(effective_attributes.charisma)

	# Vida
	var raw_max_hp = (effective_attributes.constitution * 8.0) + (lvl * 15.0)
	derived.max_hp = max(10.0, combine_modifiers(raw_max_hp, stat_modifiers.get(StatType.Type.MAX_HP, [])))

	# Maná: usa el atributo de conjuración primario de la clase (INT o WIS)
	var cast_value: float = effective_attributes.wisdom if casting_stat == CastingStat.WISDOM else effective_attributes.intelligence
	var raw_max_mana = (cast_value * 5.0) + (lvl * 10.0)
	derived.max_mana = max(0.0, combine_modifiers(raw_max_mana, stat_modifiers.get(StatType.Type.MAX_MANA, [])))

	# Poder de ataque
	var raw_phys_power = (effective_attributes.strength * 2.0) + lvl
	derived.physical_power = max(1.0, combine_modifiers(raw_phys_power, stat_modifiers.get(StatType.Type.PHYSICAL_POWER, [])))

	var raw_spell_power = (cast_value * 2.0) + lvl
	derived.spell_power = max(1.0, combine_modifiers(raw_spell_power, stat_modifiers.get(StatType.Type.SPELL_POWER, [])))

	# Armadura y mitigación física
	var base_ac = 10.0 + derived.dexterity_mod
	derived.armor_class = max(1.0, combine_modifiers(base_ac, stat_modifiers.get(StatType.Type.ARMOR_CLASS, [])))
	derived.damage_mitigation = _mitigation_curve(derived.armor_class, lvl)

	# Resistencia y mitigación mágica (independiente de la física)
	var base_mr = 10.0 + derived.wisdom_mod
	derived.magic_resist = max(1.0, combine_modifiers(base_mr, stat_modifiers.get(StatType.Type.MAGIC_RESIST, [])))
	derived.magic_mitigation = _mitigation_curve(derived.magic_resist, lvl)

	# Iniciativa
	var raw_init = (derived.dexterity_mod * 1.5) + (derived.wisdom_mod * 0.5) + (lvl * 0.5)
	derived.initiative = combine_modifiers(raw_init, stat_modifiers.get(StatType.Type.INITIATIVE, []))

	# Movimiento por casillas
	var raw_movement = 3.0 + floor(effective_attributes.dexterity / 12.0)
	derived.max_movement = max(1.0, combine_modifiers(raw_movement, stat_modifiers.get(StatType.Type.MAX_MOVEMENT, [])))

	return derived

# ---------------------------------------------------------------------------
# Conveniencia: ejecuta el pipeline completo en un solo paso.
# Devuelve un Dictionary con ambas capas por si la UI necesita mostrar,
# por ejemplo, "STR 15 (18)" — base vs. efectivo — además de los derivados.
# ---------------------------------------------------------------------------
static func calculate(
	level: int,
	base_attributes: AttributeSet,
	attribute_modifiers: Dictionary,
	stat_modifiers: Dictionary,
	casting_stat: CastingStat = CastingStat.INTELLIGENCE
) -> Dictionary:
	var effective := calculate_effective_attributes(base_attributes, attribute_modifiers)
	var derived := calculate_derived_stats(level, effective, stat_modifiers, casting_stat)
	return {
		"effective_attributes": effective,
		"derived_stats": derived,
	}
