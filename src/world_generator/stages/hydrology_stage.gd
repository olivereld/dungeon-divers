class_name HydrologyStage
extends WorldStage

## Generates hydrological features (planar depression lakes and downhill gravity-driven rivers).
## Strict separation: Hydrology operates upon the established terrain elevation and stores
## results into HydrologyResult without modifying WorldCell elevation or colors.

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

			# Discard tiny single-tile puddles
			if cluster_cells.size() < 4:
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

			hydro.lakes.append({
				"id": lake_id,
				"water_height": spillway_height,
				"cells": cluster_cells,
				"spillway_pos": spillway_pos,
				"spillway_height": spillway_height,
				"min_pos": min_p,
				"max_pos": max_p
			})

	# --- 2. DOWNHILL RIVERS (Gravity & Steepest Descent) ---
	var hydro_seed: int = WorldSeedSystem.derive_seed(context.master_seed, WorldSeedSystem.DOMAIN_HYDROLOGY)
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
			if cell != null and cell.normalized_height > 0.65 and cell.slope > 4.0:
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

		for step in range(250):
			var cur_cell: WorldCell = cells.get(current)
			var lowest_neighbor: Vector2i = current
			var lowest_height: float = cur_cell.height

			# Find steepest descent among neighbors
			for offset in neighbor_offsets:
				var npos: Vector2i = current + offset
				if npos.x < 0 or npos.x >= width or npos.y < 0 or npos.y >= height:
					continue
				if visited_river_cells.has(npos):
					continue

				var ncell: WorldCell = cells.get(npos)
				if ncell == null:
					continue

				# Must be strictly lower elevation (gravity downhill law)
				if ncell.height < cur_cell.height:
					var dist: float = 1.4142 if (offset.x != 0 and offset.y != 0) else 1.0
					var slope_down: float = (cur_cell.height - ncell.height) / dist
					var jitter: float = (rng.randf() - 0.5) * 0.15 * profile.cell_size
					var effective_score: float = slope_down + jitter

					if effective_score > 0.0 and ncell.height < lowest_height:
						lowest_height = ncell.height
						lowest_neighbor = npos

			# If no downhill neighbor exists, we reached a local pit or sink; terminate
			if lowest_neighbor == current or lowest_height >= cur_cell.height:
				break

			current = lowest_neighbor
			visited_river_cells[current] = true
			river_path.append(current)

			# If we flow into an existing lake or river, terminate flow into it
			if hydro.is_water(current):
				break

		var total_length: float = float(river_path.size()) * profile.cell_size
		if total_length >= profile.min_river_length:
			var river_index: int = rivers_formed
			rivers_formed += 1

			var points_3d: Array[Vector3] = []
			var widths: Array[float] = []

			for p_idx in range(river_path.size()):
				var rpos: Vector2i = river_path[p_idx]
				var rcell: WorldCell = cells.get(rpos)
				var p_progress: float = float(p_idx) / float(maxi(river_path.size() - 1, 1))
				var w: float = lerpf(0.8, 2.0, p_progress) * profile.cell_size
				widths.append(w)

				var flow_dir := Vector2.ZERO
				if p_idx < river_path.size() - 1:
					var diff: Vector2i = river_path[p_idx + 1] - rpos
					flow_dir = Vector2(diff.x, diff.y).normalized()
				elif p_idx > 0:
					var diff: Vector2i = rpos - river_path[p_idx - 1]
					flow_dir = Vector2(diff.x, diff.y).normalized()

				var world_pt := Vector3(
					rpos.x * profile.cell_size,
					rcell.height + 0.05,
					rpos.y * profile.cell_size
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
