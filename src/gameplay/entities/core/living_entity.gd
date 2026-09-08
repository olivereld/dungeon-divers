# living_entity.gd
# Representa una entidad conceptualmente VIVA. OJO: tener HP no es lo que la
# define — LivingEntity es una clasificación semántica que TRAE Health
# consigo, no al revés. Un ObjectEntity con Destructible/Integrity NO es
# LivingEntity aunque también pueda "morir" (destruirse).
class_name LivingEntity
extends Entity

var _health: Health
var _derived_stats: DerivedStats  # referencia, nunca se duplica ni se copia

func _init(p_identity: EntityIdentity, p_health: Health, p_derived_stats: DerivedStats) -> void:
	super._init(p_identity)
	assert(p_health != null, "LivingEntity: health no puede ser null")
	assert(p_derived_stats != null, "LivingEntity: derived_stats no puede ser null")
	_health = p_health
	_derived_stats = p_derived_stats

var health: Health:
	get: return _health

var derived_stats: DerivedStats:
	get: return _derived_stats

func is_alive() -> bool:
	return _health.is_alive()

func is_dead() -> bool:
	return _health.is_dead()
