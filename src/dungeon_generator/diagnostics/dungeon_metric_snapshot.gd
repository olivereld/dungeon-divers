extends RefCounted

## Captura de métricas de una sola ejecución del generador (un seed).
## Todas las mediciones provienen directamente de DungeonResult.

# ── Rooms ──────────────────────────────────────────────
var room_count: int = 0
var rooms: Array[RoomData] = []
var room_average_area: float = 0.0
var room_area_min: int = 0
var room_area_max: int = 0
var room_type_distribution: Dictionary = {}

# ── Connections ────────────────────────────────────────
var connection_count: int = 0
var connection_average_degree: float = 0.0
var connection_dead_ends: int = 0
var connection_loops: int = 0

# ── Corridors ──────────────────────────────────────────
var corridor_count: int = 0
var corridor_average_length: float = 0.0
var corridor_minimum_length: int = 0
var corridor_short_count: int = 0  # Frequency count of corridors <=3 cells (MVP-0 diagnostic only — NOT a quality judgment)

# ── Spatial ────────────────────────────────────────────
var spatial_average_center_distance: float = 0.0
var spatial_minimum_center_distance: float = 0.0
var start_to_centroid_distance: float = 0.0
# BASELINE OBSERVATION: `start` rooms exhibit different `profile` values
# (`entrance`, `sacristy`, `none`). If start rooms have special spatial/topological
# implications for radiality, this must be understood before interpreting the metric.
# Do not interpret radiality without noting the start room profile.
var spatial_angular_uniformity: float = 0.0
var spatial_radial_distance_variance: float = 0.0

# ── Spatial Extent / Bounding Box ────────────────────
# Covers all rooms via their Rect2i bounds.
var spatial_bbox_min_x: int = 0
var spatial_bbox_max_x: int = 0
var spatial_bbox_min_y: int = 0
var spatial_bbox_max_y: int = 0
var spatial_bbox_width: int = 0
var spatial_bbox_height: int = 0
var spatial_bbox_area: int = 0

# ── Radiality (provisional MVP-0) ────────────────────
# PROVISIONAL / DIAGNOSTIC ONLY — NOT A CANONICAL METRIC.
# Promedio de tres mediciones espaciales normalizadas con umbrales empíricos.
# NO usar para tomar decisiones ni comparar líneas base.
# Solo para inspección rápida del baseline hasta que se defina
# un composite definitivo en fases posteriores.
var spatial_radiality_provisional: float = 0.0

# ── Placement Tier Distribution ──────────────────
var placement_tier_3: int = 0
var placement_tier_4: int = 0
var before_separator_metrics: Dictionary = {}
var after_separator_metrics: Dictionary = {}

# ── Extended Spatial Metrics ───────────────────────
var dungeon_bounds_area: int = 0
var overlap_count: int = 0
var pairwise_spacing_mean: float = 0.0
var pairwise_spacing_min: float = 0.0
var pairwise_spacing_max: float = 0.0
var pairwise_spacing_stddev: float = 0.0
var nearest_neighbor_mean: float = 0.0
var nearest_neighbor_min: float = 0.0
var nearest_neighbor_max: float = 0.0
var nearest_neighbor_stddev: float = 0.0

# ── Before-Separator Spatial Metrics (explicit) ────
var before_pairwise_spacing_mean: float = 0.0
var before_pairwise_spacing_min: float = 0.0
var before_pairwise_spacing_max: float = 0.0
var before_pairwise_spacing_stddev: float = 0.0
var before_nearest_neighbor_mean: float = 0.0
var before_nearest_neighbor_min: float = 0.0
var before_nearest_neighbor_max: float = 0.0
var before_nearest_neighbor_stddev: float = 0.0

# ── MVP-1.1: Spatial Extremes ───────────────────────
var room_area_total: int = 0
var room_fill_ratio: float = 0.0

# ── MVP-1.1: Nearest Neighbor CV ─────────────────────
var nearest_neighbor_cv: float = 0.0

# ── MVP-1.1: Progression Metrics ─────────────────────
var start_to_goal_spatial_distance: float = 0.0
var start_to_goal_path_distance: float = 0.0
var start_to_boss_spatial_distance: float = 0.0
var start_to_boss_path_distance: float = 0.0

# ── MVP-1.1: Corridor Percentile Stats ───────────────
var corridor_length_min: int = 0
var corridor_length_p10: int = 0
var corridor_length_p25: int = 0
var corridor_length_median: int = 0
var corridor_length_p75: int = 0
var corridor_length_p90: int = 0
var corridor_length_max: int = 0
var corridor_length_stddev: float = 0.0
var corridor_short_percentage: float = 0.0
var corridor_short_rate: float = 0.0  # short_count / corridor_count — own field on snapshot

# New: raw arrays (Phase 1 will use these for global percentiles)
var corridor_lengths: Array = []

# ── MVP-1.1: Graph ↔ Space (Edge Stretch) ────────────
var edge_stretch_mean: float = 0.0
var edge_stretch_min: float = 0.0
var edge_stretch_max: float = 0.0
var edge_stretch_stddev: float = 0.0

# Raw per-edge values for diagnostic/aggregation purposes
var edge_stretch_values: Array = []

# ── MVP-1.1: Edge Spatial Length (topology ↔ geometry) ──
var edge_spatial_length_mean: float = 0.0
var edge_spatial_length_min: float = 0.0
var edge_spatial_length_max: float = 0.0
var edge_spatial_length_stddev: float = 0.0

# ── MVP-1.1: Excentricity (goal/boss distance to centroid) ──
var goal_to_centroid_distance: float = 0.0
var boss_to_centroid_distance: float = 0.0

# ── Connectivity (CellGrid flood-fill) ─────────────────
var connectivity_status: String = "FAIL"
var connectivity_walkable_cells: int = 0
var connectivity_reachable_cells: int = 0

# ── Validation ─────────────────────────────────────────
var validation_room_overlap: String = "FAIL"

# ── Generation ─────────────────────────────────────────
var generation_success: String = "FAIL"
var generation_seed_used: int = 0
var generation_time_ms: float = 0.0
var generation_checksum: String = ""

func to_dict() -> Dictionary:
	return {
		"room_count": room_count,
		"room_type_distribution": room_type_distribution,
		"room_average_area": roundf(room_average_area * 100.0) / 100.0,
		"room_area_min": room_area_min,
		"room_area_max": room_area_max,
		"connection_count": connection_count,
		"connection_average_degree": roundf(connection_average_degree * 100.0) / 100.0,
		"connection_dead_ends": connection_dead_ends,
		"connection_loops": connection_loops,
		"corridor_count": corridor_count,
		"corridor_average_length": roundf(corridor_average_length * 100.0) / 100.0,
		"corridor_minimum_length": corridor_minimum_length,
		"corridor_short_count": corridor_short_count,
		"spatial_average_center_distance": roundf(spatial_average_center_distance * 100.0) / 100.0,
		"spatial_minimum_center_distance": roundf(spatial_minimum_center_distance * 100.0) / 100.0,
		"start_to_centroid_distance": roundf(start_to_centroid_distance * 100.0) / 100.0,
		"spatial_angular_uniformity": roundf(spatial_angular_uniformity * 100.0) / 100.0,
		"spatial_radial_distance_variance": roundf(spatial_radial_distance_variance * 100.0) / 100.0,
		"spatial_bbox_min_x": spatial_bbox_min_x,
		"spatial_bbox_max_x": spatial_bbox_max_x,
		"spatial_bbox_min_y": spatial_bbox_min_y,
		"spatial_bbox_max_y": spatial_bbox_max_y,
		"spatial_bbox_width": spatial_bbox_width,
		"spatial_bbox_height": spatial_bbox_height,
		"spatial_bbox_area": spatial_bbox_area,
		"spatial_radiality_provisional": roundf(spatial_radiality_provisional * 100.0) / 100.0,
		"room_area_total": room_area_total,
		"room_fill_ratio": roundf(room_fill_ratio * 100.0) / 100.0,
		"nearest_neighbor_cv": roundf(nearest_neighbor_cv * 100.0) / 100.0,
		"start_to_goal_spatial_distance": roundf(start_to_goal_spatial_distance * 100.0) / 100.0,
		"start_to_goal_path_distance": roundf(start_to_goal_path_distance * 100.0) / 100.0,
		"start_to_boss_spatial_distance": roundf(start_to_boss_spatial_distance * 100.0) / 100.0,
		"start_to_boss_path_distance": roundf(start_to_boss_path_distance * 100.0) / 100.0,
		"corridor_length_min": corridor_length_min,
		"corridor_length_p10": corridor_length_p10,
		"corridor_length_p25": corridor_length_p25,
		"corridor_length_median": corridor_length_median,
		"corridor_length_p75": corridor_length_p75,
		"corridor_length_p90": corridor_length_p90,
		"corridor_length_max": corridor_length_max,
		"corridor_length_stddev": roundf(corridor_length_stddev * 100.0) / 100.0,
		"corridor_short_percentage": roundf(corridor_short_percentage * 100.0) / 100.0,
		"corridor_short_rate": roundf(corridor_short_rate * 100.0) / 100.0,
		"edge_stretch_mean": roundf(edge_stretch_mean * 100.0) / 100.0,
		"edge_stretch_min": roundf(edge_stretch_min * 100.0) / 100.0,
		"edge_stretch_max": roundf(edge_stretch_max * 100.0) / 100.0,
		"edge_stretch_stddev": roundf(edge_stretch_stddev * 100.0) / 100.0,
		"edge_spatial_length_mean": roundf(edge_spatial_length_mean * 100.0) / 100.0,
		"edge_spatial_length_min": roundf(edge_spatial_length_min * 100.0) / 100.0,
		"edge_spatial_length_max": roundf(edge_spatial_length_max * 100.0) / 100.0,
		"edge_spatial_length_stddev": roundf(edge_spatial_length_stddev * 100.0) / 100.0,
		"goal_to_centroid_distance": roundf(goal_to_centroid_distance * 100.0) / 100.0,
		"boss_to_centroid_distance": roundf(boss_to_centroid_distance * 100.0) / 100.0,
		"connectivity_status": connectivity_status,
		"connectivity_walkable_cells": connectivity_walkable_cells,
		"connectivity_reachable_cells": connectivity_reachable_cells,
		"validation_room_overlap": validation_room_overlap,
		"generation_success": generation_success,
		"generation_seed_used": generation_seed_used,
		"generation_checksum": generation_checksum,
		"placement_tier_3": placement_tier_3,
		"placement_tier_4": placement_tier_4,
		"before_separator_metrics": before_separator_metrics,
		"after_separator_metrics": after_separator_metrics,
		"dungeon_bounds_area": dungeon_bounds_area,
		"overlap_count": overlap_count,
		"pairwise_spacing_mean": roundf(pairwise_spacing_mean * 100.0) / 100.0,
		"pairwise_spacing_min": roundf(pairwise_spacing_min * 100.0) / 100.0,
		"pairwise_spacing_max": roundf(pairwise_spacing_max * 100.0) / 100.0,
		"pairwise_spacing_stddev": roundf(pairwise_spacing_stddev * 100.0) / 100.0,
		"nearest_neighbor_mean": roundf(nearest_neighbor_mean * 100.0) / 100.0,
		"nearest_neighbor_min": roundf(nearest_neighbor_min * 100.0) / 100.0,
		"nearest_neighbor_max": roundf(nearest_neighbor_max * 100.0) / 100.0,
		"nearest_neighbor_stddev": roundf(nearest_neighbor_stddev * 100.0) / 100.0,
		"before_pairwise_spacing_mean": roundf(before_pairwise_spacing_mean * 100.0) / 100.0,
		"before_pairwise_spacing_min": roundf(before_pairwise_spacing_min * 100.0) / 100.0,
		"before_pairwise_spacing_max": roundf(before_pairwise_spacing_max * 100.0) / 100.0,
		"before_pairwise_spacing_stddev": roundf(before_pairwise_spacing_stddev * 100.0) / 100.0,
		"before_nearest_neighbor_mean": roundf(before_nearest_neighbor_mean * 100.0) / 100.0,
		"before_nearest_neighbor_min": roundf(before_nearest_neighbor_min * 100.0) / 100.0,
		"before_nearest_neighbor_max": roundf(before_nearest_neighbor_max * 100.0) / 100.0,
		"before_nearest_neighbor_stddev": roundf(before_nearest_neighbor_stddev * 100.0) / 100.0,
		# Raw arrays (diagnostic) — not rounded so consumers can compute global percentiles
		"corridor_lengths": corridor_lengths,
		"edge_stretch_values": edge_stretch_values,
	}
