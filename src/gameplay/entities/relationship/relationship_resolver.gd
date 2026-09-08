# relationship_resolver.gd
# Resuelve la disposición de A hacia B siguiendo la prioridad:
#   1. Relación explícita entidad-a-entidad
#   2. Relación explícita facción-a-facción
#   3. Disposición por defecto
# Es puro: NUNCA modifica las entidades, facciones ni relaciones que recibe.
class_name RelationshipResolver
extends RefCounted

var _entity_relationships: Dictionary = {}   # "source_id|target_id" -> EntityRelationship
var _faction_relationships: Dictionary = {}  # "faction_a|faction_b" -> Disposition
var _default_disposition: Disposition

func _init(p_default_disposition: Disposition = null) -> void:
	_default_disposition = p_default_disposition if p_default_disposition != null else Disposition.neutral()

func set_entity_relationship(relationship: EntityRelationship) -> void:
	assert(relationship != null, "RelationshipResolver: relationship no puede ser null")
	var key := _entity_key(relationship.source_entity_id, relationship.target_entity_id)
	_entity_relationships[key] = relationship

func set_faction_relationship(source_faction: FactionId.Type, target_faction: FactionId.Type, disposition: Disposition) -> void:
	assert(disposition != null, "RelationshipResolver: disposition no puede ser null")
	var key := _faction_key(source_faction, target_faction)
	_faction_relationships[key] = disposition

# source/target: Entity (LivingEntity u ObjectEntity). Si tienen adjunta la
# capacidad "faction" (Entity.add_capability("faction", Faction.new(...))),
# se usa para la resolución por facción.
func resolve(source: Entity, target: Entity) -> Disposition:
	assert(source != null, "RelationshipResolver: source no puede ser null")
	assert(target != null, "RelationshipResolver: target no puede ser null")

	var entity_key := _entity_key(source.entity_id, target.entity_id)
	if _entity_relationships.has(entity_key):
		return _entity_relationships[entity_key].disposition

	var source_faction: Faction = source.try_get_capability("faction")
	var target_faction: Faction = target.try_get_capability("faction")
	if source_faction != null and target_faction != null:
		var faction_key := _faction_key(source_faction.id, target_faction.id)
		if _faction_relationships.has(faction_key):
			return _faction_relationships[faction_key]

	return _default_disposition

func _entity_key(source_id: String, target_id: String) -> String:
	return "%s|%s" % [source_id, target_id]

func _faction_key(source_faction: FactionId.Type, target_faction: FactionId.Type) -> String:
	return "%s|%s" % [source_faction, target_faction]
