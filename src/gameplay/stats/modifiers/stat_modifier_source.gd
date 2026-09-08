# stat_modifier_source.gd
# Saber DE DÓNDE viene un modificador es lo que te permite, por ejemplo,
# quitar "todos los modificadores que vinieron del anillo X" sin tener que
# recalcular todo desde cero, o mostrar en la UI "+2 STR (Anillo de Ogro)".
class_name StatModifierSource
extends RefCounted

enum Source {
	EQUIPMENT,
	BUFF,
	DEBUFF,
	CURSE,
	PASSIVE_SKILL,
	AURA,
	CONSUMABLE,
	OTHER,
}
