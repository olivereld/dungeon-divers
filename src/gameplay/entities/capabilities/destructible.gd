# destructible.gd
# Capacidad: esta entidad tiene integridad propia y puede ser destruida.
# Envuelve una Integrity, igual que LivingEntity envuelve una Health.
class_name Destructible
extends RefCounted

var _integrity: Integrity

func _init(p_integrity: Integrity) -> void:
	assert(p_integrity != null, "Destructible: integrity no puede ser null")
	_integrity = p_integrity

var integrity: Integrity:
	get: return _integrity

func is_destroyed() -> bool:
	return _integrity.is_destroyed()
