# entity_identity.gd
# Responde: "¿Qué entidad es esta?"
# Inmutable tras construcción. NUNCA usar Node.get_instance_id() ni el nombre
# del Node como identidad de dominio: ambos dependen de la escena/presentación
# y no deben filtrarse aquí.
class_name EntityIdentity
extends RefCounted

var _entity_id: String
var _kind: EntityKind.Type
var _display_name: String

func _init(p_entity_id: String, p_kind: EntityKind.Type, p_display_name: String = "") -> void:
	assert(p_entity_id != null and p_entity_id != "", "EntityIdentity: entity_id no puede estar vacío")
	_entity_id = p_entity_id
	_kind = p_kind
	_display_name = p_display_name if p_display_name != "" else p_entity_id

var entity_id: String:
	get: return _entity_id

var kind: EntityKind.Type:
	get: return _kind

var display_name: String:
	get: return _display_name

func equals(other: EntityIdentity) -> bool:
	return other != null and other.entity_id == _entity_id
