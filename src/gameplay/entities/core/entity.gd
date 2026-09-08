# entity.gd
# Base mínima que TODA entidad del dominio comparte: identidad + kind.
# Deliberadamente pequeña. NO debe crecer con HP, Stats, Faction, AI, Attack,
# Position, Sprite, Inventory, etc.
#
# Capacidades (Targetable, Destructible, Automated, Triggerable, Faction...)
# se adjuntan vía composición (add_capability/get_capability) en vez de vivir
# como campos fijos en cada subclase. Esto permite, por ejemplo, que un Turret
# (ObjectEntity) y un Guard (LivingEntity) compartan Faction y Targetable sin
# forzar una jerarquía común más allá de Entity.
class_name Entity
extends RefCounted

var _identity: EntityIdentity
var _capabilities: Dictionary = {}  # String (nombre de capacidad) -> capacidad

func _init(p_identity: EntityIdentity) -> void:
	assert(p_identity != null, "Entity: identity no puede ser null")
	_identity = p_identity

var identity: EntityIdentity:
	get: return _identity

var kind: EntityKind.Type:
	get: return _identity.kind

var entity_id: String:
	get: return _identity.entity_id

func add_capability(capability_name: String, capability) -> void:
	assert(capability_name != null and capability_name != "", "Entity: capability_name no puede estar vacío")
	assert(capability != null, "Entity: capability no puede ser null")
	_capabilities[capability_name] = capability

func has_capability(capability_name: String) -> bool:
	return _capabilities.has(capability_name)

func get_capability(capability_name: String):
	assert(has_capability(capability_name), "Entity: no existe la capacidad '%s' en %s" % [capability_name, entity_id])
	return _capabilities[capability_name]

func try_get_capability(capability_name: String):
	return _capabilities.get(capability_name, null)
