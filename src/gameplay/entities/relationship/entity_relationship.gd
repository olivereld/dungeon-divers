# entity_relationship.gd
# Relación DIRIGIDA entre dos entidades: A -> B no implica B -> A.
class_name EntityRelationship
extends RefCounted

var _source_entity_id: String
var _target_entity_id: String
var _disposition: Disposition

func _init(p_source_entity_id: String, p_target_entity_id: String, p_disposition: Disposition) -> void:
	assert(p_source_entity_id != "", "EntityRelationship: source_entity_id no puede estar vacío")
	assert(p_target_entity_id != "", "EntityRelationship: target_entity_id no puede estar vacío")
	assert(p_disposition != null, "EntityRelationship: disposition no puede ser null")
	_source_entity_id = p_source_entity_id
	_target_entity_id = p_target_entity_id
	_disposition = p_disposition

var source_entity_id: String:
	get: return _source_entity_id

var target_entity_id: String:
	get: return _target_entity_id

var disposition: Disposition:
	get: return _disposition
