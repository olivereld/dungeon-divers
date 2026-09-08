# attribute_type.gd
# Los 6 atributos primarios oficiales de Dungeon Divers.
# Nada fuera de este archivo debería inventar un séptimo atributo "informal";
# si hace falta uno nuevo, se añade aquí y se propaga al resto del módulo.
class_name AttributeType
extends RefCounted

enum Type {
	STRENGTH,
	DEXTERITY,
	CONSTITUTION,
	INTELLIGENCE,
	WISDOM,
	CHARISMA,
}

static func to_string_name(type: Type) -> String:
	match type:
		Type.STRENGTH: return "Strength"
		Type.DEXTERITY: return "Dexterity"
		Type.CONSTITUTION: return "Constitution"
		Type.INTELLIGENCE: return "Intelligence"
		Type.WISDOM: return "Wisdom"
		Type.CHARISMA: return "Charisma"
	return "Unknown"
