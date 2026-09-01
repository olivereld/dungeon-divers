extends RefCounted

## Captura de métricas de una sola ejecución del generador (un seed).
## Todas las mediciones provienen directamente de DungeonResult.

# ── Rooms ──────────────────────────────────────────────
var room_count: int = 0
var rooms: Array[RoomData] = []
var room_average_area: float = 0.0
var room_area_min: int = 0
var room_area_max: int = 0

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
	}