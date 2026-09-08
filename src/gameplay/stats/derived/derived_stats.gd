class_name DerivedStats
extends RefCounted

# ---------------------------------------------------------------------------
# Constitution
# ---------------------------------------------------------------------------

var max_hp: float = 0.0
var health_regen: float = 0.0
var physical_resilience: float = 0.0

# ---------------------------------------------------------------------------
# Strength
# ---------------------------------------------------------------------------

var physical_power: float = 0.0
var equip_load_max: float = 0.0
var shield_block_value: float = 0.0

# ---------------------------------------------------------------------------
# Dexterity
# ---------------------------------------------------------------------------

var armor_class: float = 0.0
var evasion: float = 0.0
var accuracy: float = 0.0
var initiative: float = 0.0
var max_movement: float = 0.0

# ---------------------------------------------------------------------------
# Intelligence
# ---------------------------------------------------------------------------

var spell_power: float = 0.0
var magic_piercing: float = 0.0
var skill_capacity: float = 0.0

# ---------------------------------------------------------------------------
# Wisdom
# ---------------------------------------------------------------------------

var max_mana: float = 0.0
var mana_regen: float = 0.0
var healing_power: float = 0.0
var magic_resistance: float = 0.0
var mental_resilience: float = 0.0
var elemental_status_chance: float = 0.0

# ---------------------------------------------------------------------------
# Charisma
# ---------------------------------------------------------------------------

var vendor_discount: float = 0.0
var leadership: float = 0.0
var critical_chance: float = 0.0

# ---------------------------------------------------------------------------
# Attribute modifiers
# ---------------------------------------------------------------------------

var strength_mod: int = 0
var dexterity_mod: int = 0
var constitution_mod: int = 0
var intelligence_mod: int = 0
var wisdom_mod: int = 0
var charisma_mod: int = 0


func get_value(stat: StatType.Type) -> float:
	match stat:
		StatType.Type.MAX_HP: return max_hp
		StatType.Type.HEALTH_REGEN: return health_regen
		StatType.Type.PHYSICAL_RESILIENCE: return physical_resilience

		StatType.Type.PHYSICAL_POWER: return physical_power
		StatType.Type.EQUIP_LOAD_MAX: return equip_load_max
		StatType.Type.SHIELD_BLOCK_VALUE: return shield_block_value

		StatType.Type.ARMOR_CLASS: return armor_class
		StatType.Type.EVASION: return evasion
		StatType.Type.ACCURACY: return accuracy
		StatType.Type.INITIATIVE: return initiative
		StatType.Type.MAX_MOVEMENT: return max_movement

		StatType.Type.SPELL_POWER: return spell_power
		StatType.Type.MAGIC_PIERCING: return magic_piercing
		StatType.Type.SKILL_CAPACITY: return skill_capacity

		StatType.Type.MAX_MANA: return max_mana
		StatType.Type.MANA_REGEN: return mana_regen
		StatType.Type.HEALING_POWER: return healing_power
		StatType.Type.MAGIC_RESISTANCE: return magic_resistance
		StatType.Type.MENTAL_RESILIENCE: return mental_resilience
		StatType.Type.ELEMENTAL_STATUS_CHANCE: return elemental_status_chance

		StatType.Type.VENDOR_DISCOUNT: return vendor_discount
		StatType.Type.LEADERSHIP: return leadership
		StatType.Type.CRITICAL_CHANCE: return critical_chance

		_:
			push_warning("DerivedStats: stat desconocido %s" % stat)
			return 0.0