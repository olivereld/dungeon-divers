class_name AttackData
extends RefCounted

var base_damage: float
var damage_type: DamageType.Type

func _init(
	p_base_damage: float,
	p_damage_type: DamageType.Type
) -> void:
	assert(p_base_damage >= 0.0)

	base_damage = p_base_damage
	damage_type = p_damage_type