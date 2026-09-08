class_name BlockResolver
extends RefCounted


func resolve(defender_stats: DerivedStats) -> BlockResult:
	assert(defender_stats != null)

	var block_value := maxf(
		0.0,
		defender_stats.shield_block_value
	)

	if block_value <= 0.0:
		return BlockResult.new(
			false,
			0.0
		)

	return BlockResult.new(
		true,
		block_value
	)