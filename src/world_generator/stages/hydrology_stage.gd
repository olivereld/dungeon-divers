class_name HydrologyStage
extends WorldStage

## Generación Procedural de Ríos Realistas en Godot
##
## Principio Arquitectónico:
## Separación estricta de la Verdad Hidrológica de la Geometría de Presentación.
##
## Autoridad causal:
##   H_raw -> H_filled -> ∇H -> Flow Field -> Basins -> Accumulation ->
##   River Network -> River Geometry -> Carving
##
## Bloques de Ejecución:
##   1. H_raw & Priority-Flood (H_filled)
##   2. Gradient analítico continuo (∇H_filled) & Flow Field
##   3. Discretización D8 guiada por gradiente y continuidad direccional
##   4. Delimitación de Cuencas Hidrográficas (Basins / Watersheds) & Outlets
##   5. Acumulación Topológica de Flujo con aporte de lagos
##   6. Selección Determinista de Fuentes / Cabeceras (Headwaters)
##   7. Trazado de Trayectorias y Red Hidrográfica (River Network)
##   8. Nodos de Confluencia y Conexión de Lagos (River -> Lake -> Spillway -> River)
##   9. Geometría, Orden Hidrográfico y Meandros Controlados por Valle
##  10. Esculpido Geomorfológico del Lecho (Carving sobre H_raw)
##  11. Exportación de Capas de Depuración en HydrologyResult

const _HydrologyResultScript = preload("res://src/world_generator/hydrology/hydrology_result.gd")
const _FlowDiscretizationMetricsScript = preload("res://src/world_generator/diagnostics/flow_discretization_metrics.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetworkScript = preload("res://src/world_generator/hydrology/river_network.gd")

# Constantes del Pipeline Hidrológico (Fase 7)
const FLOW_FLAT_TOLERANCE: float = 0.0001
const FLOW_DIRECTION_CONTINUITY: float = 0.35
const MIN_BASIN_AREA: int = 16
const HEADWATER_MIN_SCORE: float = 0.25
const HEADWATER_MIN_DISTANCE: float = 14.0
const HEADWATER_MIN_LENGTH: float = 8.0
const CHANNEL_DEPTH_FACTOR: float = 0.45
const BANK_WIDTH_FACTOR: float = 1.60
const MEANDER_STRENGTH: float = 0.30
const MEANDER_SLOPE_LIMIT: float = 15.0

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

## Min-heap binario O(N log N) para resolución de depresiones por Priority-Flood
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
	# 0. RUIDO SECUNDARIO (Meandros e irregularidad controlada)
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

	# Capas de depuración solicitadas (Fase 8.1)
	var debug_noise: Dictionary = {}
	var debug_lake_potential: Dictionary = {}
	var debug_river_potential: Dictionary = {}
	var debug_drainage: Dictionary = {}
	var debug_flow_dir: Dictionary = {}
	var debug_flow_vector: Dictionary = {}
	var debug_raw_height: Dictionary = {}
	var debug_filled_height: Dictionary = {}
	var debug_slope: Dictionary = {}

	# -------------------------------------------------------------------------
	# BLOQUE 1: TOPOGRAFÍA BASE (H_raw) Y RESOLUCIÓN DE LAGOS
	# -------------------------------------------------------------------------
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var cell: WorldCell = cells.get(pos)
			if cell == null:
				continue
			if cell.raw_height == 0.0 and cell.height != 0.0:
				cell.raw_height = cell.height
			debug_raw_height[pos] = cell.raw_height
			debug_slope[pos] = cell.slope

			var sample_x: float = float(x) * profile.cell_size
			var sample_y: float = float(y) * profile.cell_size
			var noise_raw: float = 0.0
			if profile.hydrology_noise_enabled:
				noise_raw = hydro_noise.get_noise_2d(sample_x, sample_y)
			debug_noise[pos] = clampf((noise_raw + 1.0) * 0.5, 0.0, 1.0)

			var lake_pot: float = 0.0
			if cell.normalized_height < profile.lake_threshold:
				lake_pot = 1.0 - (cell.normalized_height / maxf(profile.lake_threshold, 0.001))
			debug_lake_potential[pos] = clampf(lake_pot, 0.0, 1.0)

	# Priority-Flood para calcular H_filled sin alterar H_raw
	var flood_data := _build_filled_height_field(cells, width, height)
	var filled_height: Dictionary = flood_data["filled"]
	var flood_rank: Dictionary = flood_data["flood_rank"]

	# Lagos: depresión de terreno y cálculo de spillways causales usando flood_rank
	_generate_lakes(cells, hydro, debug_drainage, flood_rank, filled_height, width, height, profile)

	for pos in filled_height:
		debug_filled_height[pos] = filled_height[pos]

	# -------------------------------------------------------------------------
	# BLOQUE 2: GRADIENTE ANALÍTICO CONTINUO (∇H) Y FLOW FIELD
	# -------------------------------------------------------------------------
	var flow_field_data := _build_gradient_and_flow_field(
		filled_height, flood_rank, width, height, profile.cell_size
	)
	var continuous_flow: Dictionary = flow_field_data["flow_vectors"]
	var gradient_magnitudes: Dictionary = flow_field_data["magnitudes"]

	for pos in continuous_flow:
		debug_flow_vector[pos] = continuous_flow[pos]

	# -------------------------------------------------------------------------
	# BLOQUE 3: DISCRETIZACIÓN DEL FLOW FIELD A GRILLA (D8 GUIADO POR GRADIENTE)
	# -------------------------------------------------------------------------
	var candidate_scores: Dictionary = {}
	var record_scores = candidate_scores if profile.hydrology_debug_metrics_enabled else null
	var flow_to := _discretize_flow_field(
		cells, filled_height, flood_rank, continuous_flow,
		hydro, width, height, profile, record_scores
	)

	if profile.hydrology_debug_metrics_enabled:
		var flow_metrics := _FlowDiscretizationMetricsScript.measure(
			cells, flow_to, continuous_flow, hydro, width, height, candidate_scores
		)
		hydro.set_debug_grid("flow_metrics", flow_metrics)

	for pos in flow_to:
		var nxt: Vector2i = flow_to[pos]
		if nxt != pos:
			debug_flow_dir[pos] = Vector2(float(nxt.x - pos.x), float(nxt.y - pos.y)).normalized()
		else:
			debug_flow_dir[pos] = Vector2.ZERO

	# -------------------------------------------------------------------------
	# BLOQUE 4: DELIMITACIÓN DE CUENCAS HIDROGRÁFICAS (BASINS / WATERSHEDS)
	# -------------------------------------------------------------------------
	var basins_result := _delimit_basins(flow_to, cells, hydro, width, height)
	hydro.basins = basins_result["basins"]
	var cell_basin_map: Dictionary = basins_result["cell_basin_map"]

	# -------------------------------------------------------------------------
	# BLOQUE 5: ACUMULACIÓN TOPOLÓGICA DE FLUJO
	# -------------------------------------------------------------------------
	var accumulation_data := _compute_flow_accumulation(
		flow_to, cells, hydro, width, height, profile.cell_size
	)
	var accumulation: Dictionary = accumulation_data["accumulation"]
	var upstream: Dictionary = accumulation_data["upstream"]

	var max_acc: float = 1.0
	for pos in accumulation:
		var a: float = float(accumulation[pos])
		if a > max_acc:
			max_acc = a
		debug_drainage[pos] = a

	# -------------------------------------------------------------------------
	# BLOQUE 6: SELECCIÓN DETERMINISTA DE FUENTES / CABECERAS (HEADWATERS)
	# -------------------------------------------------------------------------
	var total_cells: int = width * height
	var tributary_threshold: float = maxf(4.0, float(total_cells) * 0.0008)
	var main_channel_threshold: float = maxf(8.0, float(total_cells) * 0.0020)

	var channel_mask: Dictionary = {}
	for pos in accumulation:
		if float(accumulation[pos]) >= tributary_threshold and not hydro.is_lake(pos):
			channel_mask[pos] = true

	var headwaters := _select_headwaters(
		cells, flow_to, accumulation, upstream, cell_basin_map,
		hydro.basins, hydro, width, height, profile
	)

	# -------------------------------------------------------------------------
	# BLOQUE 7 & 8: RED HIDROGRÁFICA (RIVER NETWORK) Y CONFLUENCIAS
	# -------------------------------------------------------------------------
	var river_network_result := _trace_river_network(
		headwaters, flow_to, accumulation, channel_mask,
		hydro, width, height, profile, main_channel_threshold
	)
	var network_rivers: Array = river_network_result["rivers"]
	hydro.confluences = river_network_result["confluences"]

	# Construir RiverNetwork explícito
	var river_net_inst = _RiverNetworkScript.new()
	river_net_inst.sources = headwaters
	river_net_inst.confluences = hydro.confluences
	river_net_inst.lakes = hydro.lakes
	river_net_inst.outlets = basins_result["outlets"]
	for r in network_rivers:
		river_net_inst.add_river(r)

	hydro.river_network = river_net_inst

	# -------------------------------------------------------------------------
	# BLOQUE 9: GEOMETRÍA, ORDEN HIDROGRÁFICO Y MEANDROS CONTROLADOS
	# -------------------------------------------------------------------------
	var validated_rivers: Array = []
	var river_max_acc: Dictionary = {}

	for river_obj in network_rivers:
		var r_id: int = river_obj.id
		var local_max_acc: float = 1.0
		for p in river_obj.path:
			local_max_acc = maxf(local_max_acc, float(accumulation.get(p, 1.0)))
		river_max_acc[r_id] = local_max_acc

	for river_obj in network_rivers:
		var r_id: int = river_obj.id
		var river_geom := _build_river_geometry(
			river_obj, accumulation, cells,
			profile, hydro, hydro_noise, river_max_acc.get(r_id, max_acc)
		)
		validated_rivers.append(river_geom)
		hydro.rivers.append(river_geom)

	# -------------------------------------------------------------------------
	# BLOQUE 10: ESCULPIDO DEL CAUCE EN EL TERRENO (RIVER CARVING SOBRE H_raw)
	# -------------------------------------------------------------------------
	_carve_river_channels(cells, validated_rivers, accumulation, width, height, profile, hydro)

	# -------------------------------------------------------------------------
	# BLOQUE 11: EXPORTACIÓN DE CAPAS DE DEPURACIÓN (Fase 8.1)
	# -------------------------------------------------------------------------
	hydro.set_debug_grid("noise", debug_noise)
	hydro.set_debug_grid("lake_potential", debug_lake_potential)
	hydro.set_debug_grid("river_potential", debug_river_potential)
	hydro.set_debug_grid("drainage", debug_drainage)
	hydro.set_debug_grid("flow_dir", debug_flow_dir)
	hydro.set_debug_grid("flow_vector", debug_flow_vector)
	hydro.set_debug_grid("flow_to", flow_to)
	hydro.set_debug_grid("upstream", upstream)
	hydro.set_debug_grid("basins", cell_basin_map)
	hydro.set_debug_grid("raw_height", debug_raw_height)
	hydro.set_debug_grid("filled_height", debug_filled_height)
	hydro.set_debug_grid("flood_rank", flood_rank)
	hydro.set_debug_grid("channel_mask", channel_mask)


# =============================================================================
# BLOQUE 1: LAGOS Y PRIORITY-FLOOD (H_raw -> H_filled)
# =============================================================================

func _generate_lakes(
	cells: Dictionary,
	hydro: RefCounted,
	debug_drainage: Dictionary,
	flood_rank: Dictionary,
	filled_height: Dictionary,
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

				for offset in D8_OFFSETS:
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
			var max_cluster_h: float = -INF
			for pos in cluster:
				cluster_set[pos] = true
				var c_cell: WorldCell = cells.get(pos)
				if c_cell != null:
					var ch: float = c_cell.raw_height if c_cell.raw_height != 0.0 else c_cell.height
					if ch > max_cluster_h:
						max_cluster_h = ch

			var min_rank: int = 999999999
			var spillway_pos: Vector2i = cluster[0]
			var spillway_height: float = INF

			# El spillway causal es el vecino de tierra firme con MENOR flood_rank (salida natural hacia el mar)
			for pos in cluster:
				for offset in D8_OFFSETS:
					var neighbor: Vector2i = pos + offset
					if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
						continue
					if cluster_set.has(neighbor):
						continue

					var neighbor_cell: WorldCell = cells.get(neighbor)
					if neighbor_cell == null:
						continue
					if neighbor_cell.normalized_height < profile.lake_threshold:
						continue

					var r_val: int = flood_rank.get(neighbor, 999999999)
					if r_val < min_rank:
						min_rank = r_val
						spillway_pos = neighbor
						spillway_height = float(filled_height.get(neighbor, neighbor_cell.raw_height))

			if is_inf(spillway_height):
				# Fallback a vecino perimetral cualquiera si toda la vecindad inmediata fuera lago
				for pos in cluster:
					for offset in D8_OFFSETS:
						var neighbor: Vector2i = pos + offset
						if neighbor.x >= 0 and neighbor.x < width and neighbor.y >= 0 and neighbor.y < height:
							if not cluster_set.has(neighbor):
								var nc: WorldCell = cells.get(neighbor)
								if nc != null:
									spillway_pos = neighbor
									spillway_height = float(filled_height.get(neighbor, nc.raw_height))
									break
					if not is_inf(spillway_height):
						break
				if is_inf(spillway_height):
					spillway_height = start_cell.raw_height

			if max_cluster_h > spillway_height:
				spillway_height = max_cluster_h

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
				var c_h: float = cell.raw_height if cell.raw_height != 0.0 else cell.height
				var depth: float = maxf(0.0, spillway_height - c_h)

				hydro.water_cells[pos] = {
					"type": "lake",
					"water_height": spillway_height,
					"terrain_height": c_h,
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


func _build_filled_height_field(
	cells: Dictionary,
	width: int,
	height: int
) -> Dictionary:
	var filled: Dictionary = {}
	var visited: Dictionary = {}
	var flood_rank: Dictionary = {}
	var pq := PriorityQueue.new()
	var rank_counter: int = 0

	# 1. Borde del mapa como outlets naturales
	for x in range(width):
		var p_top := Vector2i(x, 0)
		var p_bot := Vector2i(x, height - 1)
		if cells.has(p_top) and not visited.has(p_top):
			visited[p_top] = true
			var c: WorldCell = cells[p_top]
			var ch: float = c.raw_height if c.raw_height != 0.0 else c.height
			filled[p_top] = ch
			pq.push(p_top, ch)
		if cells.has(p_bot) and not visited.has(p_bot):
			visited[p_bot] = true
			var c: WorldCell = cells[p_bot]
			var ch: float = c.raw_height if c.raw_height != 0.0 else c.height
			filled[p_bot] = ch
			pq.push(p_bot, ch)

	for y in range(height):
		var p_left := Vector2i(0, y)
		var p_right := Vector2i(width - 1, y)
		if cells.has(p_left) and not visited.has(p_left):
			visited[p_left] = true
			var c: WorldCell = cells[p_left]
			var ch: float = c.raw_height if c.raw_height != 0.0 else c.height
			filled[p_left] = ch
			pq.push(p_left, ch)
		if cells.has(p_right) and not visited.has(p_right):
			visited[p_right] = true
			var c: WorldCell = cells[p_right]
			var ch: float = c.raw_height if c.raw_height != 0.0 else c.height
			filled[p_right] = ch
			pq.push(p_right, ch)

	# 2. Priority-Flood expande desde los bordes hacia el interior (Barnes et al. 2014)
	# Los lagos se llenan naturalmente al alcanzarse su cota de spillway desde el downstream.

	# 3. Main loop de Priority-Flood (Barnes et al. 2014)
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
			var neighbor_height: float = neighbor_cell.raw_height if neighbor_cell.raw_height != 0.0 else neighbor_cell.height

			var resolved_height: float = maxf(neighbor_height, current_filled)
			filled[neighbor] = resolved_height
			pq.push(neighbor, resolved_height)

	return {
		"filled": filled,
		"flood_rank": flood_rank
	}


# =============================================================================
# BLOQUE 2: GRADIENT ANALÍTICO CONTINUO (∇H_filled) Y FLOW FIELD
# =============================================================================

func _build_gradient_and_flow_field(
	filled_height: Dictionary,
	_flood_rank: Dictionary,
	width: int,
	height: int,
	cell_size: float
) -> Dictionary:
	var flow_vectors: Dictionary = {}
	var magnitudes: Dictionary = {}

	var inv_2_cell: float = 1.0 / (2.0 * cell_size)
	var inv_cell: float = 1.0 / cell_size

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var h_c: float = float(filled_height.get(pos, 0.0))

			# Diferencias finitas en X
			var dh_dx: float = 0.0
			if x > 0 and x < width - 1:
				var h_r: float = float(filled_height.get(Vector2i(x + 1, y), h_c))
				var h_l: float = float(filled_height.get(Vector2i(x - 1, y), h_c))
				dh_dx = (h_r - h_l) * inv_2_cell
			elif x == 0:
				var h_r: float = float(filled_height.get(Vector2i(x + 1, y), h_c))
				dh_dx = (h_r - h_c) * inv_cell
			else:
				var h_l: float = float(filled_height.get(Vector2i(x - 1, y), h_c))
				dh_dx = (h_c - h_l) * inv_cell

			# Diferencias finitas en Z (Y en grilla 2D)
			var dh_dz: float = 0.0
			if y > 0 and y < height - 1:
				var h_d: float = float(filled_height.get(Vector2i(x, y + 1), h_c))
				var h_u: float = float(filled_height.get(Vector2i(x, y - 1), h_c))
				dh_dz = (h_d - h_u) * inv_2_cell
			elif y == 0:
				var h_d: float = float(filled_height.get(Vector2i(x, y + 1), h_c))
				dh_dz = (h_d - h_c) * inv_cell
			else:
				var h_u: float = float(filled_height.get(Vector2i(x, y - 1), h_c))
				dh_dz = (h_c - h_u) * inv_cell

			# Vector de descenso físico: F = -∇H
			var f_vec := Vector2(-dh_dx, -dh_dz)
			var mag: float = f_vec.length()

			magnitudes[pos] = mag
			if mag > FLOW_FLAT_TOLERANCE:
				flow_vectors[pos] = f_vec / mag
			else:
				flow_vectors[pos] = Vector2.ZERO

	return {
		"flow_vectors": flow_vectors,
		"magnitudes": magnitudes
	}


# =============================================================================
# BLOQUE 3: DISCRETIZACIÓN DEL FLOW FIELD A GRILLA (D8)
# =============================================================================

func _discretize_flow_field(
	cells: Dictionary,
	filled_height: Dictionary,
	flood_rank: Dictionary,
	continuous_flow: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int,
	_profile: WorldProfile,
	debug_scores_out: Variant = null
) -> Dictionary:
	var flow_to: Dictionary = {}

	# 1. Mapeo de lagos a spillways
	var spillway_lake_cells: Dictionary = {}
	for lake in hydro.lakes:
		var spill_pos: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		var lake_cells: Array = lake.get("cells", [])
		var set_dict: Dictionary = {}
		for lc in lake_cells:
			set_dict[lc] = true
		spillway_lake_cells[spill_pos] = set_dict

	# 2. Las celdas de lago drenan directamente a su spillway (Topología en estrella)
	for lake in hydro.lakes:
		var spill_pos: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		for lc in lake.get("cells", []):
			flow_to[lc] = spill_pos

	# 3. Discretizar celdas terrestres guiadas por F = -∇H_filled y orden causal de flood_rank
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not cells.has(pos):
				continue
			if hydro.is_lake(pos):
				continue

			# Las celdas de borde son outlets naturales de salida del mapa (terminales)
			if pos.x == 0 or pos.x == width - 1 or pos.y == 0 or pos.y == height - 1:
				flow_to[pos] = pos
				continue

			var current_h: float = float(filled_height.get(pos, 0.0))
			var current_rank: int = flood_rank.get(pos, 999999999)
			var f_dir: Vector2 = continuous_flow.get(pos, Vector2.ZERO)

			var best_pos: Vector2i = pos
			var best_score: float = -INF
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

				var neighbor_h: float = float(filled_height.get(neighbor, 0.0))
				var neighbor_rank: int = flood_rank.get(neighbor, 999999999)

				# Restricción estricta de no-ascenso sobre H_filled
				if neighbor_h > current_h + 0.00001:
					continue

				var is_flat: bool = absf(current_h - neighbor_h) <= 0.00001
				if is_flat and neighbor_rank >= current_rank:
					continue  # En mesetas solo se avanza hacia menor flood_rank

				var dist: float = (1.41421356 if offset.x != 0 and offset.y != 0 else 1.0)
				var d_vec := Vector2(float(offset.x), float(offset.y)).normalized()
				var drop: float = (current_h - neighbor_h) / dist

				var score: float = 0.0
				if f_dir != Vector2.ZERO:
					var align: float = f_dir.dot(d_vec)
					var slope_factor: float = clampf(drop / 0.05, 0.0, 1.0)
					score = align * (1.0 + slope_factor) + drop * 0.5
				else:
					# En planos sin gradiente continuo, el flood_rank causal es la autoridad absoluta
					score = float(current_rank - neighbor_rank)

				if debug_scores_out != null:
					if not debug_scores_out.has(pos):
						debug_scores_out[pos] = []
					debug_scores_out[pos].append({
						"neighbor": neighbor,
						"score": score,
						"rank": neighbor_rank
					})

				if score > best_score + 0.0001:
					best_score = score
					best_pos = neighbor
					best_rank = neighbor_rank
				elif absf(score - best_score) <= 0.0001:
					if neighbor_rank < best_rank:
						best_pos = neighbor
						best_rank = neighbor_rank

			flow_to[pos] = best_pos

	return flow_to


# =============================================================================
# BLOQUE 4: CUENCAS HIDROGRÁFICAS (BASINS) Y OUTLETS
# =============================================================================

func _delimit_basins(
	flow_to: Dictionary,
	cells: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int
) -> Dictionary:
	var cell_basin_map: Dictionary = {}
	var basins: Dictionary = {}
	var next_basin_id: int = 1
	var terminal_to_basin: Dictionary = {}
	var outlets: Array[Vector2i] = []

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not cells.has(pos):
				continue
			if cell_basin_map.has(pos):
				continue

			var path: Array[Vector2i] = []
			var curr: Vector2i = pos
			var terminal: Vector2i = pos

			for _step in range(width + height + 50):
				path.append(curr)
				var nxt: Vector2i = flow_to.get(curr, curr)
				if nxt == curr:
					terminal = curr
					break
				if hydro.is_lake(curr):
					terminal = curr
					break
				if cell_basin_map.has(nxt):
					terminal = nxt
					break
				curr = nxt

			var b_id: int = 0
			if cell_basin_map.has(terminal):
				b_id = cell_basin_map[terminal]
			elif terminal_to_basin.has(terminal):
				b_id = terminal_to_basin[terminal]
			else:
				b_id = next_basin_id
				next_basin_id += 1
				terminal_to_basin[terminal] = b_id
				outlets.append(terminal)
				var term_cell: WorldCell = cells.get(terminal)
				var th: float = term_cell.raw_height if term_cell != null else 0.0
				basins[b_id] = {
					"id": b_id,
					"outlet": terminal,
					"area": 0,
					"cells": [],
					"min_elevation": th,
					"max_elevation": th,
					"max_accumulation": 0.0
				}

			for p in path:
				cell_basin_map[p] = b_id
				var b: Dictionary = basins[b_id]
				b["area"] += 1
				b["cells"].append(p)
				var c: WorldCell = cells.get(p)
				if c != null:
					var h_val: float = c.raw_height
					b["min_elevation"] = minf(float(b["min_elevation"]), h_val)
					b["max_elevation"] = maxf(float(b["max_elevation"]), h_val)

	return {
		"basins": basins,
		"cell_basin_map": cell_basin_map,
		"outlets": outlets
	}


# =============================================================================
# BLOQUE 5: ACUMULACIÓN TOPOLÓGICA DE FLUJO
# =============================================================================

func _compute_flow_accumulation(
	flow_to: Dictionary,
	cells: Dictionary,
	_hydro: RefCounted,
	width: int,
	height: int,
	_cell_size: float
) -> Dictionary:
	var accumulation: Dictionary = {}
	var in_degree: Dictionary = {}
	var upstream: Dictionary = {}

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if cells.has(pos):
				accumulation[pos] = 1.0
				in_degree[pos] = 0
				upstream[pos] = []

	for pos in flow_to:
		var downstream: Vector2i = flow_to[pos]
		if downstream != pos and in_degree.has(downstream):
			in_degree[downstream] = in_degree[downstream] + 1
			if not upstream.has(downstream):
				upstream[downstream] = []
			upstream[downstream].append(pos)

	# Algoritmo de Kahn para orden topológico desde cabeceras
	var queue: Array[Vector2i] = []
	for pos in in_degree:
		if in_degree[pos] == 0:
			queue.append(pos)

	var sorted_cells: Array[Vector2i] = []
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_back()
		sorted_cells.append(pos)
		var downstream: Vector2i = flow_to.get(pos, pos)
		if downstream != pos and in_degree.has(downstream):
			in_degree[downstream] -= 1
			if in_degree[downstream] == 0:
				queue.append(downstream)

	# Fallback de seguridad en caso de componentes no visitados
	if sorted_cells.size() < in_degree.size():
		for pos in in_degree:
			if in_degree[pos] > 0:
				sorted_cells.append(pos)

	# Propagar acumulación downstream
	for pos in sorted_cells:
		var downstream: Vector2i = flow_to.get(pos, pos)
		if downstream == pos:
			continue
		if not accumulation.has(downstream):
			accumulation[downstream] = 1.0
		accumulation[downstream] += accumulation.get(pos, 1.0)

	return {
		"accumulation": accumulation,
		"upstream": upstream
	}


# =============================================================================
# BLOQUE 6: SELECCIÓN DETERMINISTA DE CABECERAS (HEADWATERS)
# =============================================================================

func _select_headwaters(
	cells: Dictionary,
	flow_to: Dictionary,
	accumulation: Dictionary,
	upstream: Dictionary,
	cell_basin_map: Dictionary,
	basins: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int,
	profile: WorldProfile
) -> Array[Vector2i]:
	var candidates: Array[Dictionary] = []
	var total_cells: float = float(width * height)

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			if not cells.has(pos):
				continue
			if hydro.is_lake(pos):
				continue
			if flow_to.get(pos, pos) == pos:
				continue

			var up_list: Array = upstream.get(pos, [])
			if up_list.size() > 1:
				continue  # No empezar en confluencias interiores

			var cell: WorldCell = cells[pos]
			if cell.normalized_height < profile.river_source_min_height:
				continue

			# Rastrear longitud potencial downstream
			var curr: Vector2i = pos
			var potential_length: float = 0.0
			for _step in range(profile.river_max_steps):
				var nxt: Vector2i = flow_to.get(curr, curr)
				if nxt == curr or hydro.is_lake(nxt):
					break
				potential_length += 1.0
				curr = nxt

			if potential_length < HEADWATER_MIN_LENGTH:
				continue

			var b_id: int = cell_basin_map.get(pos, 0)
			var b_area: float = float(basins[b_id]["area"]) if basins.has(b_id) else 1.0

			var score: float = (
				0.30 * cell.normalized_height +
				0.25 * clampf(cell.slope / 45.0, 0.0, 1.0) +
				0.25 * clampf(potential_length / float(width + height), 0.0, 1.0) +
				0.20 * clampf(b_area / total_cells, 0.0, 1.0)
			)

			candidates.append({
				"pos": pos,
				"score": score
			})

	# Ordenar deterministamente por score descendente
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"]
	)

	# Filtrado espacial por HEADWATER_MIN_DISTANCE
	var accepted: Array[Vector2i] = []
	for cand in candidates:
		if accepted.size() >= profile.max_rivers:
			break
		var p: Vector2i = cand["pos"]
		var too_close: bool = false
		for acc_p in accepted:
			if float((p - acc_p).length()) < HEADWATER_MIN_DISTANCE:
				too_close = true
				break
		if not too_close:
			accepted.append(p)

	return accepted


# =============================================================================
# BLOQUES 7 & 8: RED HIDROGRÁFICA Y CONFLUENCIAS
# =============================================================================

func _trace_river_network(
	headwaters: Array[Vector2i],
	flow_to: Dictionary,
	accumulation: Dictionary,
	_channel_mask: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int,
	profile: WorldProfile,
	main_channel_threshold: float
) -> Dictionary:
	var rivers: Array = []
	var confluences: Array = []
	var river_cell_owner: Dictionary = {}  # pos -> river_id
	var rivers_by_id: Dictionary = {}      # id -> River
	var rendered_edges: Dictionary = {}    # "x,y->x,y" -> true
	var current_river_id: int = 0

	# 1. Trazar ríos desde las cabeceras aprobadas
	for head in headwaters:
		var path: Array[Vector2i] = [head]
		var curr: Vector2i = head
		var downstream_id: int = -1
		var confluence_pos: Vector2i = Vector2i(-1, -1)

		for _step in range(profile.river_max_steps):
			var nxt: Vector2i = flow_to.get(curr, curr)
			if nxt == curr:
				# Fin en el borde del mapa
				break

			var edge_key := "%d,%d->%d,%d" % [curr.x, curr.y, nxt.x, nxt.y]
			if rendered_edges.has(edge_key):
				break

			if hydro.is_lake(nxt):
				# Río entra en lago
				path.append(nxt)
				rendered_edges[edge_key] = true
				break

			if river_cell_owner.has(nxt):
				# Confluencia detectada
				path.append(nxt)
				rendered_edges[edge_key] = true
				downstream_id = river_cell_owner[nxt]
				confluence_pos = nxt
				break

			path.append(nxt)
			rendered_edges[edge_key] = true
			river_cell_owner[curr] = current_river_id
			curr = nxt

		if path.size() >= 5:
			var river_obj = _RiverScript.new(current_river_id, head, path)
			river_obj.accumulation_start = float(accumulation.get(path[0], 1.0))
			river_obj.accumulation_end = float(accumulation.get(path[-1], 1.0))
			river_obj.is_outflow = false
			river_obj.downstream_river = downstream_id

			if downstream_id != -1:
				river_obj.outlet = confluence_pos
				if rivers_by_id.has(downstream_id):
					var parent_river = rivers_by_id[downstream_id]
					if not parent_river.upstream_rivers.has(current_river_id):
						parent_river.upstream_rivers.append(current_river_id)

				confluences.append({
					"position": confluence_pos,
					"upstream_rivers": [current_river_id],
					"downstream_river": downstream_id
				})

			rivers.append(river_obj)
			rivers_by_id[current_river_id] = river_obj
			current_river_id += 1
		else:
			for i in range(path.size() - 1):
				var k := "%d,%d->%d,%d" % [path[i].x, path[i].y, path[i + 1].x, path[i + 1].y]
				rendered_edges.erase(k)
				river_cell_owner.erase(path[i])

	# 2. Emisión de ríos salientes desde spillways de lagos principales (Lake -> Spillway -> River)
	for lake in hydro.lakes:
		var spill: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		if spill == Vector2i(-1, -1):
			continue
		if float(accumulation.get(spill, 1.0)) < main_channel_threshold:
			continue
		if river_cell_owner.has(spill):
			continue  # Ya forma parte de un río existente

		var outflow_path: Array[Vector2i] = [spill]
		var curr_spill: Vector2i = spill
		var downstream_id: int = -1
		var confluence_pos: Vector2i = Vector2i(-1, -1)

		for _step in range(profile.river_max_steps):
			var nxt: Vector2i = flow_to.get(curr_spill, curr_spill)
			if nxt == curr_spill or hydro.is_lake(nxt):
				break

			var edge_key := "%d,%d->%d,%d" % [curr_spill.x, curr_spill.y, nxt.x, nxt.y]
			if rendered_edges.has(edge_key):
				break

			if river_cell_owner.has(nxt):
				outflow_path.append(nxt)
				rendered_edges[edge_key] = true
				downstream_id = river_cell_owner[nxt]
				confluence_pos = nxt
				break

			outflow_path.append(nxt)
			rendered_edges[edge_key] = true
			river_cell_owner[curr_spill] = current_river_id
			curr_spill = nxt

		if outflow_path.size() >= 5:
			var outflow_obj = _RiverScript.new(current_river_id, spill, outflow_path)
			outflow_obj.accumulation_start = float(accumulation.get(spill, 1.0))
			outflow_obj.accumulation_end = float(accumulation.get(outflow_path[-1], 1.0))
			outflow_obj.is_outflow = true
			outflow_obj.downstream_river = downstream_id

			if downstream_id != -1:
				outflow_obj.outlet = confluence_pos
				if rivers_by_id.has(downstream_id):
					var parent_river = rivers_by_id[downstream_id]
					if not parent_river.upstream_rivers.has(current_river_id):
						parent_river.upstream_rivers.append(current_river_id)

				confluences.append({
					"position": confluence_pos,
					"upstream_rivers": [current_river_id],
					"downstream_river": downstream_id
				})

			rivers.append(outflow_obj)
			rivers_by_id[current_river_id] = outflow_obj
			current_river_id += 1
		else:
			for i in range(outflow_path.size() - 1):
				var k := "%d,%d->%d,%d" % [outflow_path[i].x, outflow_path[i].y, outflow_path[i + 1].x, outflow_path[i + 1].y]
				rendered_edges.erase(k)
				river_cell_owner.erase(outflow_path[i])

	# 3. Calcular orden topológico de Strahler
	_calculate_strahler_orders(rivers)

	return {
		"rivers": rivers,
		"confluences": confluences
	}


func _calculate_strahler_orders(rivers: Array) -> void:
	var rivers_by_id: Dictionary = {}
	var in_degree: Dictionary = {}

	for r in rivers:
		rivers_by_id[r.id] = r
		in_degree[r.id] = r.upstream_rivers.size()

	var queue: Array = []
	for r in rivers:
		if in_degree[r.id] == 0:
			r.order = 1
			queue.append(r)

	while not queue.is_empty():
		var curr_r = queue.pop_front()
		var down_id: int = curr_r.downstream_river
		if down_id != -1 and rivers_by_id.has(down_id):
			in_degree[down_id] -= 1
			if in_degree[down_id] == 0:
				var down_r = rivers_by_id[down_id]
				var up_orders: Array[int] = []
				for up_id in down_r.upstream_rivers:
					if rivers_by_id.has(up_id):
						up_orders.append(rivers_by_id[up_id].order)

				if up_orders.is_empty():
					down_r.order = 1
				else:
					var max_o: int = 1
					for o in up_orders:
						if o > max_o:
							max_o = o
					var count_max: int = 0
					for o in up_orders:
						if o == max_o:
							count_max += 1

					if count_max >= 2:
						down_r.order = max_o + 1
					else:
						down_r.order = max_o

				queue.append(down_r)

	for r in rivers:
		if r.order <= 0:
			r.order = 1


# =============================================================================
# BLOQUE 9: GEOMETRÍA, ORDEN HIDROGRÁFICO Y MEANDROS CONTROLADOS
# =============================================================================

func _build_river_geometry(
	river_obj: RefCounted,
	accumulation: Dictionary,
	cells: Dictionary,
	profile: WorldProfile,
	hydro: RefCounted,
	noise: FastNoiseLite,
	network_max_acc: float
) -> Dictionary:
	var river_id: int = river_obj.id
	var path: Array[Vector2i] = river_obj.path
	var river_order: int = river_obj.order
	var points: Array[Vector3] = []
	var widths: Array[float] = []
	var depths: Array[float] = []
	var total_pts: int = path.size()

	for i in range(total_pts):
		var pos: Vector2i = path[i]
		var cell: WorldCell = cells[pos]
		var c_h: float = cell.raw_height if cell.raw_height != 0.0 else cell.height

		var acc: float = float(accumulation.get(pos, 1.0))
		var acc_norm: float = clampf(log(acc + 1.0) / maxf(log(network_max_acc + 1.0), 0.001), 0.0, 1.0)

		# Ancho y profundidad modulados hidrológicamente por acumulación, orden Strahler y pendiente
		var order_w_mult: float = 1.0 + float(river_order - 1) * 0.30
		var order_d_mult: float = 1.0 + float(river_order - 1) * 0.20
		var slope_w_factor: float = clampf(1.0 - (cell.slope / 45.0) * 0.25, 0.75, 1.0)

		var base_w: float = lerpf(profile.river_min_width, profile.river_max_width, pow(acc_norm, profile.river_width_response)) * order_w_mult * slope_w_factor
		var base_d: float = lerpf(profile.river_min_depth, minf(profile.river_max_depth, 0.45), pow(acc_norm, profile.river_depth_response)) * order_d_mult

		var pt := Vector3(float(pos.x), c_h, float(pos.y))

		# Meandro secundario controlado por valle y confinado con taper en extremos
		if i > 0 and i < total_pts - 1 and noise != null:
			var prev_pos: Vector2i = path[i - 1]
			var next_pos: Vector2i = path[i + 1]
			var tangent := Vector2(float(next_pos.x - prev_pos.x), float(next_pos.y - prev_pos.y)).normalized()
			var perp := Vector2(-tangent.y, tangent.x)

			var slope_factor: float = clampf(1.0 - (cell.slope / MEANDER_SLOPE_LIMIT), 0.0, 1.0)
			var n_val: float = noise.get_noise_2d(float(pos.x) * profile.cell_size * 2.0, float(pos.y) * profile.cell_size * 2.0)
			var cell_w: float = base_w / maxf(profile.cell_size, 0.01)
			var taper: float = sin((float(i) / float(total_pts - 1)) * PI)
			var meander_offset: Vector2 = perp * (n_val * MEANDER_STRENGTH * slope_factor * cell_w * 0.35 * taper)

			pt.x += meander_offset.x
			pt.z += meander_offset.y

		points.append(pt)
		widths.append(base_w)
		depths.append(base_d)

		# Registrar celda de río si no es lago
		if not hydro.is_lake(pos):
			var flow_d: Vector2 = Vector2.ZERO
			if i < total_pts - 1:
				var nxt_c: Vector2i = path[i + 1]
				flow_d = Vector2(float(nxt_c.x - pos.x), float(nxt_c.y - pos.y)).normalized()

			hydro.water_cells[pos] = {
				"type": "river",
				"water_height": c_h + 0.02,
				"terrain_height": c_h,
				"depth": base_d,
				"flow_dir": flow_d,
				"river_index": river_id
			}

	# Monotonía descendente obligatoria para evitar flujo ascendente (Regla A)
	for i in range(1, points.size()):
		if points[i].y > points[i - 1].y:
			points[i].y = points[i - 1].y

	# Continuidad de cota en desembocadura a lago
	if hydro.is_lake(path[-1]):
		var lake_data: Dictionary = hydro.get_cell_data(path[-1])
		var target_h: float = float(lake_data.get("water_height", points[-1].y))
		points[-1].y = target_h
		for j in range(points.size() - 2, -1, -1):
			if points[j].y < points[j + 1].y:
				points[j].y = points[j + 1].y

	# Continuidad de cota en nacimiento desde spillway
	if river_obj.is_outflow and hydro.is_lake(path[0]):
		var lake_data: Dictionary = hydro.get_cell_data(path[0])
		var spill_h: float = float(lake_data.get("water_height", points[0].y))
		points[0].y = spill_h

	river_obj.points = points
	river_obj.widths = widths
	river_obj.depths = depths

	return river_obj.to_dict()


# =============================================================================
# BLOQUE 10: ESCULPIDO DEL CAUCE EN EL TERRENO (RIVER CARVING SOBRE H_raw)
# =============================================================================

func _carve_river_channels(
	cells: Dictionary,
	rivers: Array,
	_accumulation: Dictionary,
	width: int,
	height: int,
	profile: WorldProfile,
	hydro: RefCounted
) -> void:
	var carved_cells: Dictionary = {}

	for river_data in rivers:
		var cells_arr: Array = river_data["cells"]
		var pts_arr: Array = river_data["points"]
		var depths_arr: Array = river_data["depths"]
		var widths_arr: Array = river_data["widths"]

		for i in range(cells_arr.size()):
			var center_cell: Vector2i = cells_arr[i]
			var d_max: float = depths_arr[i] * CHANNEL_DEPTH_FACTOR
			var w_val: float = widths_arr[i] * BANK_WIDTH_FACTOR
			var radius: int = maxi(1, int(ceil(w_val / profile.cell_size)))

			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var target_pos := Vector2i(center_cell.x + dx, center_cell.y + dy)
					if target_pos.x < 0 or target_pos.x >= width or target_pos.y < 0 or target_pos.y >= height:
						continue
					if hydro.is_lake(target_pos):
						continue

					var cell: WorldCell = cells.get(target_pos)
					if cell == null:
						continue

					var dist_m: float = float(dx * dx + dy * dy) * profile.cell_size
					dist_m = sqrt(dist_m)
					if dist_m > w_val:
						continue

					# Función de falloff suave en perfil cosinusoidal Profile(d) = cos^2(pi*d / (2W))
					var norm_dist: float = clampf(dist_m / w_val, 0.0, 1.0)
					var profile_falloff: float = cos(norm_dist * PI * 0.5)
					profile_falloff = profile_falloff * profile_falloff

					var carve_amount: float = d_max * profile_falloff
					var prev_carve: float = float(carved_cells.get(target_pos, 0.0))
					if carve_amount > prev_carve:
						carved_cells[target_pos] = carve_amount

	# Aplicar el tallado sobre cell.height respetando cell.raw_height intacto
	for pos in carved_cells:
		var cell: WorldCell = cells[pos]
		var carve: float = float(carved_cells[pos])
		cell.height = cell.raw_height - carve

	# Recalcular pendientes para celdas modificadas
	for pos in carved_cells:
		var x: int = pos.x
		var y: int = pos.y
		var cell: WorldCell = cells[pos]

		var h_left: float = cells[Vector2i(maxi(x - 1, 0), y)].height
		var h_right: float = cells[Vector2i(mini(x + 1, width - 1), y)].height
		var h_up: float = cells[Vector2i(x, maxi(y - 1, 0))].height
		var h_down: float = cells[Vector2i(x, mini(y + 1, height - 1))].height

		var grad_x := (h_right - h_left) / (2.0 * profile.cell_size)
		var grad_y := (h_down - h_up) / (2.0 * profile.cell_size)
		cell.slope = rad_to_deg(atan(sqrt(grad_x * grad_x + grad_y * grad_y)))
