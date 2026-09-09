# entity_kind.gd
# Categorías del dominio a las que puede pertenecer una entidad.
# IMPORTANTE: esto es SOLO taxonomía ("qué tipo de entidad es"), nunca
# especie (eso es SpeciesId), ni organización (eso es FactionId),
# ni disposición/comportamiento (eso es Disposition).
class_name EntityKind
extends RefCounted

enum Type {
	PLAYER,
	NPC,
	CREATURE,
	MONSTER,
	SUMMON,
	AUTOMATON,
	TURRET,
	TRAP,
	DESTRUCTIBLE_OBJECT,
}
