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
	var filled_height: Dictionary = _build_filled_height_field(cells, hydro, width, height)

	# -------------------------------------------------------------------------
	# 4. D8 FLOW DIRECTION
	# -------------------------------------------------------------------------
	var flow_to: Dictionary = {}

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
				profile
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
	# 6. RIVER POTENTIAL
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
	# 7. CHANNEL THRESHOLDS
	# -------------------------------------------------------------------------
	var total_cells: int = width * height
	var tributary_threshold: float = maxf(4.0, float(total_cells) * 0.0008)
	var main_channel_threshold: float = maxf(8.0, float(total_cells) * 0.0020)

	# -------------------------------------------------------------------------
	# 8. SELECT HEADWATERS
	# -------------------------------------------------------------------------
	var headwaters: Array[Vector2i] = []
	for y in range(2, height - 2):
		for x in range(2, width - 2):
			var pos := Vector2i(x, y)
			if hydro.is_lake(pos):
				continue

			var cell: WorldCell = cells.get(pos)
			if cell == null:
				continue

			var acc: float = float(accumulation.get(pos, 1.0))
			if (
				cell.normalized_height >= profile.river_source_min_height
				and cell.slope >= profile.river_source_min_slope
				and acc <= main_channel_threshold
				and acc >= 2.0
			):
				headwaters.append(pos)

	# Sort headwaters by elevation descending.
	headwaters.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			var ca: WorldCell = cells[a]
			var cb: WorldCell = cells[b]
			return ca.height > cb.height
	)

	# -------------------------------------------------------------------------
	# 9. BUILD MAIN RIVERS
	# -------------------------------------------------------------------------
	var river_id: int = 0
	var selected_headwaters: Array[Vector2i] = []

	for source in headwaters:
		if selected_headwaters.size() >= profile.max_rivers:
			break

		var too_close: bool = false
		for selected in selected_headwaters:
			var distance_cells: float = Vector2(
				float(source.x - selected.x),
				float(source.y - selected.y)
			).length()

			if distance_cells < profile.min_river_length * 0.75:
				too_close = true
				break

		if too_close:
			continue

		var path := _trace_river(
			source,
			flow_to,
			accumulation,
			hydro,
			cells,
			width,
			height,
			profile,
			tributary_threshold
		)

		if path.size() < 2:
			continue

		var length_m: float = _calculate_path_length(path, 1.0)
		if length_m < profile.min_river_length:
			continue

		var river_data := _build_river_data(
			river_id,
			path,
			accumulation,
			cells,
			profile,
			hydro,
			hydro_noise
		)

		hydro.rivers.append(river_data)
		selected_headwaters.append(source)
		river_id += 1

	# -------------------------------------------------------------------------
	# 10. ADD TRIBUTARIES
	# -------------------------------------------------------------------------
	var tributary_sources: Array[Vector2i] = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var pos := Vector2i(x, y)
			if hydro.is_lake(pos):
				continue

			var acc: float = float(accumulation.get(pos, 1.0))
			if acc < tributary_threshold:
				continue

			var downstream: Vector2i = flow_to.get(pos, pos)
			if downstream == pos:
				continue

			var upstream_count: int = 0
			for offset in D8_OFFSETS:
				var neighbor: Vector2i = pos + offset
				if flow_to.get(neighbor, neighbor) == pos:
					upstream_count += 1

			# Branching point = natural confluence
			if upstream_count >= 2:
				tributary_sources.append(pos)

	tributary_sources.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return float(accumulation.get(a, 0.0)) > float(accumulation.get(b, 0.0))
	)

	var tributary_id: int = river_id
	for source in tributary_sources:
		if tributary_id >= profile.max_rivers * 3:
			break

		var path := _trace_river(
			source,
			flow_to,
			accumulation,
			hydro,
			cells,
			width,
			height,
			profile,
			tributary_threshold
		)

		if path.size() < 2:
			continue

		var length_m: float = _calculate_path_length(path, 1.0)
		if length_m < profile.min_river_length * 0.5:
			continue

		var river_data := _build_river_data(
			tributary_id,
			path,
			accumulation,
			cells,
			profile,
			hydro,
			hydro_noise
		)

		hydro.rivers.append(river_data)
		tributary_id += 1

	# -------------------------------------------------------------------------
	# 11. DEBUG DATA
	# -------------------------------------------------------------------------
	hydro.set_debug_grid("noise", debug_noise)
	hydro.set_debug_grid("lake_potential", debug_lake_potential)
	hydro.set_debug_grid("river_potential", debug_river_potential)
	hydro.set_debug_grid("drainage", debug_drainage)
	hydro.set_debug_grid("flow_dir", debug_flow_dir)


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
			if start_cell == null or start_cell.normalized_height >= profile.lake_threshold:
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
# DEPRESSION FILL (Priority-Flood O(N log N) Heap)
# =============================================================================

func _build_filled_height_field(
	cells: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int
) -> Dictionary:
	var filled: Dictionary = {}
	var visited: Dictionary = {}
	var pq := PriorityQueue.new()

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

	# 2. Lakes are also natural internal sinks/outlets
	for lake in hydro.lakes:
		var lake_cells: Array = lake.cells if lake is Dictionary and lake.has("cells") else lake.get("cells", [])
		for pos in lake_cells:
			if cells.has(pos) and not visited.has(pos):
				visited[pos] = true
				var c: WorldCell = cells[pos]
				filled[pos] = c.height
				pq.push(pos, c.height)

	# 3. Priority Flood main loop
	while not pq.is_empty():
		var item: Dictionary = pq.pop()
		var current_pos: Vector2i = item["pos"]
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

	return filled


# =============================================================================
# FLOW DIRECTION
# =============================================================================

func _find_downstream_cell(
	pos: Vector2i,
	filled_height: Dictionary,
	cells: Dictionary,
	width: int,
	height: int,
	profile: WorldProfile
) -> Vector2i:
	var raw_current: float = cells[pos].height
	var current_filled: float = float(filled_height.get(pos, raw_current))

	var best_pos: Vector2i = pos
	var best_drop: float = 0.0

	for offset in D8_OFFSETS:
		var neighbor: Vector2i = pos + offset
		if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
			continue
		if not cells.has(neighbor):
			continue

		var neighbor_raw: float = cells[neighbor].height
		# Physical terrain constraint: rivers and gravity flow strictly downhill
		if neighbor_raw > raw_current + 0.0001:
			continue

		var neighbor_filled: float = float(filled_height.get(neighbor, neighbor_raw))
		var distance: float = (1.41421356 if offset.x != 0 and offset.y != 0 else 1.0) * profile.cell_size

		# Drop prioritized by filled surface gradient to guide drainage basins
		var drop: float = (current_filled - neighbor_filled) / maxf(distance, 0.001)

		# If filled surface is flat locally, fall back to raw terrain drop
		if drop <= 0.0001:
			drop = (raw_current - neighbor_raw) / maxf(distance, 0.001)

		if drop > best_drop:
			best_drop = drop
			best_pos = neighbor

	if best_pos != pos:
		return best_pos

	# If no strictly lower neighbor exists, check if there's a flat neighbor that drains toward boundary
	# without going uphill
	var boundary_distance: float = minf(
		minf(float(pos.x), float(width - 1 - pos.x)),
		minf(float(pos.y), float(height - 1 - pos.y))
	)

	var best_boundary_score: float = boundary_distance
	var boundary_pos: Vector2i = pos

	for offset in D8_OFFSETS:
		var neighbor: Vector2i = pos + offset
		if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
			continue
		if not cells.has(neighbor):
			continue

		var neighbor_raw: float = cells[neighbor].height
		if neighbor_raw > raw_current + 0.0001:
			continue

		var neighbor_boundary_distance: float = minf(
			minf(float(neighbor.x), float(width - 1 - neighbor.x)),
			minf(float(neighbor.y), float(height - 1 - neighbor.y))
		)

		if neighbor_boundary_distance < best_boundary_score:
			best_boundary_score = neighbor_boundary_distance
			boundary_pos = neighbor

	return boundary_pos


# =============================================================================
# RIVER TRACE
# =============================================================================

func _trace_river(
	source: Vector2i,
	flow_to: Dictionary,
	accumulation: Dictionary,
	hydro: RefCounted,
	cells: Dictionary,
	width: int,
	height: int,
	profile: WorldProfile,
	channel_threshold: float
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var visited: Dictionary = {}
	var current: Vector2i = source

	for step in range(profile.river_max_steps):
		if current.x < 0 or current.x >= width or current.y < 0 or current.y >= height:
			break
		if visited.has(current):
			break

		visited[current] = true
		path.append(current)

		if hydro.is_lake(current):
			break

		if path.size() > 1 and hydro.is_river(current):
			break

		var next_pos: Vector2i = flow_to.get(current, current)
		if next_pos == current:
			break

		# Topographic Gravity Law: water cannot flow uphill
		if cells[next_pos].height > cells[current].height + 0.0001:
			break

		current = next_pos

	return path


# =============================================================================
# RIVER DATA
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
		var acc_factor: float = clampf(log(acc + 1.0) / maxf(log(max_acc + 1.0), 0.001), 0.0, 1.0)

		# Accumulation controls river width naturally
		var width: float = lerpf(profile.river_min_width, profile.river_max_width, acc_factor)
		width = maxf(width, profile.river_min_width * 0.85)
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

		# Controlled meander guided by continuous hydrology noise in physical metric space
		var meander_offset := Vector2.ZERO
		if profile.hydrology_noise_enabled and hydro_noise != null:
			var sample_x: float = float(pos.x) * profile.cell_size
			var sample_z: float = float(pos.y) * profile.cell_size
			var noise_val: float = hydro_noise.get_noise_2d(sample_x, sample_z)
			var angle: float = (noise_val + 1.0) * 0.5 * TAU
			meander_offset = Vector2(cos(angle), sin(angle)) * profile.river_meander_strength * width

		var target_y: float = cell.height + 0.05
		if i > 0 and target_y > points[i - 1].y:
			target_y = points[i - 1].y

		var world_point := Vector3(
			world_x + meander_offset.x,
			target_y,
			world_z + meander_offset.y
		)
		points.append(world_point)

		var depth: float = lerpf(0.15, 0.65, acc_factor)

		if not hydro.is_lake(pos):
			hydro.water_cells[pos] = {
				"type": "river",
				"water_height": target_y,
				"terrain_height": cell.height,
				"depth": depth,
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
