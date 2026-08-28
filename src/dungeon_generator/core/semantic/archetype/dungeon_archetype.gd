class_name DungeonArchetype
extends RefCounted

## Modelo de valor puro que representa la identidad de un arquetipo de mazmorra.
## Completamente desacoplado de listas fijas o enums hardcodeados.

var id: StringName = &"generic"

func _init(p_id: Variant = &"generic") -> void:
	id = resolve_id(p_id)

func _to_string() -> String:
	return str(id)

## Resuelve y normaliza dinámicamente cualquier entrada (String o StringName) a un StringName de ID de arquetipo.
static func resolve_id(val: Variant) -> StringName:
	if val is StringName:
		return val if not val.is_empty() else &"generic"
	if val is String:
		var s := (val as String).strip_edges().to_lower()
		return StringName(s) if not s.is_empty() else &"generic"
	return &"generic"
