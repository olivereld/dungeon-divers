class_name BlockResolver
extends RefCounted


func resolve(defender_stats: DerivedStats) -> float:
	assert(defender_stats != null)

	return maxf(
		0.0,
		defender_stats.shield_block_value
	)