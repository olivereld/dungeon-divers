extends SceneTree

const _DungeonDiagnosticsScript = preload("res://src/dungeon_generator/diagnostics/dungeon_diagnostics.gd")

func _init() -> void:
	print("--- Running experiment_500_detailed ---")
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
		entry["overlap_count"] = snap.overlap_count
		entry["dungeon_bounds_area"] = snap.dungeon_bounds_area

		var before: Dictionary = snap.before_separator_metrics
		var after: Dictionary = snap.after_separator_metrics

		entry["bbox_before"] = {
			"width": before.get("spatial_bbox_width", 0),
			"height": before.get("spatial_bbox_height", 0),
			"area": before.get("spatial_bbox_area", 0)
		}
		entry["pairwise_spacing_before"] = {
			"mean": before.get("pairwise_spacing_mean", 0.0),
			"min": before.get("pairwise_spacing_min", 0.0),
			"max": before.get("pairwise_spacing_max", 0.0),
			"stddev": before.get("pairwise_spacing_stddev", 0.0)
		}
		entry["nearest_neighbor_before"] = {
			"mean": before.get("nearest_neighbor_mean", 0.0),
			"min": before.get("nearest_neighbor_min", 0.0),
			"max": before.get("nearest_neighbor_max", 0.0),
			"stddev": before.get("nearest_neighbor_stddev", 0.0)
		}
		entry["angular_uniformity_before"] = before.get("spatial_angular_uniformity", 0.0)
		entry["radial_variance_before"] = before.get("spatial_radial_distance_variance", 0.0)

		entry["bbox_after"] = {
			"width": after.get("spatial_bbox_width", 0),
			"height": after.get("spatial_bbox_height", 0),
			"area": after.get("spatial_bbox_area", 0)
		}
		entry["pairwise_spacing_after"] = {
			"mean": after.get("pairwise_spacing_mean", 0.0),
			"min": after.get("pairwise_spacing_min", 0.0),
			"max": after.get("pairwise_spacing_max", 0.0),
			"stddev": after.get("pairwise_spacing_stddev", 0.0)
		}
		entry["nearest_neighbor_after"] = {
			"mean": after.get("nearest_neighbor_mean", 0.0),
			"min": after.get("nearest_neighbor_min", 0.0),
			"max": after.get("nearest_neighbor_max", 0.0),
			"stddev": after.get("nearest_neighbor_stddev", 0.0)
		}
		entry["angular_uniformity_after"] = after.get("spatial_angular_uniformity", 0.0)
		entry["radial_variance_after"] = after.get("spatial_radial_distance_variance", 0.0)

		entry["delta_bbox_area"] = entry["bbox_after"]["area"] - entry["bbox_before"]["area"]
		entry["delta_pairwise_spacing_mean"] = entry["pairwise_spacing_after"]["mean"] - entry["pairwise_spacing_before"]["mean"]
		entry["delta_nearest_neighbor_mean"] = entry["nearest_neighbor_after"]["mean"] - entry["nearest_neighbor_before"]["mean"]
		entry["delta_angular_uniformity"] = entry["angular_uniformity_after"] - entry["angular_uniformity_before"]
		entry["delta_radial_variance"] = entry["radial_variance_after"] - entry["radial_variance_before"]
		entry["delta_spacing_min"] = entry["pairwise_spacing_after"]["min"] - entry["pairwise_spacing_before"]["min"]

		entry["placement_fallback"] = {
			"tier_0_1_2": snap.room_count - snap.placement_tier_3 - snap.placement_tier_4,
			"tier_3": snap.placement_tier_3,
			"tier_4": snap.placement_tier_4
		}

		results.append(entry)

	var summary = _compute_summary(results)
	var worst = _identify_worst(results, 10)
	var worst_visuals = _generate_visuals(worst, snapshots)

	var results_file = FileAccess.open("baseline/experiment_500_results.json", FileAccess.WRITE)
	if results_file:
		results_file.store_string(JSON.stringify(results, "\t"))
		results_file = null

	var summary_file = FileAccess.open("baseline/experiment_500_summary.json", FileAccess.WRITE)
	if summary_file:
		summary_file.store_string(JSON.stringify(summary, "\t"))
		summary_file = null

	var worst_file = FileAccess.open("baseline/worst_seeds.json", FileAccess.WRITE)
	if worst_file:
		worst_file.store_string(JSON.stringify(worst_visuals, "\t"))
		worst_file = null

	print("[OK] Experiment 500 seeds completed.")
	print("  baseline/experiment_500_results.json")
	print("  baseline/experiment_500_summary.json")
	print("  baseline/worst_seeds.json")
	print("  Worst seed: %d (score=%.1f)" % [worst[0]["seed"], worst[0]["_score"]])
	quit(0)

func _compute_stats(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"mean": 0.0, "median": 0.0, "min": 0.0, "max": 0.0, "p10": 0.0, "p25": 0.0, "p75": 0.0, "p90": 0.0, "stddev": 0.0, "count": 0}
	var sorted_vals: Array[float] = values.duplicate()
	sorted_vals.sort()
	var n: int = sorted_vals.size()
	var sum: float = 0.0
	for v in sorted_vals:
		sum += v
	var mean: float = sum / float(n)
	var median: float = sorted_vals[n / 2] if n % 2 == 1 else (sorted_vals[n / 2 - 1] + sorted_vals[n / 2]) / 2.0
	var variance: float = 0.0
	for v in sorted_vals:
		variance += (v - mean) * (v - mean)
	variance /= float(n)
	var p = func(idx: int) -> float:
		var i: int = clampi(idx, 0, n - 1)
		return sorted_vals[i]
	return {
		"mean": mean, "median": median, "min": sorted_vals[0], "max": sorted_vals[n - 1],
		"p10": p(int(round(0.10 * (n - 1)))), "p25": p(int(round(0.25 * (n - 1)))),
		"p75": p(int(round(0.75 * (n - 1)))), "p90": p(int(round(0.90 * (n - 1)))),
		"stddev": sqrt(variance), "count": n
	}

func _compute_summary(results: Array) -> Dictionary:
	var metrics := ["overlap_count", "tier_3_count", "tier_4_count", "dungeon_bounds_area",
		"delta_bbox_area", "delta_pairwise_spacing_mean", "delta_nearest_neighbor_mean",
		"delta_angular_uniformity", "delta_radial_variance", "delta_spacing_min"]
	var summary: Dictionary = {}
	for m in metrics:
		var vals: Array[float] = []
		for r in results:
			var v = r[m]
			if typeof(v) == TYPE_FLOAT:
				vals.append(float(v))
			elif typeof(v) == TYPE_INT:
				vals.append(float(v))
		summary[m] = _compute_stats(vals)

	# Per-metric stats for spacing and angular uniformity after separator
	var spacing_after_vals: Array[float] = []
	var angular_after_vals: Array[float] = []
	for r in results:
		spacing_after_vals.append(r["pairwise_spacing_after"]["mean"])
		angular_after_vals.append(r["angular_uniformity_after"])
	summary["pairwise_spacing_after"] = _compute_stats(spacing_after_vals)
	summary["angular_uniformity_after"] = _compute_stats(angular_after_vals)

	# Placement fallback summary
	var tier012_vals: Array[float] = []
	var tier3_vals: Array[float] = []
	var tier4_vals: Array[float] = []
	for r in results:
		tier012_vals.append(float(r["placement_fallback"]["tier_0_1_2"]))
		tier3_vals.append(float(r["placement_fallback"]["tier_3"]))
		tier4_vals.append(float(r["placement_fallback"]["tier_4"]))
	summary["placement_fallback_tier012"] = _compute_stats(tier012_vals)
	summary["placement_fallback_tier3"] = _compute_stats(tier3_vals)
	summary["placement_fallback_tier4"] = _compute_stats(tier4_vals)

	# Overlap count stats
	var overlap_vals: Array[float] = []
	var overlap_nonzero: int = 0
	for r in results:
		var ov = r["overlap_count"]
		overlap_vals.append(float(ov))
		if ov > 0:
			overlap_nonzero += 1
	summary["overlap_count"] = _compute_stats(overlap_vals)
	summary["overlap_nonzero_count"] = overlap_nonzero
	summary["overlap_pct"] = float(overlap_nonzero) / float(results.size()) * 100.0

	summary["total_seeds"] = results.size()
	return summary

func _compute_score(r: Dictionary) -> float:
	var score: float = 0.0
	score += float(r["overlap_count"]) * 50.0
	score += float(r["tier_3_count"]) * 5.0
	score += float(r["tier_4_count"]) * 15.0
	score += float(r["delta_bbox_area"]) * 0.01
	score += float(r["delta_angular_uniformity"]) * -10.0
	score += float(r["delta_radial_variance"]) * 0.1
	score += float(r["delta_spacing_min"]) * -1.0
	return score

func _identify_worst(results: Array, count: int) -> Array:
	var scored: Array[Dictionary] = []
	for r in results:
		var entry := r.duplicate()
		entry["_score"] = _compute_score(r)
		scored.append(entry)
	scored.sort_custom(func(a, b): return a["_score"] > b["_score"])
	var worst: Array = []
	var n = min(count, scored.size())
	for i in range(n):
		worst.append(scored[i])
	return worst

func _generate_visuals(worst: Array, snapshots) -> Array:
	# Build a lookup from seed to snapshot for room access
	var snap_by_seed: Dictionary = {}
	for s in snapshots:
		snap_by_seed[s.generation_seed_used] = s

	var visuals: Array = []
	for w in worst:
		var seed: int = w["seed"]
		var snap = snap_by_seed.get(seed)
		var entry := w.duplicate()
		entry.erase("_score")

		var room_lines: Array = []
		if snap and snap.rooms.size() > 0:
			for r in snap.rooms:
				room_lines.append("  Room %d: rect=(%d,%d,%dx%d) type=%s area=%d" % [
					r.id, r.rect.position.x, r.rect.position.y, r.rect.size.x, r.rect.size.y, r.room_type, r.get_area()
				])
		else:
			room_lines.append("  (no rooms)")

		entry["rooms"] = room_lines
		entry["seed"] = seed
		entry["overlap_rooms"] = []
		# Find overlapping pairs
		if snap and snap.rooms.size() > 0:
			for i in range(snap.rooms.size()):
				for j in range(i + 1, snap.rooms.size()):
					if snap.rooms[i].overlaps(snap.rooms[j]):
						entry["overlap_rooms"].append("Room %d overlaps Room %d" % [snap.rooms[i].id, snap.rooms[j].id])
		visuals.append(entry)
	return visuals