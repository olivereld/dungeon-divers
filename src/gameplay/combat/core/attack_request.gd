class_name AttackRequest
extends RefCounted

var attacker_stats: DerivedStats
var defender_stats: DerivedStats
var attack_data: AttackData

func _init(
	p_attacker_stats: DerivedStats,
	p_defender_stats: DerivedStats,
	p_attack_data: AttackData
) -> void:
	assert(p_attacker_stats != null)
	assert(p_defender_stats != null)
	assert(p_attack_data != null)

	attacker_stats = p_attacker_stats
	defender_stats = p_defender_stats
	attack_data = p_attack_data