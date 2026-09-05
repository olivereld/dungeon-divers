class_name DungeonDiagnostics
extends RefCounted

## Sistema de diagnóstico que ejecuta el generador con un conjunto
## de seeds y produce métricas estructuradas para el baseline.
## 100% headless: no depende de nodos de escena ni del renderizador.

const _DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const _DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const _DungeonMetricSnapshotScript = preload("res://src/dungeon_generator/diagnostics/dungeon_metric_snapshot.gd")

var _pipeline: DungeonPipeline
var _config: DungeonConfig

func _init() -> void:
	_pipeline = _DungeonPipelineScript.new()

## Ejecuta una generación con el seed dado y devuelve el snapshot de métricas.
func run(seed: int, config_override: DungeonConfig = null):
	var cfg: DungeonConfig = config_override if config_override != null else build_config(seed)
	var result: DungeonResult = _pipeline.generate(cfg)
	return _snapshot_from_result(result, cfg)

## Ejecuta múltiples seeds y devuelve un array de snapshots.
func run_seeds(seeds: Array[int]) -> Array:
	var snapshots = []
	for s in seeds:
		snapshots.append(run(s))
	return snapshots

## Genera el reporte formateado a partir de un snapshot.
func generate_report(snapshot) -> String:
	var lines: PackedStringArray = []
	lines.append("Dungeon Generation Report")
	lines.append("──────────────────────────────")
	lines.append("Seed: %d" % snapshot.generation_seed_used)
	lines.append("")
	lines.append("Rooms")
	lines.append("  count: %d" % snapshot.room_count)
	lines.append("  average area: %.1f" % snapshot.room_average_area)
	lines.append("")
	lines.append("Connections")
	lines.append("  count: %d" % snapshot.connection_count)
	lines.append("  average degree: %.2f" % snapshot.connection_average_degree)
	lines.append("  dead ends: %d" % snapshot.connection_dead_ends)
	lines.append("  loops: %d" % snapshot.connection_loops)
	lines.append("")
	lines.append("Spatial")
	lines.append("  average center distance: %.1f" % snapshot.spatial_average_center_distance)
	lines.append("  minimum center distance: %.1f" % snapshot.spatial_minimum_center_distance)
	lines.append("  start centrality: %.1f" % snapshot.start_to_centroid_distance)
	lines.append("  angular uniformity: %.2f" % snapshot.spatial_angular_uniformity)
	lines.append("  radial distance variance: %.1f" % snapshot.spatial_radial_distance_variance)
	lines.append("  radiality (provisional): %.2f" % snapshot.spatial_radiality_provisional)
	lines.append("  nearest neighbor mean: %.2f" % snapshot.nearest_neighbor_mean)
	lines.append("  nearest neighbor cv: %.2f" % snapshot.nearest_neighbor_cv)
	lines.append("")
	lines.append("Placement Tiers")
	lines.append("  tier 3 (shrink): %d" % snapshot.placement_tier_3)
	lines.append("  tier 4 (grid scan): %d" % snapshot.placement_tier_4)
	lines.append("")
	lines.append("Placement Separator Impact")
	lines.append("  radiality_before: %.2f" % snapshot.before_separator_metrics.get("spatial_radiality_provisional", 0.0))
	lines.append("  radiality_after: %.2f" % snapshot.after_separator_metrics.get("spatial_radiality_provisional", 0.0))
	lines.append("  bbox_width_before: %d" % snapshot.before_separator_metrics.get("spatial_bbox_width", 0))
	lines.append("  bbox_width_after: %d" % snapshot.after_separator_metrics.get("spatial_bbox_width", 0))
	lines.append("  bbox_height_before: %d" % snapshot.before_separator_metrics.get("spatial_bbox_height", 0))
	lines.append("  bbox_height_after: %d" % snapshot.after_separator_metrics.get("spatial_bbox_height", 0))
	lines.append("  bbox_area_before: %d" % snapshot.before_separator_metrics.get("spatial_bbox_area", 0))
	lines.append("  bbox_area_after: %d" % snapshot.after_separator_metrics.get("spatial_bbox_area", 0))
	lines.append("  start_centrality_before: %.1f" % snapshot.before_separator_metrics.get("start_to_centroid_distance", 0.0))
	lines.append("  start_centrality_after: %.1f" % snapshot.after_separator_metrics.get("start_to_centroid_distance", 0.0))
	lines.append("")
	lines.append("Spatial Extent / Bounding Box")
	lines.append("  min x: %d" % snapshot.spatial_bbox_min_x)
	lines.append("  max x: %d" % snapshot.spatial_bbox_max_x)
	lines.append("  min y: %d" % snapshot.spatial_bbox_min_y)
	lines.append("  max y: %d" % snapshot.spatial_bbox_max_y)
	lines.append("  width: %d" % snapshot.spatial_bbox_width)
	lines.append("  height: %d" % snapshot.spatial_bbox_height)
	lines.append("  area: %d" % snapshot.spatial_bbox_area)
	lines.append("")
	lines.append("Corridors")
	lines.append("  count: %d" % snapshot.corridor_count)
	lines.append("  average length: %.1f" % snapshot.corridor_average_length)
	lines.append("  minimum length: %d" % snapshot.corridor_minimum_length)
	lines.append("  short corridors (<=3): %d" % snapshot.corridor_short_count)  # Frequency count only — not a quality judgment
	lines.append("  short rate: %.3f" % snapshot.corridor_short_rate)
	lines.append("")
	lines.append("Topology <-> Geometry")
	lines.append("  edge spatial length mean: %.1f" % snapshot.edge_spatial_length_mean)
	lines.append("  edge spatial length min: %.1f" % snapshot.edge_spatial_length_min)
	lines.append("  edge spatial length max: %.1f" % snapshot.edge_spatial_length_max)
	lines.append("  edge spatial length stddev: %.1f" % snapshot.edge_spatial_length_stddev)
	lines.append("")
	lines.append("Excentricity")
	lines.append("  goal to centroid distance: %.1f" % snapshot.goal_to_centroid_distance)
	lines.append("  boss to centroid distance: %.1f" % snapshot.boss_to_centroid_distance)
	lines.append("")
	lines.append("Validation")
	lines.append("  connectivity: %s" % snapshot.connectivity_status)
	lines.append("  room overlap: %s" % snapshot.validation_room_overlap)
	lines.append("")
	lines.append("Generation")
	lines.append("  success: %s" % snapshot.generation_success)
	return "".join(lines)

## Genera un resumen agregado a partir de múltiples snapshots.
func generate_summary(snapshots) -> Dictionary:
	var n: int = snapshots.size()
	if n == 0:
		return {}

	var summary: Dictionary = {}
	summary["seeds_evaluated"] = n
	summary["generations_successful"] = 0
	summary["generations_failed"] = 0

	var total_room_count: int = 0
	var total_connection_count: int = 0
	var total_corridor_count: int = 0
	var total_walkable: int = 0
	var total_reachable: int = 0
	var connectivity_pass_count: int = 0
	var overlap_pass_count: int = 0

	var total_radiality: float = 0.0
	var total_start_centrality: float = 0.0
	var total_angular_uniformity: float = 0.0
	var total_radial_variance: float = 0.0
	var total_dead_ends: int = 0
	var total_loops: int = 0
	var total_corridor_length: float = 0.0
	var total_short_corridors: int = 0
	var total_placement_tier_3: int = 0
	var total_placement_tier_4: int = 0
	var total_radiality_before: float = 0.0
	var total_radiality_after: float = 0.0

	var total_room_area_total: int = 0
	var total_room_fill_ratio: float = 0.0
	var total_nearest_neighbor_cv: float = 0.0
	var total_start_to_goal_spatial: float = 0.0
	var total_start_to_goal_path: float = 0.0
	var total_start_to_boss_spatial: float = 0.0
	var total_start_to_boss_path: float = 0.0
	var total_corridor_length_min: float = 0.0
	var total_corridor_length_p10: float = 0.0
	var total_corridor_length_p25: float = 0.0
	var total_corridor_length_median: float = 0.0
	var total_corridor_length_p75: float = 0.0
	var total_corridor_length_p90: float = 0.0
	var total_corridor_length_max: float = 0.0
	var total_corridor_length_stddev: float = 0.0
	var total_corridor_short_percentage: float = 0.0
	var total_edge_stretch_mean: float = 0.0
	var total_edge_stretch_min: float = 0.0
	var total_edge_stretch_max: float = 0.0
	var total_edge_stretch_stddev: float = 0.0
	var total_edge_spatial_length_mean: float = 0.0
	var total_edge_spatial_length_min: float = 0.0
	var total_edge_spatial_length_max: float = 0.0
	var total_edge_spatial_length_stddev: float = 0.0
	var total_corridor_short_rate: float = 0.0
	var total_goal_to_centroid: float = 0.0
	var total_boss_to_centroid: float = 0.0

	for snap in snapshots:
		if snap.generation_success == "PASS":
			summary["generations_successful"] += 1
		else:
			summary["generations_failed"] += 1
			continue  # Skip failed runs for quality/spatial/topology averages

		total_room_count += snap.room_count
		total_connection_count += snap.connection_count
		total_corridor_count += snap.corridor_count
		total_walkable += snap.connectivity_walkable_cells
		total_reachable += snap.connectivity_reachable_cells
		if snap.connectivity_status == "PASS":
			connectivity_pass_count += 1
		if snap.validation_room_overlap == "PASS":
			overlap_pass_count += 1

		total_radiality += snap.spatial_radiality_provisional
		total_start_centrality += snap.start_to_centroid_distance
		total_angular_uniformity += snap.spatial_angular_uniformity
		total_radial_variance += snap.spatial_radial_distance_variance
		total_dead_ends += snap.connection_dead_ends
		total_loops += snap.connection_loops
		total_corridor_length += snap.corridor_average_length
		total_short_corridors += snap.corridor_short_count
		total_placement_tier_3 += snap.placement_tier_3
		total_placement_tier_4 += snap.placement_tier_4
		total_radiality_before += snap.before_separator_metrics.get("spatial_radiality_provisional", 0.0)
		total_radiality_after += snap.after_separator_metrics.get("spatial_radiality_provisional", 0.0)
		total_room_area_total += snap.room_area_total
		total_room_fill_ratio += snap.room_fill_ratio
		total_nearest_neighbor_cv += snap.nearest_neighbor_cv
		total_start_to_goal_spatial += snap.start_to_goal_spatial_distance
		total_start_to_goal_path += snap.start_to_goal_path_distance
		total_start_to_boss_spatial += snap.start_to_boss_spatial_distance
		total_start_to_boss_path += snap.start_to_boss_path_distance
		total_corridor_length_min += snap.corridor_length_min
		total_corridor_length_p10 += snap.corridor_length_p10
		total_corridor_length_p25 += snap.corridor_length_p25
		total_corridor_length_median += snap.corridor_length_median
		total_corridor_length_p75 += snap.corridor_length_p75
		total_corridor_length_p90 += snap.corridor_length_p90
		total_corridor_length_max += snap.corridor_length_max
		total_corridor_length_stddev += snap.corridor_length_stddev
		total_corridor_short_percentage += snap.corridor_short_percentage
		total_edge_stretch_mean += snap.edge_stretch_mean
		total_edge_stretch_min += snap.edge_stretch_min
		total_edge_stretch_max += snap.edge_stretch_max
		total_edge_stretch_stddev += snap.edge_stretch_stddev
		total_edge_spatial_length_mean += snap.edge_spatial_length_mean
		total_edge_spatial_length_min += snap.edge_spatial_length_min
		total_edge_spatial_length_max += snap.edge_spatial_length_max
		total_edge_spatial_length_stddev += snap.edge_spatial_length_stddev
		total_corridor_short_rate += snap.corridor_short_rate
		total_goal_to_centroid += snap.goal_to_centroid_distance
		total_boss_to_centroid += snap.boss_to_centroid_distance

	var successful_count = summary["generations_successful"]
	summary["avg_rooms"] = float(total_room_count) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_connections"] = float(total_connection_count) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridors"] = float(total_corridor_count) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length"] = float(total_corridor_length) / float(successful_count) if successful_count > 0 else 0.0
	summary["connectivity_pass_rate"] = float(connectivity_pass_count) / float(successful_count) if successful_count > 0 else 0.0
	summary["overlap_pass_rate"] = float(overlap_pass_count) / float(successful_count) if successful_count > 0 else 0.0
	summary["walkable_cells_total"] = total_walkable
	summary["reachable_cells_total"] = total_reachable
	summary["avg_dead_ends"] = float(total_dead_ends) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_loops"] = float(total_loops) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_radiality"] = float(total_radiality) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_start_to_centroid_distance"] = float(total_start_centrality) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_angular_uniformity"] = float(total_angular_uniformity) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_radial_variance"] = float(total_radial_variance) / float(successful_count) if successful_count > 0 else 0.0
	summary["short_corridor_rate"] = float(total_short_corridors) / float(total_corridor_count) if total_corridor_count > 0 else 0.0
	summary["avg_placement_tier_3"] = float(total_placement_tier_3) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_placement_tier_4"] = float(total_placement_tier_4) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_radiality_before_separator"] = float(total_radiality_before) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_radiality_after_separator"] = float(total_radiality_after) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_room_area_total"] = float(total_room_area_total) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_room_fill_ratio"] = float(total_room_fill_ratio) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_nearest_neighbor_cv"] = float(total_nearest_neighbor_cv) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_start_to_goal_spatial_distance"] = float(total_start_to_goal_spatial) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_start_to_goal_path_distance"] = float(total_start_to_goal_path) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_start_to_boss_spatial_distance"] = float(total_start_to_boss_spatial) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_start_to_boss_path_distance"] = float(total_start_to_boss_path) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length_min"] = float(total_corridor_length_min) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length_p10"] = float(total_corridor_length_p10) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length_p25"] = float(total_corridor_length_p25) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length_median"] = float(total_corridor_length_median) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length_p75"] = float(total_corridor_length_p75) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length_p90"] = float(total_corridor_length_p90) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length_max"] = float(total_corridor_length_max) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_length_stddev"] = float(total_corridor_length_stddev) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_short_percentage"] = float(total_corridor_short_percentage) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_edge_stretch_mean"] = float(total_edge_stretch_mean) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_edge_stretch_min"] = float(total_edge_stretch_min) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_edge_stretch_max"] = float(total_edge_stretch_max) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_edge_stretch_stddev"] = float(total_edge_stretch_stddev) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_edge_spatial_length_mean"] = float(total_edge_spatial_length_mean) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_edge_spatial_length_min"] = float(total_edge_spatial_length_min) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_edge_spatial_length_max"] = float(total_edge_spatial_length_max) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_edge_spatial_length_stddev"] = float(total_edge_spatial_length_stddev) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_corridor_short_rate"] = float(total_corridor_short_rate) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_goal_to_centroid_distance"] = float(total_goal_to_centroid) / float(successful_count) if successful_count > 0 else 0.0
	summary["avg_boss_to_centroid_distance"] = float(total_boss_to_centroid) / float(successful_count) if successful_count > 0 else 0.0

	# ── Global percentiles across all corridors from all dungeons ──
	var all_corridor_lengths: Array[int] = []
	var all_edge_stretch_values: Array[float] = []
	for s in snapshots:
		if s.generation_success != "PASS":
			continue
		for cl in s.corridor_lengths:
			all_corridor_lengths.append(cl)
		for es in s.edge_stretch_values:
			all_edge_stretch_values.append(es)
	all_corridor_lengths.sort()
	all_edge_stretch_values.sort()
	summary["global_corridor_length_p10"] = _compute_percentile(all_corridor_lengths, 10.0)
	summary["global_corridor_length_p25"] = _compute_percentile(all_corridor_lengths, 25.0)
	summary["global_corridor_length_median"] = _compute_percentile(all_corridor_lengths, 50.0)
	summary["global_corridor_length_p75"] = _compute_percentile(all_corridor_lengths, 75.0)
	summary["global_corridor_length_p90"] = _compute_percentile(all_corridor_lengths, 90.0)
	summary["global_corridor_length_count"] = all_corridor_lengths.size()
	summary["global_edge_stretch_p10"] = _compute_percentile(all_edge_stretch_values, 10.0)
	summary["global_edge_stretch_p25"] = _compute_percentile(all_edge_stretch_values, 25.0)
	summary["global_edge_stretch_median"] = _compute_percentile(all_edge_stretch_values, 50.0)
	summary["global_edge_stretch_p75"] = _compute_percentile(all_edge_stretch_values, 75.0)
	summary["global_edge_stretch_p90"] = _compute_percentile(all_edge_stretch_values, 90.0)
	summary["global_edge_stretch_count"] = all_edge_stretch_values.size()

	return summary

## Ejecuta num_seeds generaciones desde seed_start, guarda cada snapshot como JSON
## y un summary.json con el peor caso de cada métrica diagnóstico.
func save_baseline(seed_start: int, num_seeds: int, output_dir: String) -> Dictionary:
	var seeds: Array[int] = []
	for i in range(num_seeds):
		seeds.append(seed_start + i)
	var snapshots = run_seeds(seeds)

	var worst_short_corridors_seed = 0
	var worst_short_corridors_val = -1.0
	var worst_radial_distance_variance_seed = 0
	var worst_radial_distance_variance_val = -1.0
	var worst_topology_seed = 0
	var worst_topology_val = -1
	var worst_topology_checksum_seed = 0
	var worst_topology_checksum_value = ""
	var highest_start_centrality_seed = 0
	var highest_start_centrality_val = -1.0
	var highest_angular_pattern_seed = 0
	var highest_angular_pattern_val = -1.0
	var worst_room_fill_ratio_seed = 0
	var worst_room_fill_ratio_val = -1.0
	var worst_nearest_neighbor_cv_seed = 0
	var worst_nearest_neighbor_cv_val = -1.0
	var worst_corridor_length_min_seed = 0
	var worst_corridor_length_min_val = 999999
	var worst_corridor_length_max_seed = 0
	var worst_corridor_length_max_val = -1
	var worst_corridor_short_percentage_seed = 0
	var worst_corridor_short_percentage_val = -1.0
	var worst_edge_stretch_mean_seed = 0
	var worst_edge_stretch_mean_val = -1.0
	var worst_edge_stretch_stddev_seed = 0
	var worst_edge_stretch_stddev_val = -1.0
	var highest_start_to_goal_spatial_seed = 0
	var highest_start_to_goal_spatial_val = -1.0
	var highest_start_to_boss_spatial_seed = 0
	var highest_start_to_boss_spatial_val = -1.0
	var worst_edge_spatial_length_min_seed = 0
	var worst_edge_spatial_length_min_val = 999999
	var worst_edge_spatial_length_max_seed = 0
	var worst_edge_spatial_length_max_val = -1.0
	var worst_edge_spatial_length_stddev_seed = 0
	var worst_edge_spatial_length_stddev_val = -1.0
	var worst_corridor_short_rate_seed = 0
	var worst_corridor_short_rate_val = -1.0
	var highest_goal_to_centroid_seed = 0
	var highest_goal_to_centroid_val = -1.0
	var highest_boss_to_centroid_seed = 0
	var highest_boss_to_centroid_val = -1.0
	var generation_failures = 0

	for snap in snapshots:
		var seed = snap.generation_seed_used
		var snap_dict = snap.to_dict()
		var json_str = JSON.stringify(snap_dict, "\t")

		var file_path = output_dir + "_seed_%d.json" % seed
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(json_str)
			file = null

		var short_rate = float(snap.corridor_short_count) / float(snap.corridor_count) if snap.corridor_count > 0 else 0.0
		if short_rate > worst_short_corridors_val:
			worst_short_corridors_val = short_rate
			worst_short_corridors_seed = seed

		if snap.spatial_radial_distance_variance > worst_radial_distance_variance_val:
			worst_radial_distance_variance_val = snap.spatial_radial_distance_variance
			worst_radial_distance_variance_seed = seed

		var topo_score = snap.connection_dead_ends + snap.connection_loops
		if topo_score > worst_topology_val:
			worst_topology_val = topo_score
			worst_topology_seed = seed
			worst_topology_checksum_seed = seed
			worst_topology_checksum_value = snap.generation_checksum

		if snap.start_to_centroid_distance > highest_start_centrality_val:
			highest_start_centrality_val = snap.start_to_centroid_distance
			highest_start_centrality_seed = seed

		if snap.spatial_angular_uniformity > highest_angular_pattern_val:
			highest_angular_pattern_val = snap.spatial_angular_uniformity
			highest_angular_pattern_seed = seed

		if snap.room_fill_ratio > worst_room_fill_ratio_val:
			worst_room_fill_ratio_val = snap.room_fill_ratio
			worst_room_fill_ratio_seed = seed
		if snap.nearest_neighbor_cv > worst_nearest_neighbor_cv_val:
			worst_nearest_neighbor_cv_val = snap.nearest_neighbor_cv
			worst_nearest_neighbor_cv_seed = seed
		if snap.corridor_length_min < worst_corridor_length_min_val:
			worst_corridor_length_min_val = snap.corridor_length_min
			worst_corridor_length_min_seed = seed
		if snap.corridor_length_max > worst_corridor_length_max_val:
			worst_corridor_length_max_val = snap.corridor_length_max
			worst_corridor_length_max_seed = seed
		if snap.corridor_short_percentage > worst_corridor_short_percentage_val:
			worst_corridor_short_percentage_val = snap.corridor_short_percentage
			worst_corridor_short_percentage_seed = seed
		if snap.edge_stretch_mean > worst_edge_stretch_mean_val:
			worst_edge_stretch_mean_val = snap.edge_stretch_mean
			worst_edge_stretch_mean_seed = seed
		if snap.edge_stretch_stddev > worst_edge_stretch_stddev_val:
			worst_edge_stretch_stddev_val = snap.edge_stretch_stddev
			worst_edge_stretch_stddev_seed = seed
		if snap.start_to_goal_spatial_distance > highest_start_to_goal_spatial_val:
			highest_start_to_goal_spatial_val = snap.start_to_goal_spatial_distance
			highest_start_to_goal_spatial_seed = seed
		if snap.start_to_boss_spatial_distance > highest_start_to_boss_spatial_val:
			highest_start_to_boss_spatial_val = snap.start_to_boss_spatial_distance
			highest_start_to_boss_spatial_seed = seed
		if snap.edge_spatial_length_min < worst_edge_spatial_length_min_val:
			worst_edge_spatial_length_min_val = snap.edge_spatial_length_min
			worst_edge_spatial_length_min_seed = seed
		if snap.edge_spatial_length_max > worst_edge_spatial_length_max_val:
			worst_edge_spatial_length_max_val = snap.edge_spatial_length_max
			worst_edge_spatial_length_max_seed = seed
		if snap.edge_spatial_length_stddev > worst_edge_spatial_length_stddev_val:
			worst_edge_spatial_length_stddev_val = snap.edge_spatial_length_stddev
			worst_edge_spatial_length_stddev_seed = seed
		if snap.corridor_short_rate > worst_corridor_short_rate_val:
			worst_corridor_short_rate_val = snap.corridor_short_rate
			worst_corridor_short_rate_seed = seed
		if snap.goal_to_centroid_distance > highest_goal_to_centroid_val:
			highest_goal_to_centroid_val = snap.goal_to_centroid_distance
			highest_goal_to_centroid_seed = seed
		if snap.boss_to_centroid_distance > highest_boss_to_centroid_val:
			highest_boss_to_centroid_val = snap.boss_to_centroid_distance
			highest_boss_to_centroid_seed = seed

		if snap.generation_success != "PASS":
			generation_failures += 1

	var summary = generate_summary(snapshots)
	summary["worst_short_corridors"] = {"seed": worst_short_corridors_seed, "value": worst_short_corridors_val}
	summary["highest_radial_distance_variance"] = {"seed": worst_radial_distance_variance_seed, "value": worst_radial_distance_variance_val}
	summary["worst_topology"] = {"seed": worst_topology_seed, "value": worst_topology_val}
	summary["worst_topology_checksum"] = {"seed": worst_topology_checksum_seed, "value": worst_topology_checksum_value}
	summary["highest_start_to_centroid_distance"] = {"seed": highest_start_centrality_seed, "value": highest_start_centrality_val}
	summary["highest_angular_pattern"] = {"seed": highest_angular_pattern_seed, "value": highest_angular_pattern_val}
	summary["worst_room_fill_ratio"] = {"seed": worst_room_fill_ratio_seed, "value": worst_room_fill_ratio_val}
	summary["worst_nearest_neighbor_cv"] = {"seed": worst_nearest_neighbor_cv_seed, "value": worst_nearest_neighbor_cv_val}
	summary["worst_corridor_length_min"] = {"seed": worst_corridor_length_min_seed, "value": worst_corridor_length_min_val}
	summary["worst_corridor_length_max"] = {"seed": worst_corridor_length_max_seed, "value": worst_corridor_length_max_val}
	summary["worst_corridor_short_percentage"] = {"seed": worst_corridor_short_percentage_seed, "value": worst_corridor_short_percentage_val}
	summary["worst_edge_stretch_mean"] = {"seed": worst_edge_stretch_mean_seed, "value": worst_edge_stretch_mean_val}
	summary["worst_edge_stretch_stddev"] = {"seed": worst_edge_stretch_stddev_seed, "value": worst_edge_stretch_stddev_val}
	summary["worst_edge_spatial_length_min"] = {"seed": worst_edge_spatial_length_min_seed, "value": worst_edge_spatial_length_min_val}
	summary["worst_edge_spatial_length_max"] = {"seed": worst_edge_spatial_length_max_seed, "value": worst_edge_spatial_length_max_val}
	summary["worst_edge_spatial_length_stddev"] = {"seed": worst_edge_spatial_length_stddev_seed, "value": worst_edge_spatial_length_stddev_val}
	summary["worst_corridor_short_rate"] = {"seed": worst_corridor_short_rate_seed, "value": worst_corridor_short_rate_val}
	summary["highest_goal_to_centroid_distance"] = {"seed": highest_goal_to_centroid_seed, "value": highest_goal_to_centroid_val}
	summary["highest_boss_to_centroid_distance"] = {"seed": highest_boss_to_centroid_seed, "value": highest_boss_to_centroid_val}
	summary["highest_start_to_goal_spatial_distance"] = {"seed": highest_start_to_goal_spatial_seed, "value": highest_start_to_goal_spatial_val}
	summary["highest_start_to_boss_spatial_distance"] = {"seed": highest_start_to_boss_spatial_seed, "value": highest_start_to_boss_spatial_val}
	summary["generation_failures"] = generation_failures

	var summary_json = JSON.stringify(summary, "\t")
	var summary_file = FileAccess.open(output_dir + "_summary.json", FileAccess.WRITE)
	if summary_file:
		summary_file.store_string(summary_json)
		summary_file = null

	return summary

## Construye un DungeonConfig con seed fijo para un valor dado.
static func build_config(seed: int) -> DungeonConfig:
	var cfg = _DungeonConfigScript.new()
	cfg.seed = seed
	cfg.use_fixed_seed = true
	cfg.apply_preset_standard()
	return cfg

## Computa métricas espaciales a partir de un array de rooms sintéticas.
## Útil para tests de sensibilidad sin necesidad de generar un dungeon completo.
func compute_spatial_metrics_from_rooms(rooms: Array[RoomData], config: DungeonConfig):
	var snap = _DungeonMetricSnapshotScript.new()
	snap.room_count = rooms.size()
	snap.room_type_distribution = {}
	for r in rooms:
		snap.room_type_distribution[r.room_type] = snap.room_type_distribution.get(r.room_type, 0) + 1
	_compute_overlap_count(snap, rooms)
	_compute_dungeon_bounds_area(snap, config)
	_compute_pairwise_spacing(snap, rooms)
	_compute_nearest_neighbor(snap, rooms)
	_compute_bounding_box(snap, rooms)
	_compute_spatial_metrics(snap, rooms)
	return snap

# ── Internal helpers ───────────────────────────

func _snapshot_from_result(result: DungeonResult, config: DungeonConfig):
	var snap = _DungeonMetricSnapshotScript.new()

	if result == null or result.rooms.is_empty():
		snap.generation_success = "FAIL"
		return snap

	snap.generation_time_ms = result.generation_time_ms
	snap.generation_checksum = result.checksum
	snap.generation_seed_used = result.seed_used
	snap.generation_success = "PASS"
	snap.room_count = result.rooms.size()
	snap.connection_count = result.connections.size()
	snap.corridor_count = result.corridor_paths.size()

	_compute_room_metrics(snap, result.rooms)
	_compute_connection_metrics(snap, result.rooms, result.connections)
	_compute_corridor_metrics(snap, result.corridor_paths)
	_compute_spatial_metrics(snap, result.rooms)
	_compute_bounding_box(snap, result.rooms)
	_compute_connectivity(snap, result.grid, result.rooms)
	snap.placement_tier_3 = result.placement_tier_3
	snap.placement_tier_4 = result.placement_tier_4
	snap.before_separator_metrics = result.before_separator_metrics
	if not result.rooms_before_separator.is_empty():
		var _before_spatial_snap := _DungeonMetricSnapshotScript.new()
		_compute_pairwise_spacing(_before_spatial_snap, result.rooms_before_separator)
		snap.before_pairwise_spacing_mean = _before_spatial_snap.pairwise_spacing_mean
		snap.before_pairwise_spacing_min = _before_spatial_snap.pairwise_spacing_min
		snap.before_pairwise_spacing_max = _before_spatial_snap.pairwise_spacing_max
		snap.before_pairwise_spacing_stddev = _before_spatial_snap.pairwise_spacing_stddev
		var _before_nn_snap := _DungeonMetricSnapshotScript.new()
		_compute_nearest_neighbor(_before_nn_snap, result.rooms_before_separator)
		snap.before_nearest_neighbor_mean = _before_nn_snap.nearest_neighbor_mean
		snap.before_nearest_neighbor_min = _before_nn_snap.nearest_neighbor_min
		snap.before_nearest_neighbor_max = _before_nn_snap.nearest_neighbor_max
		snap.before_nearest_neighbor_stddev = _before_nn_snap.nearest_neighbor_stddev
		snap.before_separator_metrics["pairwise_spacing_mean"] = snap.before_pairwise_spacing_mean
		snap.before_separator_metrics["pairwise_spacing_min"] = snap.before_pairwise_spacing_min
		snap.before_separator_metrics["pairwise_spacing_max"] = snap.before_pairwise_spacing_max
		snap.before_separator_metrics["pairwise_spacing_stddev"] = snap.before_pairwise_spacing_stddev
		snap.before_separator_metrics["nearest_neighbor_mean"] = snap.before_nearest_neighbor_mean
		snap.before_separator_metrics["nearest_neighbor_min"] = snap.before_nearest_neighbor_min
		snap.before_separator_metrics["nearest_neighbor_max"] = snap.before_nearest_neighbor_max
		snap.before_separator_metrics["nearest_neighbor_stddev"] = snap.before_nearest_neighbor_stddev
		if not _validate_metrics("before", snap.before_pairwise_spacing_mean, snap.before_separator_metrics.get("pairwise_spacing_mean", 0.0), snap.before_pairwise_spacing_stddev, snap.before_separator_metrics.get("pairwise_spacing_stddev", 0.0)):
			push_error("[DungeonDiagnostics] BEFORE separator metrics validation mismatch for seed %d" % result.seed_used)
	snap.after_separator_metrics = result.after_separator_metrics
	snap.rooms = result.rooms

	_compute_validation(snap, result.rooms)
	_compute_overlap_count(snap, result.rooms)
	_compute_dungeon_bounds_area(snap, config)
	_compute_pairwise_spacing(snap, result.rooms)
	_compute_nearest_neighbor(snap, result.rooms)
	snap.room_fill_ratio = float(snap.room_area_total) / float(snap.dungeon_bounds_area) if snap.dungeon_bounds_area > 0 else 0.0
	if snap.nearest_neighbor_mean > 0.0:
		snap.nearest_neighbor_cv = snap.nearest_neighbor_stddev / snap.nearest_neighbor_mean
	_compute_corridor_percentile_stats(snap, result.corridor_paths)
	_compute_edge_stretch(snap, result.rooms, result.connections, result.corridor_paths)
	_compute_edge_spatial_lengths(snap, result.rooms, result.connections)
	_compute_excentricity(snap, result.rooms)
	_compute_progression_metrics(snap, result.rooms, result.mission_graph)
	snap.corridor_short_rate = float(snap.corridor_short_count) / float(snap.corridor_count) if snap.corridor_count > 0 else 0.0
	_inject_metric_keys(snap)
	if not result.after_separator_metrics.is_empty():
		if not _validate_metrics("after", snap.pairwise_spacing_mean, result.after_separator_metrics.get("pairwise_spacing_mean", 0.0), snap.pairwise_spacing_stddev, result.after_separator_metrics.get("pairwise_spacing_stddev", 0.0)):
			push_error("[DungeonDiagnostics] AFTER separator metrics validation mismatch for seed %d" % result.seed_used)

	return snap

func _validate_metrics(label: String, mean_a: float, mean_b: float, stddev_a: float, stddev_b: float) -> bool:
	var m_ok: bool = abs(mean_a - mean_b) < 0.01
	var s_ok: bool = abs(stddev_a - stddev_b) < 0.01
	if not m_ok or not s_ok:
		push_error("[DungeonDiagnostics] %s metrics validation FAILED: mean %s vs %s, stddev %s vs %s" % [label, str(mean_a), str(mean_b), str(stddev_a), str(stddev_b)])
	return m_ok and s_ok

func _inject_metric_keys(snap) -> void:
	# Add pairwise_spacing_* and nearest_neighbor_* keys to before_separator_metrics
	# and after_separator_metrics dictionaries so that experiment_500_detailed.gd
	# and other consumers can read them via dictionary .get() lookups.
	# before_* fields are populated directly from rooms_before_separator
	# computation in _snapshot_from_result(), ensuring correct serialization.
	var before: Dictionary = snap.before_separator_metrics
	var after: Dictionary = snap.after_separator_metrics

	before["pairwise_spacing_mean"] = snap.before_pairwise_spacing_mean
	before["pairwise_spacing_min"] = snap.before_pairwise_spacing_min
	before["pairwise_spacing_max"] = snap.before_pairwise_spacing_max
	before["pairwise_spacing_stddev"] = snap.before_pairwise_spacing_stddev
	before["nearest_neighbor_mean"] = snap.before_nearest_neighbor_mean
	before["nearest_neighbor_min"] = snap.before_nearest_neighbor_min
	before["nearest_neighbor_max"] = snap.before_nearest_neighbor_max
	before["nearest_neighbor_stddev"] = snap.before_nearest_neighbor_stddev

	# after_separator_metrics: use computed snap values
	after["pairwise_spacing_mean"] = snap.pairwise_spacing_mean
	after["pairwise_spacing_min"] = snap.pairwise_spacing_min
	after["pairwise_spacing_max"] = snap.pairwise_spacing_max
	after["pairwise_spacing_stddev"] = snap.pairwise_spacing_stddev
	after["nearest_neighbor_mean"] = snap.nearest_neighbor_mean
	after["nearest_neighbor_min"] = snap.nearest_neighbor_min
	after["nearest_neighbor_max"] = snap.nearest_neighbor_max
	after["nearest_neighbor_stddev"] = snap.nearest_neighbor_stddev

func _compute_overlap_count(snap, rooms: Array[RoomData]) -> void:
	var count: int = 0
	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			if rooms[i].overlaps(rooms[j]):
				count += 1
	snap.overlap_count = count

func _compute_room_metrics(snap, rooms: Array[RoomData]) -> void:
	var total_area: int = 0
	var room_area_min: int = 999999
	var room_area_max: int = 0
	snap.room_type_distribution = {}
	for r in rooms:
		var a: int = r.get_area()
		total_area += a
		if a < room_area_min:
			room_area_min = a
		if a > room_area_max:
			room_area_max = a
		snap.room_type_distribution[r.room_type] = snap.room_type_distribution.get(r.room_type, 0) + 1
	snap.room_area_min = room_area_min
	snap.room_area_max = room_area_max
	snap.room_area_total = total_area
	snap.room_average_area = float(total_area) / float(rooms.size()) if rooms.size() > 0 else 0.0

func _compute_connection_metrics(snap, rooms: Array[RoomData], connections: Array) -> void:
	if rooms.is_empty():
		snap.connection_average_degree = 0.0
		snap.connection_dead_ends = 0
		snap.connection_loops = 0
		return

	var degree: Dictionary = {}
	for r in rooms:
		degree[r.id] = 0

	# Filter null connections and build adjacency list
	var valid_connections: Array = []
	for c in connections:
		if c == null:
			continue
		valid_connections.append(c)
		if degree.has(c.room_a_id):
			degree[c.room_a_id] += 1
		if degree.has(c.room_b_id):
			degree[c.room_b_id] += 1

	# Build adjacency list for connected components
	var adjacency: Dictionary = {}
	for r in rooms:
		adjacency[r.id] = []
	for c in valid_connections:
		adjacency[c.room_a_id].append(c.room_b_id)
		adjacency[c.room_b_id].append(c.room_a_id)

	# Count connected components via BFS
	var visited: Dictionary = {}
	var num_components: int = 0
	for r in rooms:
		if not visited.has(r.id):
			num_components += 1
			var queue: Array = [r.id]
			visited[r.id] = true
			while not queue.is_empty():
				var current = queue.pop_front()
				for neighbor in adjacency[current]:
					if not visited.has(neighbor):
						visited[neighbor] = true
						queue.append(neighbor)

	# Cycle rank: loops = E - V + C
	var v: int = rooms.size()
	var e: int = valid_connections.size()
	snap.connection_loops = maxi(e - v + num_components, 0)

	var total_degree: int = 0
	var dead_ends: int = 0
	for d in degree.values():
		total_degree += d
		if d == 1:
			dead_ends += 1

	snap.connection_dead_ends = dead_ends
	snap.connection_average_degree = float(total_degree) / float(degree.size()) if degree.size() > 0 else 0.0

func _compute_corridor_metrics(snap, corridor_paths: Array) -> void:
	if corridor_paths.is_empty():
		snap.corridor_average_length = 0.0
		snap.corridor_minimum_length = 0
		snap.corridor_short_count = 0
		snap.corridor_lengths.clear()
		return

	var total_len: int = 0
	var min_len: int = 999999
	var short_count: int = 0
	snap.corridor_lengths.clear()
	for p in corridor_paths:
		if p == null:
			continue
		var length: int = p.centerline_cells.size()
		total_len += length
		snap.corridor_lengths.append(length)
		if length < min_len:
			min_len = length
		if length <= 3:
			short_count += 1

	snap.corridor_average_length = float(total_len) / float(corridor_paths.size()) if corridor_paths.size() > 0 else 0.0
	snap.corridor_minimum_length = min_len if min_len < 999999 else 0
	snap.corridor_short_count = short_count

func _compute_spatial_metrics(snap, rooms: Array[RoomData]) -> void:
	if rooms.size() < 2:
		snap.spatial_average_center_distance = 0.0
		snap.spatial_minimum_center_distance = 0.0
		snap.start_to_centroid_distance = 0.0
		snap.spatial_angular_uniformity = 0.0
		snap.spatial_radial_distance_variance = 0.0
		snap.spatial_radiality_provisional = 0.0
		return

	var centers: Array[Vector2i] = []
	var start_center: Vector2i
	var start_found: bool = false
	for r in rooms:
		centers.append(r.get_center())
		if not start_found and r.room_type == &"start":
			start_center = r.get_center()
			start_found = true

	if not start_found:
		start_center = centers[0]

	# Pairwise distances
	var distances: Array[float] = []
	var min_dist: float = 1e9
	for i in range(centers.size()):
		for j in range(i + 1, centers.size()):
			var d: float = centers[i].distance_to(centers[j])
			distances.append(d)
			if d < min_dist:
				min_dist = d

	snap.spatial_average_center_distance = float(_sum_array(distances)) / float(distances.size()) if distances.size() > 0 else 0.0
	snap.spatial_minimum_center_distance = min_dist if min_dist < 1e9 else 0.0

	# Start centrality: distance from start room center to centroid of all rooms
	var centroid: Vector2i = _compute_centroid(centers)
	snap.start_to_centroid_distance = start_center.distance_to(centroid)

	# Angular uniformity: circular variance around START
	var angles: Array[float] = []
	for c in centers:
		if c == start_center:
			continue
		angles.append(atan2(float(c.y - start_center.y), float(c.x - start_center.x)))

	if angles.size() > 0:
		var sum_cos: float = 0.0
		var sum_sin: float = 0.0
		for a in angles:
			sum_cos += cos(a)
			sum_sin += sin(a)
		var mean_resultant: float = sqrt(sum_cos * sum_cos + sum_sin * sum_sin) / float(angles.size())
		snap.spatial_angular_uniformity = 1.0 - mean_resultant
	else:
		snap.spatial_angular_uniformity = 0.0

	# Radial distance variance: variance of distances from START to rooms
	var radial_dists: Array[float] = []
	for c in centers:
		if c == start_center:
			continue
		radial_dists.append(start_center.distance_to(c))

	if radial_dists.size() > 0:
		var mean_r: float = float(_sum_array(radial_dists)) / float(radial_dists.size())
		var var_r: float = 0.0
		for d in radial_dists:
			var_r += (d - mean_r) * (d - mean_r)
		var_r /= float(radial_dists.size())
		snap.spatial_radial_distance_variance = var_r
	else:
		snap.spatial_radial_distance_variance = 0.0

	# Provisional radiality (MVP-0): simple average of normalized raw measurements.
	snap.spatial_radiality_provisional = _compute_provisional_radiality(snap)

func _compute_provisional_radiality(snap) -> float:
	# DIAGNOSTIC ONLY — not a canonical metric.
	# Normalizes three spatial measurements to [0,1] with empirical thresholds
	# and averages them. Mixed magnitudes with arbitrary thresholds.
	# Do NOT use for baseline decisions or comparisons.
	var c_norm: float = minf(snap.start_to_centroid_distance / 20.0, 1.0)
	var a_norm: float = snap.spatial_angular_uniformity  # already in [0, 1]
	var v_norm: float = minf(snap.spatial_radial_distance_variance / 100.0, 1.0)
	return (c_norm + a_norm + v_norm) / 3.0

func _compute_connectivity(snap, grid: CellGrid, rooms: Array[RoomData]) -> void:
	if grid == null or rooms.is_empty():
		snap.connectivity_status = "FAIL"
		snap.connectivity_walkable_cells = 0
		snap.connectivity_reachable_cells = 0
		return

	snap.connectivity_walkable_cells = grid.count_walkable_cells()

	# Find start room center for BFS origin
	var start_pos: Vector2i
	var start_found: bool = false
	for r in rooms:
		if r.room_type == &"start":
			start_pos = r.get_center()
			start_found = true
			break

	if not start_found:
		start_pos = Vector2i(0, 0)
		for y in range(grid.height):
			for x in range(grid.width):
				if grid.is_walkable(Vector2i(x, y)):
					start_pos = Vector2i(x, y)
					start_found = true
					break
			if start_found:
				break

	if not grid.is_in_bounds(start_pos):
		snap.connectivity_status = "FAIL"
		return

	# BFS flood-fill on walkable cells
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_pos]
	visited[start_pos] = true
	var count: int = 0

	while not queue.is_empty():
		var current = queue.pop_front()
		if not grid.is_in_bounds(current):
			continue
		if not grid.is_walkable(current):
			continue
		count += 1
		for neighbor in grid.get_neighbors_4(current):
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)

	snap.connectivity_reachable_cells = count
	if snap.connectivity_reachable_cells >= snap.connectivity_walkable_cells:
		snap.connectivity_status = "PASS"
	else:
		snap.connectivity_status = "FAIL"

func _compute_validation(snap, rooms: Array[RoomData]) -> void:
	if rooms.size() < 2:
		snap.validation_room_overlap = "PASS"
		return

	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			if rooms[i].overlaps(rooms[j]):
				snap.validation_room_overlap = "FAIL"
				return
	snap.validation_room_overlap = "PASS"

func _compute_dungeon_bounds_area(snap, config: DungeonConfig) -> void:
	snap.dungeon_bounds_area = config.grid_width * config.grid_height

func _compute_centroid(centers: Array[Vector2i]) -> Vector2i:
	if centers.is_empty():
		return Vector2i.ZERO
	var sum_x: int = 0
	var sum_y: int = 0
	for c in centers:
		sum_x += c.x
		sum_y += c.y
	return Vector2i(roundf(float(sum_x) / float(centers.size())), roundf(float(sum_y) / float(centers.size())))

func _compute_pairwise_spacing(snap, rooms: Array[RoomData]) -> void:
	if rooms.size() < 2:
		snap.pairwise_spacing_mean = 0.0
		snap.pairwise_spacing_min = 0.0
		snap.pairwise_spacing_max = 0.0
		snap.pairwise_spacing_stddev = 0.0
		return
	var distances: Array[float] = []
	for i in range(rooms.size()):
		var c1 := rooms[i].get_center()
		for j in range(i + 1, rooms.size()):
			var c2 := rooms[j].get_center()
			var dx: int = c2.x - c1.x
			var dy: int = c2.y - c1.y
			distances.append(sqrt(float(dx * dx + dy * dy)))
	var n: int = distances.size()
	if n == 0:
		snap.pairwise_spacing_mean = 0.0
		snap.pairwise_spacing_min = 0.0
		snap.pairwise_spacing_max = 0.0
		snap.pairwise_spacing_stddev = 0.0
		return
	var s: float = _sum_array(distances)
	var mean: float = s / float(n)
	var mn: float = distances[0]
	var mx: float = distances[0]
	for d in distances:
		if d < mn: mn = d
		if d > mx: mx = d
	var variance: float = 0.0
	for d in distances:
		variance += (d - mean) * (d - mean)
	variance /= float(n)
	snap.pairwise_spacing_mean = mean
	snap.pairwise_spacing_min = mn
	snap.pairwise_spacing_max = mx
	snap.pairwise_spacing_stddev = sqrt(variance)

func _compute_nearest_neighbor(snap, rooms: Array[RoomData]) -> void:
	if rooms.size() < 2:
		snap.nearest_neighbor_mean = 0.0
		snap.nearest_neighbor_min = 0.0
		snap.nearest_neighbor_max = 0.0
		snap.nearest_neighbor_stddev = 0.0
		return
	var nn_distances: Array[float] = []
	for i in range(rooms.size()):
		var c1 := rooms[i].get_center()
		var nn: float = 1e9
		for j in range(rooms.size()):
			if i == j: continue
			var c2 := rooms[j].get_center()
			var dx: int = c2.x - c1.x
			var dy: int = c2.y - c1.y
			var d: float = sqrt(float(dx * dx + dy * dy))
			if d < nn: nn = d
		nn_distances.append(nn)
	var n: int = nn_distances.size()
	if n == 0:
		snap.nearest_neighbor_mean = 0.0
		snap.nearest_neighbor_min = 0.0
		snap.nearest_neighbor_max = 0.0
		snap.nearest_neighbor_stddev = 0.0
		return
	var s: float = _sum_array(nn_distances)
	var mean: float = s / float(n)
	var mn: float = nn_distances[0]
	var mx: float = nn_distances[0]
	for d in nn_distances:
		if d < mn: mn = d
		if d > mx: mx = d
	var variance: float = 0.0
	for d in nn_distances:
		variance += (d - mean) * (d - mean)
	variance /= float(n)
	snap.nearest_neighbor_mean = mean
	snap.nearest_neighbor_min = mn
	snap.nearest_neighbor_max = mx
	snap.nearest_neighbor_stddev = sqrt(variance)

func _compute_bounding_box(snap, rooms: Array[RoomData]) -> void:
	if rooms.is_empty():
		snap.spatial_bbox_min_x = 0
		snap.spatial_bbox_max_x = 0
		snap.spatial_bbox_min_y = 0
		snap.spatial_bbox_max_y = 0
		snap.spatial_bbox_width = 0
		snap.spatial_bbox_height = 0
		snap.spatial_bbox_area = 0
		return

	var min_x: int = 999999
	var max_x: int = -999999
	var min_y: int = 999999
	var max_y: int = -999999

	for r in rooms:
		min_x = mini(min_x, r.rect.position.x)
		max_x = maxi(max_x, r.rect.end.x)
		min_y = mini(min_y, r.rect.position.y)
		max_y = maxi(max_y, r.rect.end.y)

	snap.spatial_bbox_min_x = min_x
	snap.spatial_bbox_max_x = max_x
	snap.spatial_bbox_min_y = min_y
	snap.spatial_bbox_max_y = max_y
	snap.spatial_bbox_width = max_x - min_x
	snap.spatial_bbox_height = max_y - min_y
	snap.spatial_bbox_area = snap.spatial_bbox_width * snap.spatial_bbox_height

static func _compute_percentile(sorted_arr: Array, p: float) -> float:
	if sorted_arr.is_empty():
		return 0.0
	var idx: float = p / 100.0 * float(sorted_arr.size() - 1)
	var lower: int = int(idx)
	var upper: int = mini(lower + 1, sorted_arr.size() - 1)
	var frac: float = idx - float(lower)
	return float(sorted_arr[lower]) * (1.0 - frac) + float(sorted_arr[upper]) * frac

func _compute_corridor_percentile_stats(snap, corridor_paths: Array) -> void:
	if corridor_paths.is_empty():
		snap.corridor_length_min = 0
		snap.corridor_length_p10 = 0
		snap.corridor_length_p25 = 0
		snap.corridor_length_median = 0
		snap.corridor_length_p75 = 0
		snap.corridor_length_p90 = 0
		snap.corridor_length_max = 0
		snap.corridor_length_stddev = 0.0
		snap.corridor_short_percentage = 0.0
		return

	var lengths: Array[int] = []
	var short_count: int = 0
	for p in corridor_paths:
		if p == null:
			continue
		var l: int = p.centerline_cells.size()
		lengths.append(l)
		if l <= 3:
			short_count += 1

	lengths.sort()
	var n: int = lengths.size()
	snap.corridor_length_min = lengths[0]
	snap.corridor_length_p10 = int(_compute_percentile(lengths, 10.0))
	snap.corridor_length_p25 = int(_compute_percentile(lengths, 25.0))
	snap.corridor_length_median = int(_compute_percentile(lengths, 50.0))
	snap.corridor_length_p75 = int(_compute_percentile(lengths, 75.0))
	snap.corridor_length_p90 = int(_compute_percentile(lengths, 90.0))
	snap.corridor_length_max = lengths[n - 1]
	snap.corridor_short_percentage = float(short_count) / float(n) if n > 0 else 0.0

	var mean_len: float = float(_sum_array(lengths)) / float(n)
	var variance: float = 0.0
	for l in lengths:
		variance += float((l - mean_len) * (l - mean_len))
	variance /= float(n)
	snap.corridor_length_stddev = sqrt(variance)

func _compute_edge_stretch(snap, rooms: Array[RoomData], connections: Array, corridor_paths: Array) -> void:
	if rooms.is_empty() or corridor_paths.is_empty():
		snap.edge_stretch_mean = 0.0
		snap.edge_stretch_min = 0.0
		snap.edge_stretch_max = 0.0
		snap.edge_stretch_stddev = 0.0
		snap.edge_stretch_values = []
		return

	var corridor_map: Dictionary = {}
	for p in corridor_paths:
		if p == null:
			continue
		corridor_map[p.connection_id] = p

	var stretches: Array[float] = []
	for c in connections:
		if c == null:
			continue
		if not corridor_map.has(c.id):
			continue
		var cp: CorridorPath = corridor_map[c.id]
		if cp == null or cp.centerline_cells.is_empty():
			continue
		var room_a: RoomData = null
		var room_b: RoomData = null
		for r in rooms:
			if r.id == c.room_a_id:
				room_a = r
			if r.id == c.room_b_id:
				room_b = r
		if room_a == null or room_b == null:
			continue
		var euclidean_dist: float = room_a.get_center().distance_to(room_b.get_center())
		if euclidean_dist <= 0.0:
			continue
		var path_length: float = float(cp.centerline_cells.size())
		stretches.append(path_length / euclidean_dist)

	if stretches.is_empty():
		snap.edge_stretch_mean = 0.0
		snap.edge_stretch_min = 0.0
		snap.edge_stretch_max = 0.0
		snap.edge_stretch_stddev = 0.0
		snap.edge_stretch_values = []
		return

	snap.edge_stretch_values = stretches
	var s: float = _sum_array(stretches)
	snap.edge_stretch_mean = s / float(stretches.size())
	snap.edge_stretch_min = stretches[0]
	snap.edge_stretch_max = stretches[0]
	for st in stretches:
		if st < snap.edge_stretch_min:
			snap.edge_stretch_min = st
		if st > snap.edge_stretch_max:
			snap.edge_stretch_max = st
	var variance: float = 0.0
	for st in stretches:
		variance += (st - snap.edge_stretch_mean) * (st - snap.edge_stretch_mean)
	variance /= float(stretches.size())
	snap.edge_stretch_stddev = sqrt(variance)

func _compute_edge_spatial_lengths(snap, rooms: Array[RoomData], connections: Array) -> void:
	if rooms.is_empty() or connections.is_empty():
		snap.edge_spatial_length_mean = 0.0
		snap.edge_spatial_length_min = 0.0
		snap.edge_spatial_length_max = 0.0
		snap.edge_spatial_length_stddev = 0.0
		return

	var spatial_lengths: Array[float] = []
	for c in connections:
		if c == null:
			continue
		var room_a: RoomData = null
		var room_b: RoomData = null
		for r in rooms:
			if r.id == c.room_a_id:
				room_a = r
			if r.id == c.room_b_id:
				room_b = r
		if room_a == null or room_b == null:
			continue
		var euclidean_dist: float = room_a.get_center().distance_to(room_b.get_center())
		if euclidean_dist <= 0.0:
			continue
		spatial_lengths.append(euclidean_dist)

	if spatial_lengths.is_empty():
		snap.edge_spatial_length_mean = 0.0
		snap.edge_spatial_length_min = 0.0
		snap.edge_spatial_length_max = 0.0
		snap.edge_spatial_length_stddev = 0.0
		return

	var s: float = _sum_array(spatial_lengths)
	snap.edge_spatial_length_mean = s / float(spatial_lengths.size())
	snap.edge_spatial_length_min = spatial_lengths[0]
	snap.edge_spatial_length_max = spatial_lengths[0]
	for sl in spatial_lengths:
		if sl < snap.edge_spatial_length_min:
			snap.edge_spatial_length_min = sl
		if sl > snap.edge_spatial_length_max:
			snap.edge_spatial_length_max = sl
	var variance: float = 0.0
	for sl in spatial_lengths:
		variance += (sl - snap.edge_spatial_length_mean) * (sl - snap.edge_spatial_length_mean)
	variance /= float(spatial_lengths.size())
	snap.edge_spatial_length_stddev = sqrt(variance)

func _compute_excentricity(snap, rooms: Array[RoomData]) -> void:
	if rooms.is_empty():
		snap.goal_to_centroid_distance = 0.0
		snap.boss_to_centroid_distance = 0.0
		return

	var centers: Array[Vector2i] = []
	var goal_center: Vector2i
	var boss_center: Vector2i
	var goal_found: bool = false
	var boss_found: bool = false
	for r in rooms:
		centers.append(r.get_center())
		if not goal_found and r.room_type == &"goal":
			goal_center = r.get_center()
			goal_found = true
		if not boss_found and r.room_type == &"boss":
			boss_center = r.get_center()
			boss_found = true

	if not goal_found and not boss_found:
		snap.goal_to_centroid_distance = 0.0
		snap.boss_to_centroid_distance = 0.0
		return

	var centroid: Vector2i = _compute_centroid(centers)

	if goal_found:
		snap.goal_to_centroid_distance = goal_center.distance_to(centroid)
	else:
		snap.goal_to_centroid_distance = 0.0

	if boss_found:
		snap.boss_to_centroid_distance = boss_center.distance_to(centroid)
	else:
		snap.boss_to_centroid_distance = 0.0

func _compute_progression_metrics(snap, rooms: Array[RoomData], mission_graph: DungeonGraph) -> void:
	var start_room: RoomData = null
	var goal_room: RoomData = null
	var boss_room: RoomData = null
	for r in rooms:
		if r.room_type == &"start":
			start_room = r
		elif r.room_type == &"goal":
			goal_room = r
		elif r.room_type == &"boss":
			boss_room = r

	if start_room == null:
		snap.start_to_goal_spatial_distance = 0.0
		snap.start_to_goal_path_distance = 0.0
		snap.start_to_boss_spatial_distance = 0.0
		snap.start_to_boss_path_distance = 0.0
		return

	if goal_room != null:
		snap.start_to_goal_spatial_distance = start_room.get_center().distance_to(goal_room.get_center())
		if mission_graph != null and mission_graph.has_node(start_room.mission_node_id) and mission_graph.has_node(goal_room.mission_node_id):
			var path: Array[int] = mission_graph.get_shortest_path(start_room.mission_node_id, goal_room.mission_node_id)
			snap.start_to_goal_path_distance = float(path.size() - 1) if path.size() > 0 else 0.0
		else:
			snap.start_to_goal_path_distance = 0.0
	else:
		snap.start_to_goal_spatial_distance = 0.0
		snap.start_to_goal_path_distance = 0.0

	if boss_room != null:
		snap.start_to_boss_spatial_distance = start_room.get_center().distance_to(boss_room.get_center())
		if mission_graph != null and mission_graph.has_node(start_room.mission_node_id) and mission_graph.has_node(boss_room.mission_node_id):
			var path: Array[int] = mission_graph.get_shortest_path(start_room.mission_node_id, boss_room.mission_node_id)
			snap.start_to_boss_path_distance = float(path.size() - 1) if path.size() > 0 else 0.0
		else:
			snap.start_to_boss_path_distance = 0.0
	else:
		snap.start_to_boss_spatial_distance = 0.0
		snap.start_to_boss_path_distance = 0.0

static func _sum_array(arr: Array) -> float:
	var s: float = 0.0
	for v in arr:
		s += float(v)
	return s
