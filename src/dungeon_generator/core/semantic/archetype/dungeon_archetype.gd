class_name DungeonArchetype
extends RefCounted

## Identificador canónico y tipos de arquetipos de mazmorra.

enum Type {
	GENERIC = 0,
	MAUSOLEUM = 1,
	FORTRESS = 2,
	TEMPLE = 3,
	MINE = 4
}

static func to_name(p_type: Type) -> String:
	match p_type:
		Type.GENERIC: return "GENERIC"
		Type.MAUSOLEUM: return "MAUSOLEUM"
		Type.FORTRESS: return "FORTRESS"
		Type.TEMPLE: return "TEMPLE"
		Type.MINE: return "MINE"
		_: return "UNKNOWN"

static func from_name(p_name: String) -> Type:
	match p_name.to_upper():
		"GENERIC": return Type.GENERIC
		"MAUSOLEUM": return Type.MAUSOLEUM
		"FORTRESS": return Type.FORTRESS
		"TEMPLE": return Type.TEMPLE
		"MINE": return Type.MINE
		_: return Type.GENERIC
