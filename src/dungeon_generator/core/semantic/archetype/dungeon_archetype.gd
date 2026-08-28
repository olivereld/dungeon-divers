class_name DungeonArchetype
extends RefCounted

## Modelo de valor que representa la identidad de un arquetipo de mazmorra.

var id: StringName = &"generic"

func _init(p_id: Variant = &"generic") -> void:
	id = resolve_id(p_id)

func _to_string() -> String:
	return str(id)

# Constantes numéricas para compatibilidad retroactiva
enum Type {
	GENERIC = 0,
	MAUSOLEUM = 1,
	NECROPOLIS = 1,
	FORTRESS = 2,
	TEMPLE = 3,
	MINE = 4
}

## Resuelve dinámicamente cualquier tipo de entrada (String, StringName o int legacy) a un StringName normalizado.
static func resolve_id(val: Variant) -> StringName:
	if val is StringName:
		return val
	if val is String:
		var s := (val as String).strip_edges().to_lower()
		return StringName(s) if not s.is_empty() else &"generic"
	if val is int:
		match int(val):
			Type.NECROPOLIS: return &"necropolis"
			Type.FORTRESS: return &"fortress"
			Type.TEMPLE: return &"temple"
			Type.MINE: return &"mine"
			_: return &"generic"
	return &"generic"
