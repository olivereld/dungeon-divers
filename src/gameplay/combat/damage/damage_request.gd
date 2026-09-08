class_name DamageRequest
extends RefCounted


var attacker_stats: DerivedStats
var defender_stats: DerivedStats

var base_damage: float
var damage_type: DamageType.Type

var is_critical: bool = false


func _init(
	p_attacker_stats: DerivedStats,
	p_defender_stats: DerivedStats,
	p_base_damage: float,
	p_damage_type: DamageType.Type,
	p_is_critical: bool = false
) -> void:

	assert(p_attacker_stats != null)
	assert(p_defender_stats != null)

	attacker_stats = p_attacker_stats
	defender_stats = p_defender_stats

	base_damage = maxf(0.0, p_base_damage)
	damage_type = p_damage_type

	is_critical = p_is_critical