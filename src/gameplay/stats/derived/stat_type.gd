# stat_type.gd
class_name StatType
extends RefCounted

enum Type {
	# --- Constitution ---
	MAX_HP,
	HEALTH_REGEN,
	PHYSICAL_RESILIENCE,     # % resistencia a estados físicos (veneno, sangrado, aturdimiento)

	# --- Strength ---
	PHYSICAL_POWER,
	EQUIP_LOAD_MAX,          # kg que puede cargar antes de penalización
	SHIELD_BLOCK_VALUE,      # mitigación plana al bloquear con escudo

	# --- Dexterity ---
	ARMOR_CLASS,
	DAMAGE_MITIGATION,       # % reducción de daño físico (de Armor Class)
	EVASION,                 # % de esquivar ataques físicos
	ACCURACY,                # % de acertar ataques físicos
	INITIATIVE,
	MAX_MOVEMENT,

	# --- Intelligence ---
	SPELL_POWER,
	MAGIC_PIERCING,          # % de resistencia mágica enemiga ignorada
	SKILL_CAPACITY,          # ranuras de habilidad activa

	# --- Wisdom ---
	MAX_MANA,
	MANA_REGEN,
	HEALING_POWER,
	MAGIC_RESIST,
	MAGIC_MITIGATION,        # % reducción de daño mágico (de Magic Resist)
	MENTAL_RESILIENCE,       # % resistencia a estados mentales (miedo, silencio, confusión)
	ELEMENTAL_STATUS_CHANCE, # % de aplicar quemadura/congelación/etc al golpear

	# --- Charisma ---
	VENDOR_DISCOUNT,         # % de descuento con mercaderes
	LEADERSHIP,              # % de buff pasivo a aliados/invocaciones adyacentes
	CRITICAL_CHANCE,         # % de golpe crítico
}