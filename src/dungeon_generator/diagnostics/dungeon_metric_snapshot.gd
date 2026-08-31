extends RefCounted

## Captura de métricas de una sola ejecución del generador (un seed).
## Todas las mediciones provienen directamente de DungeonResult.

# ── Rooms ──────────────────────────────────────────────
var room_count: int = 0
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
var corridor_short_count: int = 0

# ── Spatial ────────────────────────────────────────────
var spatial_average_room_distance: float = 0.0
var spatial_minimum_room_distance: float = 0.0
var spatial_start_centrality: float = 0.0
var spatial_angular_uniformity: float = 0.0
var spatial_radial_distance_variance: float = 0.0

# ── Radiality (provisional MVP-0) ────────────────────
# Método provisional documentado: media aritmética de las tres
# mediciones espaciales normalizadas con umbrales empíricos.
# NO es canónico — se usará para inspección rápida del baseline
# hasta que se defina un composite definitivo en fases posteriores.
var spatial_radiality_provisional: float = 0.0

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
		"spatial_average_room_distance": roundf(spatial_average_room_distance * 100.0) / 100.0,
		"spatial_minimum_room_distance": roundf(spatial_minimum_room_distance * 100.0) / 100.0,
		"spatial_start_centrality": roundf(spatial_start_centrality * 100.0) / 100.0,
		"spatial_angular_uniformity": roundf(spatial_angular_uniformity * 100.0) / 100.0,
		"spatial_radial_distance_variance": roundf(spatial_radial_distance_variance * 100.0) / 100.0,
		"spatial_radiality_provisional": roundf(spatial_radiality_provisional * 100.0) / 100.0,
		"connectivity_status": connectivity_status,
		"connectivity_walkable_cells": connectivity_walkable_cells,
		"connectivity_reachable_cells": connectivity_reachable_cells,
		"validation_room_overlap": validation_room_overlap,
		"generation_success": generation_success,
		"generation_seed_used": generation_seed_used,
		"generation_time_ms": roundf(generation_time_ms * 100.0) / 100.0,
		"generation_checksum": generation_checksum,
	}