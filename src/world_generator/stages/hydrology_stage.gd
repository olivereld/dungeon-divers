class_name HydrologyStage
extends WorldStage

## Generates hydrological features (planar depression lakes and downhill gravity-driven rivers).
## Strict separation: Hydrology operates upon the established terrain elevation and stores
## results into HydrologyResult without modifying WorldCell elevation or colors.
## Uses an independent continuous hydrology noise field to guide meanders and channel preference.

const _HydrologyResultScript = preload("res://src/world_generator/hydrology/hydrology_result.gd")

func execute(context: WorldGenerationContext) -> void:
	var profile: WorldProfile = context.profile
	var hydro = _HydrologyResultScript.new()
	context.result.hydrology = hydro

	if not profile.hydrology_enabled:
		return

	var width: int = profile.width
	var height: int = profile.height
	var cells: Dictionary = context.result.cells

	# --- 0. HYDROLOGY NOISE & DEBUG INITIALIZATION ---
	var hydro_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_HYDROLOGY, profile.hydrology_noise_seed_offset)
	var hydro_noise := FastNoiseLite.new()
	if profile.hydrology_noise_enabled:
		hydro_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		hydro_noise.seed = hydro_seed
		hydro_noise.frequency = profile.get_hydrology_noise_frequency()
		hydro_noise.fractal_octaves = profile.hydrology_noise_octaves

	var debug_noise: Dictionary = {}
	var debug_lake_pot: Dictionary = {}
	var debug_river_pot: Dictionary = {}
	var debug_drainage: Dictionary = {}
	var debug_flow_dir: Dictionary = {}

	# Precompute terrain gradient, hydrology noise, and base potential per cell
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var cell: WorldCell = cells.get(pos)
			if cell == null:
				continue

			var sample_x: float = float(x) * profile.cell_size
			var sample_y: float = float(y) * profile.cell_size
			var h_noise_raw: float = hydro_noise.get_noise_2d(sample_x, sample_y) if profile.hydrology_noise_enabled else 0.0
			var h_noise_norm: float = clampf((h_noise_raw + 1.0) * 0.5, 0.0, 1.0)
			debug_noise[pos] = h_noise_norm

			# Lake potential: proximity to depression threshold
			var lake_pot: float = 0.0
			if cell.normalized_height < profile.lake_threshold:
				lake_pot = 1.0 - (cell.normalized_height / maxf(profile.lake_threshold, 0.01))
			debug_lake_pot[pos] = clampf(lake_pot, 0.0, 1.0)

			# River potential: high slope + high elevation + favorable noise
			var slope_norm: float = clampf(cell.slope / 35.0, 0.0, 1.0)
			var river_pot: float = (slope_norm * 0.45) + (cell.normalized_height * 0.35) + (h_noise_norm * 0.20)
			debug_river_pot[pos] = clampf(river_pot, 0.0, 1.0)

			# Default flow accumulation and direction initialized
			debug_drainage[pos] = 0.0
			debug_flow_dir[pos] = Vector2.ZERO

	# --- 1. PLANAR LAKE BASINS (Depression Sinks) ---
	var lake_visited: Dictionary = {}
	var next_lake_id: int = 1

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if lake_visited.has(pos):
				continue

			var cell: WorldCell = cells.get(pos)
			if cell == null or cell.normalized_height >= profile.lake_threshold:
				continue

			# Flood fill / BFS contiguous low-lying depression
			var cluster_cells: Array[Vector2i] = []
			var queue: Array[Vector2i] = [pos]
			lake_visited[pos] = true

			var min_p := pos
			var max_p := pos

			while not queue.is_empty():
				var cur: Vector2i = queue.pop_front()
				cluster_cells.append(cur)

				min_p.x = mini(min_p.x, cur.x)
				min_p.y = mini(min_p.y, cur.y)
				max_p.x = maxi(max_p.x, cur.x)
				max_p.y = maxi(max_p.y, cur.y)

				for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var npos: Vector2i = cur + offset
					if npos.x < 0 or npos.x >= width or npos.y < 0 or npos.y >= height:
						continue
					if lake_visited.has(npos):
						continue
					var n_cell: WorldCell = cells.get(npos)
					if n_cell != null and n_cell.normalized_height < profile.lake_threshold:
						lake_visited[npos] = true
						queue.append(npos)

			# Discard bodies smaller than configurable minimum area
			if cluster_cells.size() < profile.lake_minimum_area:
				continue

			# Find spillway height (lowest terrain height on the perimeter rim)
			var cluster_set: Dictionary = {}
			for c_pos in cluster_cells:
				cluster_set[c_pos] = true

			var spillway_height: float = INF
			var spillway_pos: Vector2i = pos

			for c_pos in cluster_cells:
				for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var npos: Vector2i = c_pos + offset
					if npos.x < 0 or npos.x >= width or npos.y < 0 or npos.y >= height:
						continue
					if not cluster_set.has(npos):
						var n_cell: WorldCell = cells.get(npos)
						if n_cell != null and n_cell.height < spillway_height:
							spillway_height = n_cell.height
							spillway_pos = npos

			if is_inf(spillway_height):
				spillway_height = -INF
				for c_pos in cluster_cells:
					var c_cell: WorldCell = cells.get(c_pos)
					if c_cell.height > spillway_height:
						spillway_height = c_cell.height

			var lake_id: int = next_lake_id
			next_lake_id += 1

			for c_pos in cluster_cells:
				var c_cell: WorldCell = cells.get(c_pos)
				var depth: float = maxf(0.0, spillway_height - c_cell.height)
				hydro.water_cells[c_pos] = {
					"type": "lake",
					"water_height": spillway_height,
					"terrain_height": c_cell.height,
					"depth": depth,
					"lake_id": lake_id,
					"flow_dir": Vector2.ZERO
				}
				debug_drainage[c_pos] = maxf(debug_drainage.get(c_pos, 0.0), 10.0 + depth * 5.0)

			hydro.lakes.append({
				"id": lake_id,
				"water_height": spillway_height,
				"cells": cluster_cells,
				"spillway_pos": spillway_pos,
				"spillway_height": spillway_height,
				"min_pos": min_p,
				"max_pos": max_p
			})

	# --- 2. DOWNHILL RIVERS (Gravity & Hydrology Noise Channel Guidance) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = hydro_seed

	var num_rivers: int = profile.max_rivers
	var high_cells: Array[Vector2i] = []
	for y in range(4, height - 4):
		for x in range(4, width - 4):
			var pos := Vector2i(x, y)
			if hydro.is_lake(pos):
				continue
			var cell: WorldCell = cells.get(pos)
			if cell != null and cell.normalized_height >= profile.river_source_min_height and cell.slope >= profile.river_source_min_slope:
				high_cells.append(pos)

	# Shuffle candidate headwater sources deterministically
	for i in range(high_cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = high_cells[i]
		high_cells[i] = high_cells[j]
		high_cells[j] = tmp

	var rivers_formed: int = 0
	var river_candidates_tried: int = 0
	var neighbor_offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
	]

	while rivers_formed < num_rivers and river_candidates_tried < high_cells.size():
		var start_pos: Vector2i = high_cells[river_candidates_tried]
		river_candidates_tried += 1

		if hydro.is_water(start_pos):
			continue

		var river_path: Array[Vector2i] = [start_pos]
		var current: Vector2i = start_pos
		var visited_river_cells: Dictionary = { start_pos: true }

		for step in range(profile.river_max_steps):
			var cur_cell: WorldCell = cells.get(current)
			var best_neighbor: Vector2i = current
			var best_score: float = -INF
			var lowest_height: float = cur_cell.height

			# Find downhill descent among neighbors with hydrology noise channel bias
			for offset in neighbor_offsets:
				var npos: Vector2i = current + offset
				if npos.x < 0 or npos.x >= width or npos.y < 0 or npos.y >= height:
					continue
				if visited_river_cells.has(npos):
					continue

				var ncell: WorldCell = cells.get(npos)
				if ncell == null:
					continue

				# Must be strictly lower elevation (gravity downhill law: delta_h > 0)
				if ncell.height < cur_cell.height:
					var dist: float = (1.4142 if (offset.x != 0 and offset.y != 0) else 1.0) * profile.cell_size
					var slope_down: float = (cur_cell.height - ncell.height) / dist

					# Hydrology noise guides channel preference and meanders in world metric space
					var sample_nx: float = float(npos.x) * profile.cell_size
					var sample_ny: float = float(npos.y) * profile.cell_size
					var h_noise_val: float = hydro_noise.get_noise_2d(sample_nx, sample_ny) if profile.hydrology_noise_enabled else 0.0
					var noise_bias: float = h_noise_val * profile.hydrology_noise_strength
					var meander_jitter: float = (rng.randf() - 0.5) * profile.river_meander_strength * profile.cell_size

					var score: float = slope_down + noise_bias + meander_jitter

					if score > best_score:
						best_score = score
						best_neighbor = npos
						lowest_height = ncell.height

			# If no downhill neighbor exists, we reached a local pit or sink; terminate
			if best_neighbor == current or lowest_height >= cur_cell.height:
				break

			current = best_neighbor
			visited_river_cells[current] = true
			river_path.append(current)

			# If we flow into an existing lake or river, terminate flow into it
			if hydro.is_water(current):
				break

		var total_length: float = float(river_path.size()) * profile.cell_size
		if total_length >= profile.min_river_length:
			var river_index: int = rivers_formed
			rivers_formed += 1

			# Clamp path if it exceeds max_river_length
			var max_cells: int = int(profile.max_river_length / profile.cell_size)
			if river_path.size() > max_cells:
				river_path = river_path.slice(0, max_cells)

			var points_3d: Array[Vector3] = []
			var widths: Array[float] = []

			for p_idx in range(river_path.size()):
				var rpos: Vector2i = river_path[p_idx]
				var rcell: WorldCell = cells.get(rpos)
				var p_progress: float = float(p_idx) / float(maxi(river_path.size() - 1, 1))
				var w: float = lerpf(profile.river_min_width, profile.river_max_width, p_progress)
				widths.append(w)

				var flow_dir := Vector2.ZERO
				if p_idx < river_path.size() - 1:
					var diff: Vector2i = river_path[p_idx + 1] - rpos
					flow_dir = Vector2(diff.x, diff.y).normalized()
				elif p_idx > 0:
					var diff: Vector2i = rpos - river_path[p_idx - 1]
					flow_dir = Vector2(diff.x, diff.y).normalized()

				debug_flow_dir[rpos] = flow_dir
				debug_drainage[rpos] = float(p_idx + 1) * 2.0

				var world_pt := Vector3(
					float(rpos.x),
					rcell.height + 0.05,
					float(rpos.y)
				)
				points_3d.append(world_pt)

				if not hydro.is_lake(rpos):
					hydro.water_cells[rpos] = {
						"type": "river",
						"water_height": rcell.height + 0.05,
						"terrain_height": rcell.height,
						"depth": lerpf(0.15, 0.45, p_progress),
						"river_index": river_index,
						"flow_dir": flow_dir
					}

			hydro.rivers.append({
				"index": river_index,
				"points": points_3d,
				"widths": widths,
				"cells": river_path
			})

	# Store debug maps into hydro result
	hydro.set_debug_grid("noise", debug_noise)
	hydro.set_debug_grid("lake_potential", debug_lake_pot)
	hydro.set_debug_grid("river_potential", debug_river_pot)
	hydro.set_debug_grid("drainage", debug_drainage)
	hydro.set_debug_grid("flow_dir", debug_flow_dir)
