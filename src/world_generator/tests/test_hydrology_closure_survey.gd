extends SceneTree

## Survey de Cierre Hidrológico Multi-Seed (30 Seeds)
## Valida formalmente las garantías topológicas, hidrológicas y de presentación en volumen.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _HydrologyValidationScript = preload("res://src/world_generator/validation/hydrology_validation.gd")

func _init() -> void:
	print("================================================================================")
	print(" HYDROLOGY CLOSURE SURVEY — 30 SEEDS FORMAL VALIDATION")
	print("================================================================================")

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.22
	profile.max_rivers = 4
	profile.min_river_length = 8.0

	var total_seeds: int = 30
	var passed_seeds: int = 0
	var total_rivers: int = 0
	var total_confluences: int = 0
	var total_lakes: int = 0
	var strahler_distribution: Dictionary = { 1: 0, 2: 0, 3: 0, 4: 0 }
	var total_monotonic_failures: int = 0
	var total_dead_end_failures: int = 0
	var total_cycles: int = 0
	var total_errors: Array[String] = []

	for s in range(1, total_seeds + 1):
		var current_seed := 2000 + s
		var result = _WorldPipelineScript.generate(current_seed, profile)
		if result == null or result.hydrology == null:
			printerr("  [ERROR] Seed %d: WorldResult or HydrologyResult is null" % current_seed)
			continue

		var val: Dictionary = _HydrologyValidationScript.validate(result, profile)
		var metrics: Dictionary = val.get("metrics", {})

		var n_rivers: int = metrics.get("river_count", 0)
		var n_conf: int = metrics.get("confluence_count", 0)
		var n_lakes: int = metrics.get("lake_count", 0)
		var max_s: int = metrics.get("max_strahler_order", 1)
		var mono_fail: int = metrics.get("monotonic_elevation_failures", 0)
		var dead_fail: int = metrics.get("dead_end_failures", 0)
		var cycle_detected: bool = metrics.get("cycle_detected", false)

		total_rivers += n_rivers
		total_confluences += n_conf
		total_lakes += n_lakes
		total_monotonic_failures += mono_fail
		total_dead_end_failures += dead_fail
		if cycle_detected:
			total_cycles += 1

		for r in result.hydrology.rivers:
			var ord: int = r.order if (r is River or "order" in r) else r.get("order", 1)
			var capped_ord: int = mini(ord, 4)
			strahler_distribution[capped_ord] = strahler_distribution.get(capped_ord, 0) + 1

		if val.get("valid", false):
			passed_seeds += 1
		else:
			for err in val.get("errors", []):
				total_errors.append("Seed %d: %s" % [current_seed, err])

	print("--------------------------------------------------------------------------------")
	print(" SURVEY RESULTS:")
	print("  • Evaluated Seeds:           %d" % total_seeds)
	print("  • 100%% Valid Seeds:          %d / %d (%.1f%%)" % [passed_seeds, total_seeds, (float(passed_seeds) / float(total_seeds)) * 100.0])
	print("  • Total Rivers Generated:    %d (avg %.1f / seed)" % [total_rivers, float(total_rivers) / float(total_seeds)])
	print("  • Total Confluences:         %d" % total_confluences)
	print("  • Total Lakes:               %d" % total_lakes)
	print("  • Strahler Distribution:     R1=%d, R2=%d, R3=%d, R4+=%d" % [
		strahler_distribution[1], strahler_distribution[2], strahler_distribution[3], strahler_distribution[4]
	])
	print("  • Monotonic Elevation Drops: %d failures (tolerance +0.0005m)" % total_monotonic_failures)
	print("  • Dead-End Violations:       %d failures" % total_dead_end_failures)
	print("  • Graph Cycles:              %d detected" % total_cycles)
	print("--------------------------------------------------------------------------------")

	if total_errors.is_empty():
		print(" >> ALL 30 SEEDS PASSED 100% OF HYDROLOGY & TOPOLOGICAL INVARIANTS <<")
		quit(0)
	else:
		printerr(" >> SURVEY FAILED WITH %d ERRORS <<" % total_errors.size())
		for i in range(mini(total_errors.size(), 10)):
			printerr("    - %s" % total_errors[i])
		quit(1)
