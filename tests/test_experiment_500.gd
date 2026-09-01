extends SceneTree

const _DungeonDiagnosticsScript = preload("res://src/dungeon_generator/diagnostics/dungeon_diagnostics.gd")

func _init() -> void:
	print("--- Running experiment_500 ---")
	var diag = _DungeonDiagnosticsScript.new()
	var seeds: Array[int] = []
	for i in range(1, 501):
		seeds.append(i)
	var snapshots = diag.run_seeds(seeds)

	var results = []
	for snap in snapshots:
		var entry := {}
		entry["seed"] = snap.generation_seed_used
		entry["rooms"] = snap.room_count
		entry["tier_3_count"] = snap.placement_tier_3
		entry["tier_4_count"] = snap.placement_tier_4

		var before: Dictionary = snap.before_separator_metrics
		var after: Dictionary = snap.after_separator_metrics

		entry["bbox_before"] = {
			"width": before.get("spatial_bbox_width", 0),
			"height": before.get("spatial_bbox_height", 0),
			"area": before.get("spatial_bbox_area", 0)
		}
		entry["spacing_before"] = before.get("spatial_minimum_center_distance", 0.0)
		entry["angular_uniformity_before"] = before.get("spatial_angular_uniformity", 0.0)
		entry["radial_variance_before"] = before.get("spatial_radial_distance_variance", 0.0)

		entry["bbox_after"] = {
			"width": after.get("spatial_bbox_width", 0),
			"height": after.get("spatial_bbox_height", 0),
			"area": after.get("spatial_bbox_area", 0)
		}
		entry["spacing_after"] = after.get("spatial_minimum_center_distance", 0.0)
		entry["angular_uniformity_after"] = after.get("spatial_angular_uniformity", 0.0)
		entry["radial_variance_after"] = after.get("spatial_radial_distance_variance", 0.0)

		entry["delta_bbox_width"] = entry["bbox_after"]["width"] - entry["bbox_before"]["width"]
		entry["delta_bbox_height"] = entry["bbox_after"]["height"] - entry["bbox_before"]["height"]
		entry["delta_bbox_area"] = entry["bbox_after"]["area"] - entry["bbox_before"]["area"]
		entry["delta_spacing"] = entry["spacing_after"] - entry["spacing_before"]
		entry["delta_angular_uniformity"] = entry["angular_uniformity_after"] - entry["angular_uniformity_before"]
		entry["delta_radial_variance"] = entry["radial_variance_after"] - entry["radial_variance_before"]

		results.append(entry)

	var json_str := JSON.stringify(results, "\t")
	var file = FileAccess.open("baseline/experiment_500_results.json", FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file = null

	print("[OK] Experiment 500 seeds completed.")
	print("  Results saved to baseline/experiment_500_results.json")
	print("  Total entries: %d" % results.size())
	quit(0)