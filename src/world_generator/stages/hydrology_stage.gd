class_name HydrologyStage
extends WorldStage

## Hydrology generation based on terrain drainage, priority-flood depression filling,
## D8 flow direction, and flow accumulation.
##
## Pipeline:
##   1. Hydrology noise sampling
##   2. Lake detection and clustering
##   3. Priority-Flood depression filling (O(N log N) min-heap)
##   4. D8 flow direction calculation
##   5. Flow accumulation network
##   6. River potential and drainage maps
##   7. Headwaters selection and main river tracing
##   8. Natural tributary branching
##   9. River geometry, width, depth, and controlled meanders
##
## Hydrology never modifies WorldCell terrain elevation.
## Water is stored exclusively in HydrologyResult.

const _HydrologyResultScript = preload("res://src/world_generator/hydrology/hydrology_result.gd")

const D8_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 1),
	Vector2i(-1, 1),
	Vector2i(1, -1),
	Vector2i(-1, -1),
]

const CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

## Fast binary min-heap for O(N log N) Priority-Flood sink filling
class PriorityQueue:
	var _data: Array[Dictionary] = []

	func push(pos: Vector2i, height: float) -> void:
		_data.append({ "pos": pos, "height": height })
		var idx := _data.size() - 1
		while idx > 0:
			var parent := (idx - 1) >> 1
			if _data[idx]["height"] < _data[parent]["height"]:
				var tmp: Dictionary = _data[idx]
				_data[idx] = _data[parent]
				_data[parent] = tmp
				idx = parent
			else:
				break

	func pop() -> Dictionary:
		var root: Dictionary = _data[0]
		var last: Dictionary = _data.pop_back()
		if not _data.is_empty():
			_data[0] = last
			var idx := 0
			var count := _data.size()
			while true:
				var left := (idx << 1) + 1
				var right := left + 1
				var smallest := idx
				if left < count and _data[left]["height"] < _data[smallest]["height"]:
					smallest = left
				if right < count and _data[right]["height"] < _data[smallest]["height"]:
					smallest = right
				if smallest != idx:
					var tmp: Dictionary = _data[idx]
					_data[idx] = _data[smallest]
					_data[smallest] = tmp
					idx = smallest
				else:
					break
		return root

	func is_empty() -> bool:
		return _data.is_empty()

	func size() -> int:
		return _data.size()


func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var hydro = _HydrologyResultScript.new()
	context.result.hydrology = hydro

	if not profile.hydrology_enabled:
		return

	var width: int = profile.width
	var height: int = profile.height
	var cells: Dictionary = context.result.cells

	# -------------------------------------------------------------------------
	# 0. HYDROLOGY NOISE
	# -------------------------------------------------------------------------
	var hydro_seed: int = WorldSeedSystem.derive_seed(
		context.master_seed,
		WorldSeedSystem.DOMAIN_HYDROLOGY,
		profile.hydrology_noise_seed_offset
	)

	var hydro_noise := FastNoiseLite.new()
	if profile.hydrology_noise_enabled:
		hydro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		hydro_noise.seed = hydro_seed
		hydro_noise.frequency = profile.get_hydrology_noise_frequency()
		hydro_noise.fractal_octaves = profile.hydrology_noise_octaves

	var debug_noise: Dictionary = {}
	var debug_lake_potential: Dictionary = {}
	var debug_river_potential: Dictionary = {}
	var debug_drainage: Dictionary = {}
	var debug_flow_dir: Dictionary = {}

	# -------------------------------------------------------------------------
	# 1. SAMPLE HYDROLOGY FIELD
	# -------------------------------------------------------------------------
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var cell: WorldCell = cells.get(pos)
			if cell == null:
				continue

			var sample_x: float = float(x) * profile.cell_size
			var sample_y: float = float(y) * profile.cell_size

			var noise_raw: float = 0.0
			if profile.hydrology_noise_enabled:
				noise_raw = hydro_noise.get_noise_2d(sample_x, sample_y)

			var noise_norm: float = clampf((noise_raw + 1.0) * 0.5, 0.0, 1.0)
			debug_noise[pos] = noise_norm

			var lake_potential: float = 0.0
			if cell.normalized_height < profile.lake_threshold:
				lake_potential = 1.0 - (cell.normalized_height / maxf(profile.lake_threshold, 0.001))

			debug_lake_potential[pos] = clampf(lake_potential, 0.0, 1.0)
			debug_drainage[pos] = 0.0
			debug_flow_dir[pos] = Vector2.ZERO

	# -------------------------------------------------------------------------
	# 2. LAKES (Depression basins and spillways)
	# -------------------------------------------------------------------------
	_generate_lakes(cells, hydro, debug_drainage, width, height, profile)

	# -------------------------------------------------------------------------
	# 3. DEPRESSION-FILLED HEIGHT FIELD (Barnes et al. 2014 Priority-Flood)
	# -------------------------------------------------------------------------
	var flood_data := _build_filled_height_field(cells, hydro, width, height)
	var filled_height: Dictionary = flood_data["filled"]
	var flood_rank: Dictionary = flood_data["flood_rank"]

	# -------------------------------------------------------------------------
	# 4. D8 FLOW DIRECTION
	# -------------------------------------------------------------------------
	var flow_to: Dictionary = {}

	# Precompute lake cell sets for spillways so spillways don't flow backward into their own lakes
	var spillway_lake_cells: Dictionary = {}
	for lake in hydro.lakes:
		var spill_pos: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		var lake_cells: Array = lake.get("cells", [])
		var set_dict: Dictionary = {}
		for lc in lake_cells:
			set_dict[lc] = true
		spillway_lake_cells[spill_pos] = set_dict

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not cells.has(pos):
				continue

			# Lake cells are terminal drainage sinks/outlets.
			if hydro.is_lake(pos):
				flow_to[pos] = pos
				debug_flow_dir[pos] = Vector2.ZERO
				continue

			var next_pos: Vector2i = _find_downstream_cell(
				pos,
				filled_height,
				cells,
				width,
				height,
				profile,
				flood_rank,
				spillway_lake_cells
			)
			flow_to[pos] = next_pos

			if next_pos != pos:
				var direction := Vector2(
					float(next_pos.x - pos.x),
					float(next_pos.y - pos.y)
				).normalized()
				debug_flow_dir[pos] = direction

	# -------------------------------------------------------------------------
	# 5. FLOW ACCUMULATION
	# -------------------------------------------------------------------------
	var accumulation: Dictionary = {}
	for y in range(height):
		for x in range(width):
			accumulation[Vector2i(x, y)] = 1.0

	# H11: Inject lake contribution into spillways BEFORE propagation
	for lake in hydro.lakes:
		var spill_pos: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		var lake_cells: Array = lake.get("cells", [])
		if cells.has(spill_pos) and not hydro.is_lake(spill_pos):
			var lake_acc: float = 0.0
			for lpos in lake_cells:
				lake_acc += float(accumulation.get(lpos, 1.0))
			accumulation[spill_pos] = float(accumulation.get(spill_pos, 1.0)) + lake_acc

	# Sort cells from highest to lowest filled elevation.
	var sorted_cells: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if cells.has(pos):
				sorted_cells.append(pos)

	sorted_cells.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return float(filled_height.get(a, 0.0)) > float(filled_height.get(b, 0.0))
	)

	for pos in sorted_cells:
		var downstream: Vector2i = flow_to.get(pos, pos)
		if downstream == pos:
			continue

		if not accumulation.has(downstream):
			accumulation[downstream] = 1.0

		accumulation[downstream] += accumulation.get(pos, 1.0)

	# -------------------------------------------------------------------------
	# 6. RIVER POTENTIAL & CHANNEL MASK (Phase H2)
	# -------------------------------------------------------------------------
	var max_accumulation: float = 1.0
	for pos in accumulation:
		max_accumulation = maxf(max_accumulation, float(accumulation[pos]))

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not cells.has(pos):
				continue

			var acc: float = float(accumulation.get(pos, 1.0))
			var acc_norm: float = clampf(log(acc + 1.0) / maxf(log(max_accumulation + 1.0), 0.001), 0.0, 1.0)
			var cell: WorldCell = cells[pos]
			var slope_norm: float = clampf(cell.slope / maxf(profile.max_walkable_slope, 1.0), 0.0, 1.0)

			var river_potential: float = (
				acc_norm * 0.70 +
				slope_norm * 0.15 +
				cell.normalized_height * 0.10 +
				float(debug_noise.get(pos, 0.5)) * 0.05
			)

			debug_river_potential[pos] = clampf(river_potential, 0.0, 1.0)
			debug_drainage[pos] = acc

	# -------------------------------------------------------------------------
	# 7. CHANNEL THRESHOLDS, REVERSE GRAPH & MASK (H13)
	# -------------------------------------------------------------------------
	var total_cells: int = width * height
	var tributary_threshold: float = maxf(4.0, float(total_cells) * 0.0008)
	var main_channel_threshold: float = maxf(8.0, float(total_cells) * 0.0020)

	# Build upstream reverse graph (H13)
	var upstream: Dictionary = {}  # Vector2i -> Array[Vector2i]
	for pos in flow_to:
		var downstream: Vector2i = flow_to[pos]
		if downstream == pos:
			continue
		if not upstream.has(downstream):
			upstream[downstream] = []
		upstream[downstream].append(pos)

	# Channel mask excludes lake cells (H13)
	var channel_mask: Dictionary = {}
	for pos in accumulation:
		if float(accumulation[pos]) >= tributary_threshold and not hydro.is_lake(pos):
			channel_mask[pos] = true

	# -------------------------------------------------------------------------
	# 8. FIND CONNECTED HYDROGRAPHIC NETWORKS (H13/H14)
	# -------------------------------------------------------------------------
	# Find all outlets (boundary cells, lakes, or terminal cells that collect flow)
	var outlets: Array[Vector2i] = []
	for pos in flow_to:
		if flow_to[pos] == pos:
			if _is_boundary(pos, width, height) or hydro.is_lake(pos):
				if float(accumulation.get(pos, 1.0)) >= main_channel_threshold:
					outlets.append(pos)

	# If no boundary/lake outlets meet main_channel_threshold, include any terminal cell meeting threshold
	if outlets.is_empty():
		for pos in flow_to:
			if flow_to[pos] == pos and float(accumulation.get(pos, 1.0)) >= main_channel_threshold:
				outlets.append(pos)

	# Sort outlets by accumulation descending (most important first)
	outlets.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return float(accumulation.get(a, 0.0)) > float(accumulation.get(b, 0.0))
	)

	# -------------------------------------------------------------------------
	# 9. EXTRACT RIVER PATHS WITH EDGE OWNERSHIP (H14/H15)
	# -------------------------------------------------------------------------
	var validated_paths: Array[Dictionary] = []
	var rendered_edges: Dictionary = {}  # "x,y->x,y" -> true
	var river_id: int = 0
	var networks_selected: int = 0

	for outlet in outlets:
		if networks_selected >= profile.max_rivers:
			break

		# Trace main stem: walk upstream from outlet following highest accumulation
		var main_path: Array[Vector2i] = _trace_main_stem_upstream(
			outlet, upstream, accumulation, channel_mask, hydro
		)
		main_path.reverse()  # Now headwater -> outlet

		if main_path.size() < 2:
			continue
		var length_m: float = _calculate_path_length(main_path, 1.0)
		if length_m < profile.min_river_length:
			continue

		# Register main stem edges
		var main_edges_ok: bool = _register_path_edges(main_path, rendered_edges)
		if not main_edges_ok:
			continue  # Overlaps with already-selected network

		validated_paths.append({
			"id": river_id,
			"path": main_path,
			"is_tributary": false,
			"network_id": networks_selected
		})
		river_id += 1

		# Extract tributaries that join this main stem
		var tributary_paths: Array[Array] = _extract_tributaries(
			main_path, upstream, accumulation, channel_mask,
			rendered_edges, hydro, profile
		)
		for trib_path in tributary_paths:
			validated_paths.append({
				"id": river_id,
				"path": trib_path,
				"is_tributary": true,
				"network_id": networks_selected
			})
			river_id += 1

		networks_selected += 1

	# -------------------------------------------------------------------------
	# 10. CARVE RIVER CHANNELS INTO TERRAIN (Phase H6 & H7)
	# -------------------------------------------------------------------------
	_carve_river_channels(cells, validated_paths, accumulation, width, height, profile, hydro)

	# -------------------------------------------------------------------------
	# 11. BUILD FINAL RIVER GEOMETRY DATA (Phase H4 & H5)
	# -------------------------------------------------------------------------
	for item in validated_paths:
		var river_data := _build_river_data(
			item["id"],
			item["path"],
			accumulation,
			cells,
			profile,
			hydro,
			hydro_noise
		)
		hydro.rivers.append(river_data)

	# -------------------------------------------------------------------------
	# 12. DEBUG DATA
	# -------------------------------------------------------------------------
	hydro.set_debug_grid("noise", debug_noise)
	hydro.set_debug_grid("lake_potential", debug_lake_potential)
	hydro.set_debug_grid("river_potential", debug_river_potential)
	hydro.set_debug_grid("drainage", debug_drainage)
	hydro.set_debug_grid("flow_dir", debug_flow_dir)
	hydro.set_debug_grid("flow_to", flow_to)


# =============================================================================
# LAKES
# =============================================================================

func _generate_lakes(
	cells: Dictionary,
	hydro: RefCounted,
	debug_drainage: Dictionary,
	width: int,
	height: int,
	profile: WorldProfile
) -> void:
	var visited: Dictionary = {}
	var next_lake_id: int = 1

	for y in range(height):
		for x in range(width):
			var start := Vector2i(x, y)
			if visited.has(start):
				continue

			var start_cell: WorldCell = cells.get(start)
			if start_cell == null:
				continue
			if start_cell.normalized_height >= profile.lake_threshold:
				continue

			var cluster: Array[Vector2i] = []
			var queue: Array[Vector2i] = [start]
			visited[start] = true

			while not queue.is_empty():
				var current: Vector2i = queue.pop_front()
				cluster.append(current)

				for offset in CARDINAL_OFFSETS:
					var neighbor: Vector2i = current + offset
					if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
						continue
					if visited.has(neighbor):
						continue

					var neighbor_cell: WorldCell = cells.get(neighbor)
					if neighbor_cell == null:
						continue

					if neighbor_cell.normalized_height < profile.lake_threshold:
						visited[neighbor] = true
						queue.append(neighbor)

			if cluster.size() < profile.lake_minimum_area:
				continue

			var cluster_set: Dictionary = {}
			for pos in cluster:
				cluster_set[pos] = true

			var spillway_height: float = INF
			var spillway_pos: Vector2i = cluster[0]

			for pos in cluster:
				for offset in CARDINAL_OFFSETS:
					var neighbor: Vector2i = pos + offset
					if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
						continue
					if cluster_set.has(neighbor):
						continue

					var neighbor_cell: WorldCell = cells.get(neighbor)
					if neighbor_cell == null:
						continue

					if neighbor_cell.height < spillway_height:
						spillway_height = neighbor_cell.height
						spillway_pos = neighbor

			if is_inf(spillway_height):
				spillway_height = start_cell.height

			var min_pos := cluster[0]
			var max_pos := cluster[0]
			for pos in cluster:
				min_pos.x = mini(min_pos.x, pos.x)
				min_pos.y = mini(min_pos.y, pos.y)
				max_pos.x = maxi(max_pos.x, pos.x)
				max_pos.y = maxi(max_pos.y, pos.y)

			var lake_id: int = next_lake_id
			next_lake_id += 1

			for pos in cluster:
				var cell: WorldCell = cells[pos]
				var depth: float = maxf(0.0, spillway_height - cell.height)

				hydro.water_cells[pos] = {
					"type": "lake",
					"water_height": spillway_height,
					"terrain_height": cell.height,
					"depth": depth,
					"lake_id": lake_id,
					"flow_dir": Vector2.ZERO
				}

				debug_drainage[pos] = maxf(
					float(debug_drainage.get(pos, 0.0)),
					10.0 + depth * 5.0
				)

			hydro.lakes.append({
				"id": lake_id,
				"water_height": spillway_height,
				"cells": cluster,
				"spillway_pos": spillway_pos,
				"spillway_height": spillway_height,
				"min_pos": min_pos,
				"max_pos": max_pos
			})


# =============================================================================
# DEPRESSION FILL (Priority-Flood O(N log N) Heap - Phase H1)
# =============================================================================

func _build_filled_height_field(
	cells: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int
) -> Dictionary:
	var filled: Dictionary = {}
	var visited: Dictionary = {}
	var flood_rank: Dictionary = {}
	var pq := PriorityQueue.new()
	var rank_counter: int = 0

	# 1. Boundary cells are natural open outlets
	for x in range(width):
		var p_top := Vector2i(x, 0)
		var p_bot := Vector2i(x, height - 1)
		if cells.has(p_top) and not visited.has(p_top):
			visited[p_top] = true
			var c: WorldCell = cells[p_top]
			filled[p_top] = c.height
			pq.push(p_top, c.height)
		if cells.has(p_bot) and not visited.has(p_bot):
			visited[p_bot] = true
			var c: WorldCell = cells[p_bot]
			filled[p_bot] = c.height
			pq.push(p_bot, c.height)

	for y in range(height):
		var p_left := Vector2i(0, y)
		var p_right := Vector2i(width - 1, y)
		if cells.has(p_left) and not visited.has(p_left):
			visited[p_left] = true
			var c: WorldCell = cells[p_left]
			filled[p_left] = c.height
			pq.push(p_left, c.height)
		if cells.has(p_right) and not visited.has(p_right):
			visited[p_right] = true
			var c: WorldCell = cells[p_right]
			filled[p_right] = c.height
			pq.push(p_right, c.height)

	# 2. Lakes are filled to their spillway height
	for lake in hydro.lakes:
		var lake_cells: Array = lake.cells if lake is Dictionary and lake.has("cells") else lake.get("cells", [])
		var spill_h: float = float(lake.get("spillway_height", 0.0))
		for pos in lake_cells:
			if cells.has(pos) and not visited.has(pos):
				visited[pos] = true
				filled[pos] = spill_h
				pq.push(pos, spill_h)

	# 3. Priority Flood main loop
	while not pq.is_empty():
		var item: Dictionary = pq.pop()
		var current_pos: Vector2i = item["pos"]
		flood_rank[current_pos] = rank_counter
		rank_counter += 1
		var current_filled: float = float(filled[current_pos])

		for offset in D8_OFFSETS:
			var neighbor: Vector2i = current_pos + offset
			if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
				continue
			if visited.has(neighbor):
				continue
			if not cells.has(neighbor):
				continue

			visited[neighbor] = true
			var neighbor_cell: WorldCell = cells[neighbor]
			var neighbor_height: float = neighbor_cell.height

			var resolved_height: float = maxf(neighbor_height, current_filled)
			filled[neighbor] = resolved_height
			pq.push(neighbor, resolved_height)

	return {
		"filled": filled,
		"flood_rank": flood_rank
	}


# =============================================================================
# FLOW DIRECTION (Phase H1)
# =============================================================================

func _find_downstream_cell(
	pos: Vector2i,
	filled_height: Dictionary,
	cells: Dictionary,
	width: int,
	height: int,
	_profile: WorldProfile,
	flood_rank: Dictionary = {},
	spillway_lake_cells: Dictionary = {}
) -> Vector2i:
	var current_filled: float = float(filled_height.get(pos, cells[pos].height))
	var current_rank: int = flood_rank.get(pos, 999999999)

	var best_pos: Vector2i = pos
	var best_drop: float = 0.0
	var best_rank: int = current_rank

	var forbidden_cells: Dictionary = spillway_lake_cells.get(pos, {})

	for offset in D8_OFFSETS:
		var neighbor: Vector2i = pos + offset
		if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
			continue
		if not cells.has(neighbor):
			continue
		if forbidden_cells.has(neighbor):
			continue

		var neighbor_filled: float = float(filled_height.get(neighbor, cells[neighbor].height))
		var distance: float = (1.41421356 if offset.x != 0 and offset.y != 0 else 1.0)

		var drop: float = (current_filled - neighbor_filled) / maxf(distance, 0.001)
		var neighbor_rank: int = flood_rank.get(neighbor, 999999999)

		if drop > best_drop + 0.00001:
			best_drop = drop
			best_pos = neighbor
			best_rank = neighbor_rank
		elif absf(drop - best_drop) <= 0.00001 and drop > 0.0:
			# Tie-break among downhill neighbors: prefer cell resolved earlier in Priority-Flood
			if neighbor_rank < best_rank:
				best_pos = neighbor
				best_rank = neighbor_rank
		elif best_drop <= 0.00001 and absf(drop) <= 0.00001:
			# Flat plateau: drain toward lower flood rank (closer to outlet/spillway)
			if neighbor_rank < best_rank:
				best_pos = neighbor
				best_rank = neighbor_rank

	return best_pos


# =============================================================================
# RIVER EXTRACTION & GRAPH TRACING (H13, H14, H15)
# =============================================================================

func _trace_main_stem_upstream(
	start: Vector2i,
	upstream_graph: Dictionary,
	accumulation: Dictionary,
	channel_mask: Dictionary,
	hydro: RefCounted
) -> Array[Vector2i]:
	var path: Array[Vector2i] = [start]
	var current: Vector2i = start
	var visited: Dictionary = { start: true }

	for _step in range(5000):
		var up_list: Array = upstream_graph.get(current, [])
		if up_list.is_empty():
			break

		var best_up: Vector2i = Vector2i(-1, -1)
		var best_acc: float = -1.0
		for candidate in up_list:
			if not channel_mask.has(candidate) and not hydro.is_lake(candidate):
				continue
			var c_acc: float = float(accumulation.get(candidate, 0.0))
			if c_acc > best_acc:
				best_acc = c_acc
				best_up = candidate

		if best_up == Vector2i(-1, -1) or visited.has(best_up):
			break
		if hydro.is_lake(best_up):
			path.append(best_up)
			break

		visited[best_up] = true
		path.append(best_up)
		current = best_up

	return path


func _register_path_edges(path: Array[Vector2i], rendered_edges: Dictionary) -> bool:
	for i in range(path.size() - 1):
		var key: String = "%d,%d->%d,%d" % [path[i].x, path[i].y, path[i + 1].x, path[i + 1].y]
		if rendered_edges.has(key):
			return false
	for i in range(path.size() - 1):
		var key: String = "%d,%d->%d,%d" % [path[i].x, path[i].y, path[i + 1].x, path[i + 1].y]
		rendered_edges[key] = true
	return true


func _extract_tributaries(
	main_path: Array[Vector2i],
	upstream_graph: Dictionary,
	accumulation: Dictionary,
	channel_mask: Dictionary,
	rendered_edges: Dictionary,
	hydro: RefCounted,
	profile: WorldProfile
) -> Array[Array]:
	var tributaries: Array[Array] = []
	var main_set: Dictionary = {}
	for p in main_path:
		main_set[p] = true

	# Find confluence points (cells on main stem with >= 2 upstream cells in channel)
	for confluence in main_path:
		var up_list: Array = upstream_graph.get(confluence, [])
		for up_cell in up_list:
			if main_set.has(up_cell) or hydro.is_lake(up_cell):
				continue
			if not channel_mask.has(up_cell):
				continue

			# Trace this branch upstream
			var trib_path: Array[Vector2i] = [confluence]
			var current: Vector2i = up_cell
			var visited: Dictionary = { confluence: true }
			for _step in range(2000):
				if visited.has(current) or hydro.is_lake(current):
					break
				visited[current] = true
				trib_path.append(current)
				var next_up: Array = upstream_graph.get(current, [])
				if next_up.is_empty():
					break
				var best: Vector2i = Vector2i(-1, -1)
				var best_acc: float = -1.0
				for c in next_up:
					if channel_mask.has(c) and float(accumulation.get(c, 0.0)) > best_acc:
						best_acc = float(accumulation.get(c, 0.0))
						best = c
				if best == Vector2i(-1, -1):
					break
				current = best

			trib_path.reverse()  # headwater -> confluence

			if trib_path.size() < 3:
				continue
			var length_m: float = _calculate_path_length(trib_path, 1.0)
			if length_m < profile.min_river_length * 0.5:
				continue

			if _register_path_edges(trib_path, rendered_edges):
				tributaries.append(trib_path)

	return tributaries


func _is_boundary(pos: Vector2i, w: int, h: int) -> bool:
	return pos.x <= 0 or pos.x >= w - 1 or pos.y <= 0 or pos.y >= h - 1


# =============================================================================
# RIVER CHANNEL CARVING (Phase H6 & H7 - Physical Channel & Wet Banks)
# =============================================================================

func _carve_river_channels(
	cells: Dictionary,
	validated_paths: Array[Dictionary],
	accumulation: Dictionary,
	width: int,
	height: int,
	profile: WorldProfile,
	hydro: RefCounted
) -> void:
	if validated_paths.is_empty():
		return

	var max_acc: float = 1.0
	for item in validated_paths:
		for pos in item["path"]:
			max_acc = maxf(max_acc, float(accumulation.get(pos, 1.0)))

	var carve_depth: Dictionary = {}

	for item in validated_paths:
		var path: Array[Vector2i] = item["path"]
		var n_pts: int = path.size()
		for i in range(n_pts):
			var pos: Vector2i = path[i]
			if hydro.is_lake(pos):
				continue

			var acc: float = float(accumulation.get(pos, 1.0))
			var acc_ratio: float = clampf((acc - 1.0) / maxf(max_acc - 1.0, 1.0), 0.0, 1.0)
			var acc_factor: float = pow(acc_ratio, 0.42)

			# Channel width and depth driven by profile parameters (Phase H6)
			var channel_depth: float = lerpf(profile.river_channel_depth * 0.5, profile.river_channel_depth, acc_factor)
			var bank_width: float = maxf(profile.river_bank_width * maxf(acc_factor, 0.75), 1.8)
			var ir_ceil: int = int(ceil(bank_width))

			# Inspect grid neighborhood
			for dy in range(-ir_ceil, ir_ceil + 1):
				for dx in range(-ir_ceil, ir_ceil + 1):
					var cx: int = pos.x + dx
					var cy: int = pos.y + dy
					if cx < 0 or cx >= width or cy < 0 or cy >= height:
						continue

					var c_pos := Vector2i(cx, cy)
					if hydro.is_lake(c_pos) or not cells.has(c_pos):
						continue

					# Distance to centerline segment
					var dist: float = Vector2(float(dx), float(dy)).length()
					if i < n_pts - 1:
						var next_pos: Vector2i = path[i + 1]
						var seg_start := Vector2(float(pos.x), float(pos.y))
						var seg_end := Vector2(float(next_pos.x), float(next_pos.y))
						var pt := Vector2(float(cx), float(cy))
						var ab := seg_end - seg_start
						var len_sq := ab.length_squared()
						if len_sq > 0.001:
							var t := clampf((pt - seg_start).dot(ab) / len_sq, 0.0, 1.0)
							var proj := seg_start + ab * t
							dist = (pt - proj).length()

					if dist >= bank_width:
						continue

					var u: float = dist / bank_width
					# Smooth falloff using profile.river_bank_falloff
					var falloff: float = pow(maxf(0.0, 1.0 - u * u), profile.river_bank_falloff)
					var d_carve: float = channel_depth * falloff
					carve_depth[c_pos] = maxf(carve_depth.get(c_pos, 0.0), d_carve)

	# Apply height adjustments & soil moisture (Phase H7)
	var modified_cells: Dictionary = {}
	for pos in carve_depth:
		var cell: WorldCell = cells.get(pos)
		if cell == null or hydro.is_lake(pos):
			continue

		var dep: float = carve_depth[pos]
		cell.height -= dep
		# Enrich soil moisture under and around the stream so it darkens into peat/loam
		cell.moisture = clampf(cell.moisture + 0.35 * (dep / maxf(profile.river_channel_depth, 0.01)), 0.0, 1.0)
		modified_cells[pos] = true

	# Update slope for modified cells to ensure consistent terrain mesh normals and walkability
	for pos in modified_cells:
		var cell: WorldCell = cells[pos]
		var x: int = pos.x
		var y: int = pos.y
		var h_l: float = cells[Vector2i(maxi(x - 1, 0), y)].height
		var h_r: float = cells[Vector2i(mini(x + 1, width - 1), y)].height
		var h_u: float = cells[Vector2i(x, maxi(y - 1, 0))].height
		var h_d: float = cells[Vector2i(x, mini(y + 1, height - 1))].height
		var dx: float = (h_r - h_l) * 0.5
		var dy: float = (h_d - h_u) * 0.5
		cell.slope = rad_to_deg(atan(sqrt(dx * dx + dy * dy)))


# =============================================================================
# RIVER DATA (Phase H4 & H5 - Width, Depth & Lateral Meander)
# =============================================================================

func _build_river_data(
	river_index: int,
	path: Array[Vector2i],
	accumulation: Dictionary,
	cells: Dictionary,
	profile: WorldProfile,
	hydro: RefCounted,
	hydro_noise: FastNoiseLite
) -> Dictionary:
	var points: Array[Vector3] = []
	var widths: Array[float] = []

	var max_acc: float = 1.0
	for pos in path:
		max_acc = maxf(max_acc, float(accumulation.get(pos, 1.0)))

	for i in range(path.size()):
		var pos: Vector2i = path[i]
		var cell: WorldCell = cells[pos]

		var acc: float = float(accumulation.get(pos, 1.0))
		var acc_ratio: float = clampf((acc - 1.0) / maxf(max_acc - 1.0, 1.0), 0.0, 1.0)
		var acc_factor: float = pow(acc_ratio, 0.42)

		# Non-linear accumulation-based width progression (Phase H4)
		var width: float = lerpf(profile.river_min_width, profile.river_max_width, acc_factor)

		# Taper at headwater source spring
		var length_progress: float = float(i) / float(maxi(path.size() - 1, 1))
		var source_taper: float = clampf(length_progress / 0.12, 0.40, 1.0)
		width = maxf(width * source_taper, profile.river_min_width * 0.80)

		# Expansion at lake estuary / mouth
		if i >= path.size() - 2 and hydro.is_lake(path[-1]):
			width *= 1.25

		widths.append(width)

		var flow_dir := Vector2.ZERO
		if i < path.size() - 1:
			var diff: Vector2i = path[i + 1] - pos
			flow_dir = Vector2(float(diff.x), float(diff.y)).normalized()
		elif i > 0:
			var diff: Vector2i = pos - path[i - 1]
			flow_dir = Vector2(float(diff.x), float(diff.y)).normalized()

		# Fixed 1.0 unit grid coordinates for 128x128 3D test level
		var world_x: float = float(pos.x)
		var world_z: float = float(pos.y)

		# Controlled meander strictly LATERAL to flow direction (Phase H5)
		var meander_offset := Vector2.ZERO
		if profile.hydrology_noise_enabled and hydro_noise != null:
			var sample_x: float = float(pos.x) * profile.cell_size
			var sample_z: float = float(pos.y) * profile.cell_size
			var noise_val: float = hydro_noise.get_noise_2d(sample_x, sample_z)
			var perp_dir := Vector2(-flow_dir.y, flow_dir.x)
			var meander_taper: float = clampf(length_progress / 0.15, 0.0, 1.0)
			if i >= path.size() - 2:
				meander_taper *= 0.3
			meander_offset = perp_dir * (noise_val * profile.river_meander_strength * width * 0.25 * meander_taper)

		var target_y: float
		if hydro.is_lake(pos):
			var l_data: Dictionary = hydro.get_cell_data(pos)
			target_y = float(l_data.get("water_height", cell.height))
		else:
			target_y = cell.height + 0.025

		if i > 0 and target_y > points[i - 1].y:
			target_y = points[i - 1].y

		var world_point := Vector3(
			world_x + meander_offset.x,
			target_y,
			world_z + meander_offset.y
		)
		points.append(world_point)

		if not hydro.is_lake(pos):
			hydro.water_cells[pos] = {
				"type": "river",
				"water_height": target_y,
				"terrain_height": cell.height,
				"depth": maxf(0.12, target_y - cell.height),
				"river_index": river_index,
				"flow_dir": flow_dir
			}

	return {
		"index": river_index,
		"points": points,
		"widths": widths,
		"cells": path
	}


# =============================================================================
# UTILITIES
# =============================================================================

func _calculate_path_length(path: Array[Vector2i], cell_size: float) -> float:
	if path.size() < 2:
		return 0.0

	var length: float = 0.0
	for i in range(1, path.size()):
		var diff := Vector2(float(path[i].x - path[i - 1].x), float(path[i].y - path[i - 1].y))
		length += diff.length() * cell_size

	return length
