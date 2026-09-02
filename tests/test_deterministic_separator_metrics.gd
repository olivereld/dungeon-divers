extends SceneTree

const _DungeonDiagnosticsScript = preload("res://src/dungeon_generator/diagnostics/dungeon_diagnostics.gd")

func _init() -> void:
	print("--- Running Deterministic Separator Metrics Test (Seeds 1, 250, 500) ---")
	var diag = _DungeonDiagnosticsScript.new()
	var test_seeds: Array[int] = [1, 250, 500]
	var snapshots = diag.run_seeds(test_seeds)

	for snap in snapshots:
		print("\n=== SEED %d ===" % snap.generation_seed_used)
		var before: Dictionary = snap.before_separator_metrics
		var after: Dictionary = snap.after_separator_metrics

		print("BEFORE Separator:")
		print("  BBox: %dx%d (Area: %d)" % [before.get("spatial_bbox_width", 0), before.get("spatial_bbox_height", 0), before.get("spatial_bbox_area", 0)])
		print("  Pairwise Spacing: mean=%.2f min=%.2f max=%.2f stddev=%.2f" % [
			before.get("pairwise_spacing_mean", 0.0),
			before.get("pairwise_spacing_min", 0.0),
			before.get("pairwise_spacing_max", 0.0),
			before.get("pairwise_spacing_stddev", 0.0)
		])
		print("  Nearest Neighbor: mean=%.2f min=%.2f max=%.2f stddev=%.2f" % [
			before.get("nearest_neighbor_mean", 0.0),
			before.get("nearest_neighbor_min", 0.0),
			before.get("nearest_neighbor_max", 0.0),
			before.get("nearest_neighbor_stddev", 0.0)
		])

		print("AFTER Separator:")
		print("  BBox: %dx%d (Area: %d)" % [after.get("spatial_bbox_width", 0), after.get("spatial_bbox_height", 0), after.get("spatial_bbox_area", 0)])
		print("  Pairwise Spacing: mean=%.2f min=%.2f max=%.2f stddev=%.2f" % [
			after.get("pairwise_spacing_mean", 0.0),
			after.get("pairwise_spacing_min", 0.0),
			after.get("pairwise_spacing_max", 0.0),
			after.get("pairwise_spacing_stddev", 0.0)
		])
		print("  Nearest Neighbor: mean=%.2f min=%.2f max=%.2f stddev=%.2f" % [
			after.get("nearest_neighbor_mean", 0.0),
			after.get("nearest_neighbor_min", 0.0),
			after.get("nearest_neighbor_max", 0.0),
			after.get("nearest_neighbor_stddev", 0.0)
		])

		assert(before.get("pairwise_spacing_stddev", 0.0) > 0.0, "Pairwise spacing stddev BEFORE must be non-zero")
		assert(before.get("nearest_neighbor_stddev", 0.0) > 0.0, "Nearest neighbor stddev BEFORE must be non-zero")
		assert(before.get("nearest_neighbor_cv", 0.0) > 0.0, "Nearest neighbor cv BEFORE must be non-zero")
		assert(before.get("pairwise_spacing_max", 0.0) > 0.0, "Pairwise spacing max BEFORE must be non-zero")
		assert(before.get("nearest_neighbor_max", 0.0) > 0.0, "Nearest neighbor max BEFORE must be non-zero")

		assert(after.get("pairwise_spacing_stddev", 0.0) > 0.0, "Pairwise spacing stddev AFTER must be non-zero")
		assert(after.get("nearest_neighbor_stddev", 0.0) > 0.0, "Nearest neighbor stddev AFTER must be non-zero")
		assert(after.get("nearest_neighbor_cv", 0.0) > 0.0, "Nearest neighbor cv AFTER must be non-zero")
		assert(after.get("pairwise_spacing_max", 0.0) > 0.0, "Pairwise spacing max AFTER must be non-zero")
		assert(after.get("nearest_neighbor_max", 0.0) > 0.0, "Nearest neighbor max AFTER must be non-zero")

	print("\nAll deterministic metric checks passed successfully!")
	quit()