# species_id.gd
# Taxonomía biológica/racial: "¿Qué especie es?"
# Nunca disposición ni comportamiento — eso vive en Faction/Disposition.
# Útil para afinidad cultural, habilidades raciales, lore, apariencia.
#
# NOTA DE DISEÑO: implementado como enum por seguridad de tipos. Si el juego
# termina necesitando especies definidas por datos/contenido (mods, editor
# de nivel, DLC), conviene migrar a String validado contra un registro.
class_name SpeciesId
extends RefCounted

enum Type {
	HUMANITY,
	ORCOID,
	ELVEN,
	DWARVEN,
	GNOMISH,
	GOBLINOID,
	DRACONIAN,
	UNDEAD,
	BEASTS,
	INFERNAL,
	GIANTS,
	ELEMENTAL,
}
