# derived_stats.gd
# Solo almacena resultados. NUNCA calcula nada — eso es trabajo exclusivo
# de StatCalculator. Si algún día ves una fórmula dentro de este archivo,
# es una señal de que se está rompiendo la separación de responsabilidades.
class_name DerivedStats
extends RefCounted

var max_hp: float = 0.0
var max_mana: float = 0.0
var physical_power: float = 0.0
var spell_power: float = 0.0
var armor_class: float = 0.0
var damage_mitigation: float = 0.0
var magic_resist: float = 0.0
var magic_mitigation: float = 0.0
var initiative: float = 0.0
var max_movement: float = 0.0

# Modificadores de atributo "cacheados" — útiles para UI y para otras
# fórmulas (iniciativa, movimiento), pero no son stats de combate en sí.
var strength_mod: int = 0
var dexterity_mod: int = 0
var constitution_mod: int = 0
var intelligence_mod: int = 0
var wisdom_mod: int = 0
var charisma_mod: int = 0

func get_value(stat: StatType.Type) -> float:
	match stat:
		StatType.Type.MAX_HP: return max_hp
		StatType.Type.MAX_MANA: return max_mana
		StatType.Type.PHYSICAL_POWER: return physical_power
		StatType.Type.SPELL_POWER: return spell_power
		StatType.Type.ARMOR_CLASS: return armor_class
		StatType.Type.DAMAGE_MITIGATION: return damage_mitigation
		StatType.Type.MAGIC_RESIST: return magic_resist
		StatType.Type.MAGIC_MITIGATION: return magic_mitigation
		StatType.Type.INITIATIVE: return initiative
		StatType.Type.MAX_MOVEMENT: return max_movement
	push_warning("DerivedStats: stat desconocido %s" % stat)
	return 0.0
