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
	lines.append("  average room distance: %.1f" % snapshot.spatial_average_room_distance)
	lines.append("  minimum room distance: %.1f" % snapshot.spatial_minimum_room_distance)
	lines.append("  start centrality: %.1f" % snapshot.spatial_start_centrality)
	lines.append("  angular uniformity: %.2f" % snapshot.spatial_angular_uniformity)
	lines.append("  radial distance variance: %.1f" % snapshot.spatial_radial_distance_variance)
	lines.append("  radiality (provisional): %.2f" % snapshot.spatial_radiality_provisional)
	lines.append("")
	lines.append("Corridors")
	lines.append("  count: %d" % snapshot.corridor_count)
	lines.append("  average length: %.1f" % snapshot.corridor_average_length)
	lines.append("  minimum length: %d" % snapshot.corridor_minimum_length)
	lines.append("  short corridors (<=3): %d" % snapshot.corridor_short_count)
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

	for snap in snapshots:
		if snap.generation_success == "PASS":
			summary["generations_successful"] += 1
		else:
			summary["generations_failed"] += 1

		total_room_count += snap.room_count
		total_connection_count += snap.connection_count
		total_corridor_count += snap.corridor_count
		total_walkable += snap.connectivity_walkable_cells
		total_reachable += snap.connectivity_reachable_cells
		if snap.connectivity_status == "PASS":
			connectivity_pass_count += 1
		if snap.validation_room_overlap == "PASS":
			overlap_pass_count += 1

	summary["avg_rooms"] = float(total_room_count) / float(n)
	summary["avg_connections"] = float(total_connection_count) / float(n)
	summary["avg_corridors"] = float(total_corridor_count) / float(n)
	summary["connectivity_pass_rate"] = float(connectivity_pass_count) / float(n)
	summary["overlap_pass_rate"] = float(overlap_pass_count) / float(n)
	summary["walkable_cells_total"] = total_walkable
	summary["reachable_cells_total"] = total_reachable

	return summary

## Construye un DungeonConfig con seed fijo para un valor dado.
static func build_config(seed: int) -> DungeonConfig:
	var cfg = _DungeonConfigScript.new()
	cfg.seed = seed
	cfg.use_fixed_seed = true
	cfg.apply_preset_standard()
	return cfg

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
	_compute_connectivity(snap, result.grid, result.rooms)
	_compute_validation(snap, result.rooms)

	return snap

func _compute_room_metrics(snap, rooms: Array[RoomData]) -> void:
	var total_area: int = 0
	var room_area_min: int = 999999
	var room_area_max: int = 0
	for r in rooms:
		var a: int = r.get_area()
		total_area += a
		if a < room_area_min:
			room_area_min = a
		if a > room_area_max:
			room_area_max = a
	snap.room_area_min = room_area_min
	snap.room_area_max = room_area_max
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

	var loop_count: int = 0
	for c in connections:
		if c == null:
			continue
		if degree.has(c.room_a_id):
			degree[c.room_a_id] += 1
		if degree.has(c.room_b_id):
			degree[c.room_b_id] += 1
		if not c.is_required:
			loop_count += 1

	snap.connection_loops = loop_count

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
		return

	var total_len: int = 0
	var min_len: int = 999999
	var short_count: int = 0
	for p in corridor_paths:
		if p == null:
			continue
		var length: int = p.centerline_cells.size()
		total_len += length
		if length < min_len:
			min_len = length
		if length <= 3:
			short_count += 1

	snap.corridor_average_length = float(total_len) / float(corridor_paths.size()) if corridor_paths.size() > 0 else 0.0
	snap.corridor_minimum_length = min_len if min_len < 999999 else 0
	snap.corridor_short_count = short_count

func _compute_spatial_metrics(snap, rooms: Array[RoomData]) -> void:
	if rooms.size() < 2:
		snap.spatial_average_room_distance = 0.0
		snap.spatial_minimum_room_distance = 0.0
		snap.spatial_start_centrality = 0.0
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

	snap.spatial_average_room_distance = float(_sum_array(distances)) / float(distances.size()) if distances.size() > 0 else 0.0
	snap.spatial_minimum_room_distance = min_dist if min_dist < 1e9 else 0.0

	# Start centrality: distance from start room center to centroid of all rooms
	var centroid: Vector2i = _compute_centroid(centers)
	snap.spatial_start_centrality = start_center.distance_to(centroid)

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
	# Normaliza cada medición al rango [0, 1] usando umbrales empíricos
	# y promedia. Es provisional — no es una métrica canónica.
	var c_norm: float = minf(snap.spatial_start_centrality / 20.0, 1.0)
	var a_norm: float = snap.spatial_angular_uniformity  # ya está en [0, 1]
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

static func _compute_centroid(points: Array[Vector2i]) -> Vector2i:
	if points.is_empty():
		return Vector2i(0, 0)
	var sx: int = 0
	var sy: int = 0
	for p in points:
		sx += p.x
		sy += p.y
	return Vector2i(sx / points.size(), sy / points.size())

static func _sum_array(arr: Array) -> float:
	var s: float = 0.0
	for v in arr:
		s += float(v)
	return s