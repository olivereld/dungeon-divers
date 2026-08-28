class_name RoomPurpose
extends RefCounted

## Modelo de valor puro que representa el propósito funcional/arquitectónico de una sala.
## Desacoplado de listas fijas o enums de contenido; la identidad es un StringName.

var id: StringName = &"generic"

func _init(p_id: Variant = &"generic") -> void:
	id = resolve_id(p_id)

func _to_string() -> String:
	return str(id)

## Resuelve y normaliza cualquier entrada a un StringName de ID de propósito.
static func resolve_id(val: Variant) -> StringName:
	if val is StringName:
		return val if not val.is_empty() else &"generic"
	if val is String:
		var s := (val as String).strip_edges().to_lower()
		return StringName(s) if not s.is_empty() else &"generic"
	return &"generic"

static func to_name(p_id: Variant) -> String:
	return str(resolve_id(p_id)).to_upper()

static func from_name(p_name: String) -> StringName:
	return resolve_id(p_name)
