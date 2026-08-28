class_name DungeonArchetype
extends RefCounted

## Modelo de valor que representa la identidad de un arquetipo de mazmorra.

var id: StringName = &"generic"

func _init(p_id: Variant = &"generic") -> void:
	id = resolve_id(p_id)

enum Type {
	GENERIC = 0,
	MAUSOLEUM = 1,
	NECROPOLIS = 1,
	FORTRESS = 2,
	TEMPLE = 3,
	MINE = 4
}

static func to_name(p_type: Type) -> String:
	match p_type:
		Type.GENERIC: return "GENERIC"
		Type.NECROPOLIS: return "NECROPOLIS"
		Type.FORTRESS: return "FORTRESS"
		Type.TEMPLE: return "TEMPLE"
		Type.MINE: return "MINE"
		_: return "UNKNOWN"

static func from_name(p_name: String) -> Type:
	match p_name.to_upper():
		"GENERIC": return Type.GENERIC
		"NECROPOLIS", "MAUSOLEUM", "CRYPT": return Type.NECROPOLIS
		"FORTRESS": return Type.FORTRESS
		"TEMPLE": return Type.TEMPLE
		"MINE": return Type.MINE
		_: return Type.GENERIC

## Resuelve dinámicamente cualquier tipo de entrada (String, StringName o int legacy) a un StringName de ID de arquetipo.
static func resolve_id(val: Variant) -> StringName:
	if val is StringName:
		return val
	if val is String:
		return StringName((val as String).to_lower())
	if val is int:
		match int(val):
			Type.MAUSOLEUM: return &"necropolis"
			Type.FORTRESS: return &"fortress"
			Type.TEMPLE: return &"temple"
			Type.MINE: return &"mine"
			_: return &"generic"
	return &"generic"
