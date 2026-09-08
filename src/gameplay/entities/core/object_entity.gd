# object_entity.gd
# Representa una entidad NO viva: barriles, trampas, torretas, cofres...
# No tiene Health. Solo posee las capacidades (Targetable, Destructible,
# Automated, Triggerable, Faction) que realmente le correspondan, adjuntadas
# vía Entity.add_capability — nunca todas por defecto.
class_name ObjectEntity
extends Entity

func _init(p_identity: EntityIdentity) -> void:
	super._init(p_identity)
