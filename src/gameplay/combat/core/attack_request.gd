class_name AttackRequest
extends RefCounted


var attacker_stats: DerivedStats
var defender_stats: DerivedStats


func _init(
	p_attacker_stats: DerivedStats,
	p_defender_stats: DerivedStats
) -> void:
	if p_attacker_stats == null:
		push_error("AttackRequest: attacker_stats cannot be null.")
		return

	if p_defender_stats == null:
		push_error("AttackRequest: defender_stats cannot be null.")
		return

	attacker_stats = p_attacker_stats
	defender_stats = p_defender_stats