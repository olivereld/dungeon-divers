class_name StatCalculator
extends RefCounted

# ---------------------------------------------------------------------------
# Caps
# ---------------------------------------------------------------------------

const EVASION_CAP := 0.50
const ACCURACY_CAP := 1.00
const MAGIC_PIERCING_CAP := 0.50
const PHYSICAL_RESILIENCE_CAP := 0.75
const MENTAL_RESILIENCE_CAP := 0.75
const ELEMENTAL_STATUS_CHANCE_CAP := 0.75
const VENDOR_DISCOUNT_CAP := 0.30
const LEADERSHIP_CAP := 0.50
const CRITICAL_CHANCE_CAP := 0.50
const LOOT_LUCK_MIN := 1.0
const LOOT_LUCK_CAP := 2.0
# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

static func get_dnd_modifier(score: float) -> int:
	if is_nan(score):
		return 0

	return int(floor((score - 10.0) / 2.0))


static func combine_modifiers(
	base_value: float,
	modifiers: Array
) -> float:
	var total_add := 0.0
	var total_multiply := 1.0

	for modifier in modifiers:
		if modifier.type == StatModifierType.Type.ADD:
			total_add += modifier.value

		elif modifier.type == StatModifierType.Type.MULTIPLY:
			total_multiply *= 1.0 + modifier.value

	return (base_value + total_add) * total_multiply


static func _apply_modifiers(
	base_value: float,
	stat_type: StatType.Type,
	stat_modifiers: Dictionary
) -> float:
	return combine_modifiers(
		base_value,
		stat_modifiers.get(stat_type, [])
	)


# ---------------------------------------------------------------------------
# Base Attributes -> Effective Attributes
# ---------------------------------------------------------------------------

static func calculate_effective_attributes(
	base_attributes: AttributeSet,
	attribute_modifiers: Dictionary
) -> AttributeSet:

	var effective := AttributeSet.new()

	effective.strength = combine_modifiers(
		base_attributes.strength,
		attribute_modifiers.get(AttributeType.Type.STRENGTH, [])
	)

	effective.dexterity = combine_modifiers(
		base_attributes.dexterity,
		attribute_modifiers.get(AttributeType.Type.DEXTERITY, [])
	)

	effective.constitution = combine_modifiers(
		base_attributes.constitution,
		attribute_modifiers.get(AttributeType.Type.CONSTITUTION, [])
	)

	effective.intelligence = combine_modifiers(
		base_attributes.intelligence,
		attribute_modifiers.get(AttributeType.Type.INTELLIGENCE, [])
	)

	effective.wisdom = combine_modifiers(
		base_attributes.wisdom,
		attribute_modifiers.get(AttributeType.Type.WISDOM, [])
	)

	effective.charisma = combine_modifiers(
		base_attributes.charisma,
		attribute_modifiers.get(AttributeType.Type.CHARISMA, [])
	)

	return effective


# ---------------------------------------------------------------------------
# Effective Attributes + Level -> Derived Stats
# ---------------------------------------------------------------------------

static func calculate_derived_stats(
	level: int,
	effective_attributes: AttributeSet,
	stat_modifiers: Dictionary
) -> DerivedStats:

	var lvl := float(clamp(level, 1, 30))
	var derived := DerivedStats.new()

	# -----------------------------------------------------------------------
	# Attribute modifiers
	# -----------------------------------------------------------------------

	derived.strength_mod = get_dnd_modifier(
		effective_attributes.strength
	)

	derived.dexterity_mod = get_dnd_modifier(
		effective_attributes.dexterity
	)

	derived.constitution_mod = get_dnd_modifier(
		effective_attributes.constitution
	)

	derived.intelligence_mod = get_dnd_modifier(
		effective_attributes.intelligence
	)

	derived.wisdom_mod = get_dnd_modifier(
		effective_attributes.wisdom
	)

	derived.charisma_mod = get_dnd_modifier(
		effective_attributes.charisma
	)

	# -----------------------------------------------------------------------
	# Constitution
	# -----------------------------------------------------------------------

	var raw_max_hp := (
		effective_attributes.constitution * 8.0
		+ lvl * 15.0
	)

	derived.max_hp = max(
		10.0,
		_apply_modifiers(
			raw_max_hp,
			StatType.Type.MAX_HP,
			stat_modifiers
		)
	)

	var raw_health_regen: float = floor(
		effective_attributes.constitution / 8.0
	)

	derived.health_regen = max(
		0.0,
		_apply_modifiers(
			raw_health_regen,
			StatType.Type.HEALTH_REGEN,
			stat_modifiers
		)
	)

	var raw_physical_resilience := (
		effective_attributes.constitution
		/ (
			effective_attributes.constitution
			+ lvl * 1.5
			+ 10.0
		)
	)

	derived.physical_resilience = clamp(
		_apply_modifiers(
			raw_physical_resilience,
			StatType.Type.PHYSICAL_RESILIENCE,
			stat_modifiers
		),
		0.0,
		PHYSICAL_RESILIENCE_CAP
	)

	# -----------------------------------------------------------------------
	# Strength
	# -----------------------------------------------------------------------

	var raw_physical_power := (
		effective_attributes.strength * 2.0
		+ lvl
	)

	derived.physical_power = max(
		1.0,
		_apply_modifiers(
			raw_physical_power,
			StatType.Type.PHYSICAL_POWER,
			stat_modifiers
		)
	)

	var raw_equip_load := (
		effective_attributes.strength * 3.0
	)

	derived.equip_load_max = max(
		0.0,
		_apply_modifiers(
			raw_equip_load,
			StatType.Type.EQUIP_LOAD_MAX,
			stat_modifiers
		)
	)

	var raw_shield_block: float = floor(
		effective_attributes.strength / 4.0
	)

	derived.shield_block_value = max(
		0.0,
		_apply_modifiers(
			raw_shield_block,
			StatType.Type.SHIELD_BLOCK_VALUE,
			stat_modifiers
		)
	)

	# -----------------------------------------------------------------------
	# Dexterity
	# -----------------------------------------------------------------------

	var raw_armor_class := (
		10.0
		+ derived.dexterity_mod
	)

	derived.armor_class = max(
		1.0,
		_apply_modifiers(
			raw_armor_class,
			StatType.Type.ARMOR_CLASS,
			stat_modifiers
		)
	)

	var raw_evasion := (
		effective_attributes.dexterity
		/ (
			effective_attributes.dexterity
			+ lvl * 4.0
			+ 50.0
		)
	)

	derived.evasion = clamp(
		_apply_modifiers(
			raw_evasion,
			StatType.Type.EVASION,
			stat_modifiers
		),
		0.0,
		EVASION_CAP
	)

	var raw_accuracy: float = (
		0.80
		+ floor(effective_attributes.dexterity / 5.0) / 100.0
	)

	derived.accuracy = clamp(
		_apply_modifiers(
			raw_accuracy,
			StatType.Type.ACCURACY,
			stat_modifiers
		),
		0.0,
		ACCURACY_CAP
	)

	var raw_initiative := (
		derived.dexterity_mod * 2.0
		+ lvl * 0.5
	)

	derived.initiative = _apply_modifiers(
		raw_initiative,
		StatType.Type.INITIATIVE,
		stat_modifiers
	)

	var raw_movement: float = (
		3.0
		+ floor(effective_attributes.dexterity / 12.0)
	)

	derived.max_movement = max(
		1.0,
		_apply_modifiers(
			raw_movement,
			StatType.Type.MAX_MOVEMENT,
			stat_modifiers
		)
	)

	# -----------------------------------------------------------------------
	# Intelligence
	# -----------------------------------------------------------------------

	var raw_spell_power := (
		effective_attributes.intelligence * 2.0
		+ lvl
	)

	derived.spell_power = max(
		1.0,
		_apply_modifiers(
			raw_spell_power,
			StatType.Type.SPELL_POWER,
			stat_modifiers
		)
	)

	var raw_magic_piercing: float = (
		floor(effective_attributes.intelligence / 4.0)
		/ 100.0
	)

	derived.magic_piercing = clamp(
		_apply_modifiers(
			raw_magic_piercing,
			StatType.Type.MAGIC_PIERCING,
			stat_modifiers
		),
		0.0,
		MAGIC_PIERCING_CAP
	)

	var raw_skill_capacity: float = (
		2.0
		+ floor(effective_attributes.intelligence / 10.0)
	)

	derived.skill_capacity = max(
		1.0,
		_apply_modifiers(
			raw_skill_capacity,
			StatType.Type.SKILL_CAPACITY,
			stat_modifiers
		)
	)

	# -----------------------------------------------------------------------
	# Wisdom
	# -----------------------------------------------------------------------

	var raw_max_mana := (
		effective_attributes.wisdom * 5.0
		+ lvl * 10.0
	)

	derived.max_mana = max(
		0.0,
		_apply_modifiers(
			raw_max_mana,
			StatType.Type.MAX_MANA,
			stat_modifiers
		)
	)

	var raw_mana_regen: float = (
		2.0
		+ floor(effective_attributes.wisdom / 12.0)
	)

	derived.mana_regen = max(
		0.0,
		_apply_modifiers(
			raw_mana_regen,
			StatType.Type.MANA_REGEN,
			stat_modifiers
		)
	)

	var raw_healing_power := (
		effective_attributes.wisdom * 2.0
		+ lvl
	)

	derived.healing_power = max(
		0.0,
		_apply_modifiers(
			raw_healing_power,
			StatType.Type.HEALING_POWER,
			stat_modifiers
		)
	)

	var raw_magic_resistance := (
		10.0
		+ derived.wisdom_mod
	)

	derived.magic_resistance = max(
		1.0,
		_apply_modifiers(
			raw_magic_resistance,
			StatType.Type.MAGIC_RESISTANCE,
			stat_modifiers
		)
	)

	var raw_mental_resilience := (
		effective_attributes.wisdom
		/ (
			effective_attributes.wisdom
			+ lvl * 1.5
			+ 10.0
		)
	)

	derived.mental_resilience = clamp(
		_apply_modifiers(
			raw_mental_resilience,
			StatType.Type.MENTAL_RESILIENCE,
			stat_modifiers
		),
		0.0,
		MENTAL_RESILIENCE_CAP
	)

	var raw_elemental_status_chance: float = (
		0.05
		+ floor(effective_attributes.wisdom / 6.0) / 100.0
	)

	derived.elemental_status_chance = clamp(
		_apply_modifiers(
			raw_elemental_status_chance,
			StatType.Type.ELEMENTAL_STATUS_CHANCE,
			stat_modifiers
		),
		0.0,
		ELEMENTAL_STATUS_CHANCE_CAP
	)

	# -----------------------------------------------------------------------
	# Charisma
	# -----------------------------------------------------------------------

	var raw_vendor_discount: float = (
		floor(effective_attributes.charisma / 2.5)
		/ 100.0
	)

	derived.vendor_discount = clamp(
		_apply_modifiers(
			raw_vendor_discount,
			StatType.Type.VENDOR_DISCOUNT,
			stat_modifiers
		),
		0.0,
		VENDOR_DISCOUNT_CAP
	)

	var raw_leadership: float = (
		floor(effective_attributes.charisma / 10.0)
		/ 100.0
	)

	derived.leadership = clamp(
		_apply_modifiers(
			raw_leadership,
			StatType.Type.LEADERSHIP,
			stat_modifiers
		),
		0.0,
		LEADERSHIP_CAP
	)

	var raw_critical_chance: float = (
		0.05
		+ floor(effective_attributes.charisma / 8.0) / 100.0
	)

	derived.critical_chance = clamp(
		_apply_modifiers(
			raw_critical_chance,
			StatType.Type.CRITICAL_CHANCE,
			stat_modifiers
		),
		0.0,
		CRITICAL_CHANCE_CAP
	)

	var raw_loot_luck: float = (
		1.0
		+ floor(effective_attributes.charisma / 10.0) * 0.05
	)

	derived.loot_luck = clamp(
		_apply_modifiers(
			raw_loot_luck,
			StatType.Type.LOOT_LUCK,
			stat_modifiers
		),
		LOOT_LUCK_MIN,
		LOOT_LUCK_CAP
	)

	return derived


# ---------------------------------------------------------------------------
# Full pipeline
# ---------------------------------------------------------------------------

static func calculate(
	level: int,
	base_attributes: AttributeSet,
	attribute_modifiers: Dictionary,
	stat_modifiers: Dictionary
) -> Dictionary:

	var effective := calculate_effective_attributes(
		base_attributes,
		attribute_modifiers
	)

	var derived := calculate_derived_stats(
		level,
		effective,
		stat_modifiers
	)

	return {
		"effective_attributes": effective,
		"derived_stats": derived,
	}