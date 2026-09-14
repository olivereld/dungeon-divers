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
const _HydraulicCarvingProfileScript = preload("res://src/world_generator/hydrology/hydraulic_carving_profile.gd")
const _RiverEndpointScript = preload("res://src/world_generator/hydrology/river_endpoint.gd")
const _LakeCandidateScript = preload("res://src/world_generator/hydrology/lake_candidate.gd")
const _HydraulicDestinationResolverScript = preload("res://src/world_generator/hydrology/hydraulic_destination_resolver.gd")
const _HydraulicBasinClassifierScript = preload("res://src/world_generator/hydrology/hydraulic_basin_classifier.gd")

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
		hydro, width, height, profile, main_channel_threshold,
		cells, filled_height
	)
	var network_rivers: Array = river_network_result["rivers"]
	hydro.confluences = river_network_result["confluences"]

	# -------------------------------------------------------------------------
	# BLOQUE 7B: RESOLUCIÓN DE ENDPOINTS FLUVIALES Y GENERACIÓN DE LAGOS (River -> Lake)
	# -------------------------------------------------------------------------
	_resolve_river_endpoints_and_lakes(
		cells, network_rivers, flow_to, accumulation, filled_height, flood_rank,
		basins_result["basins"], hydro, width, height, profile
	)

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

	# Conexión 3D continua de confluencias (snap de afluente a la centerline del receptor)
	var rivers_by_id: Dictionary = {}
	for r in validated_rivers:
		rivers_by_id[r.get("id", -1)] = r

	for r in validated_rivers:
		var down_id: int = int(r.get("downstream_river", -1))
		if down_id != -1 and rivers_by_id.has(down_id):
			var parent_r: Dictionary = rivers_by_id[down_id]
			var conf_pos: Vector2i = r.get("outlet", Vector2i(-1, -1))
			var k_parent: int = -1
			var p_path: Array = parent_r.get("path", [])
			for idx in range(p_path.size()):
				if p_path[idx] == conf_pos:
					k_parent = idx
					break
			var p_points: Array = parent_r.get("points", [])
			var pts_arr: Array = r.get("points", [])
			if k_parent != -1 and k_parent < p_points.size() and not pts_arr.is_empty():
				var target_pt: Vector3 = p_points[k_parent]
				pts_arr[-1] = Vector3(float(conf_pos.x), target_pt.y, float(conf_pos.y))
				if not r.get("widths", []).is_empty():
					r["widths"][-1] = maxf(r["widths"][-1], parent_r["widths"][k_parent] * 0.8)
				if not r.get("depths", []).is_empty():
					r["depths"][-1] = parent_r["depths"][k_parent]

				# Suavizar gradiente vertical en los últimos puntos del afluente hacia la confluencia
				var blend_steps: int = mini(4, pts_arr.size() - 1)
				for b in range(1, blend_steps):
					var idx: int = pts_arr.size() - 1 - b
					var frac: float = float(b) / float(blend_steps)
					var blended_y: float = lerpf(target_pt.y, pts_arr[idx].y, frac)
					pts_arr[idx] = Vector3(pts_arr[idx].x, blended_y, pts_arr[idx].z)

				# Garantizar monotonía descendente hacia el receptor sin caídas en retroceso
				for b in range(pts_arr.size() - 2, -1, -1):
					if pts_arr[b].y < pts_arr[b + 1].y:
						pts_arr[b] = Vector3(pts_arr[b].x, pts_arr[b + 1].y, pts_arr[b].z)

				# Resincronizar water_cells en la confluencia
				for b in range(blend_steps + 1):
					var idx: int = pts_arr.size() - 1 - b
					if idx < r.get("path", []).size():
						var p_cell: Vector2i = r["path"][idx]
						if hydro.water_cells.has(p_cell):
							var cur_d: float = float(r["depths"][idx]) if idx < r["depths"].size() else 0.25
							var f_b: float = maxf(cur_d * 0.75, 0.25)
							var w_h: float = pts_arr[idx].y - f_b
							var b_h: float = w_h - cur_d
							hydro.water_cells[p_cell]["water_height"] = w_h
							hydro.water_cells[p_cell]["bed_height"] = b_h
							hydro.water_cells[p_cell]["shoreline_height"] = pts_arr[idx].y

	# -------------------------------------------------------------------------
	# BLOQUE 10: ESCULPIDO DEL CAUCE EN EL TERRENO (RIVER CARVING SOBRE H_raw)
	# -------------------------------------------------------------------------
	_carve_river_channels(cells, validated_rivers, accumulation, width, height, profile, hydro)
	_carve_lake_basins(cells, hydro.lakes, width, height, profile, hydro)
	_relax_hydraulic_banks(cells, width, height, profile, hydro)

	# -------------------------------------------------------------------------
	# BLOQUE 10B.3: VALIDACIÓN HIDRÁULICA SOBRE H_carved (HYDRAULIC GROUND TRUTH)
	# -------------------------------------------------------------------------
	_validate_hydraulic_ground_truth(cells, width, height, profile, hydro)

	# -------------------------------------------------------------------------
	# BLOQUE 10C: ZONIFICACIÓN HIDROLÓGICA Y MÁSCARA DE EXCLUSIÓN PARA VEGETACIÓN
	# -------------------------------------------------------------------------
	_build_hydrology_zones(width, height, profile, hydro)

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
	hydro.set_debug_grid("hydrology_zones", hydro.zones)
	hydro.set_debug_grid("exclusion_mask", hydro.exclusion_mask)
	hydro.set_debug_grid("hydraulic_influence", hydro.hydraulic_influence)


# =============================================================================
# BLOQUE 1: LAGOS Y PRIORITY-FLOOD (H_raw -> H_filled)
# =============================================================================

# =============================================================================
# BLOQUE 7B: RESOLUCIÓN DE ENDPOINTS FLUVIALES Y GENERACIÓN DE LAGOS (River -> Lake)
# =============================================================================

func _resolve_river_endpoints_and_lakes(
	cells: Dictionary,
	network_rivers: Array,
	flow_to: Dictionary,
	accumulation: Dictionary,
	filled_height: Dictionary,
	flood_rank: Dictionary,
	basins: Dictionary,
	hydro: RefCounted,
	width: int,
	height: int,
	profile: WorldProfile
) -> void:
	var resolver = _HydraulicDestinationResolverScript.new()
	var basin_classifier = _HydraulicBasinClassifierScript.new()
	var river_cell_owner: Dictionary = {}
	for r in network_rivers:
		for p in r.path:
			if not river_cell_owner.has(p):
				river_cell_owner[p] = r.id

	var next_lake_id: int = 1
	var next_river_id: int = network_rivers.size()
	var visited_endpoints: Dictionary = {}

	var river_idx: int = 0
	while river_idx < network_rivers.size():
		var r = network_rivers[river_idx]
		river_idx += 1

		if r.path.is_empty():
			continue
		var end_pos: Vector2i = r.path[-1]
		if visited_endpoints.has(end_pos):
			continue
		visited_endpoints[end_pos] = true

		var end_cell: WorldCell = cells.get(end_pos)
		var end_elev: float = end_cell.raw_height if end_cell != null else 0.0
		var end_accum: float = float(accumulation.get(end_pos, 1.0))

		var endpoint = _RiverEndpointScript.new(r.id, end_pos, end_elev, end_accum)
		var dest: int = endpoint.destination_type
		if r.downstream_river != -1:
			dest = _RiverEndpointScript.DestinationType.JOIN_RIVER
			endpoint.destination_type = dest
			endpoint.target_river_id = r.downstream_river
		elif hydro.is_lake(end_pos):
			var existing_lake_id: int = int(hydro.water_cells[end_pos].get("lake_id", -1))
			dest = _RiverEndpointScript.DestinationType.LAKE
			endpoint.destination_type = dest
			endpoint.target_lake_id = existing_lake_id
			for lk_dict in hydro.lakes:
				if lk_dict.get("id", -1) == existing_lake_id:
					if not lk_dict.get("source_river_ids", []).has(r.id):
						lk_dict["source_river_ids"].append(r.id)
					if lk_dict.has("outflow_river_id") and lk_dict["outflow_river_id"] != -1:
						r.downstream_river = lk_dict["outflow_river_id"]
					break
			r.destination_type = dest
			continue
		else:
			dest = resolver.resolve_destination(
				endpoint, width, height, river_cell_owner, cells, flow_to, basins, filled_height
			)

		if dest == _RiverEndpointScript.DestinationType.LAKE:
			var lake = resolver.expand_lake_from_endpoint(
				endpoint, next_lake_id, cells, filled_height, flood_rank, width, height, profile.lake_minimum_area
			)
			if lake != null and not lake.cells.is_empty():
				next_lake_id += 1
				hydro.lakes.append(lake.to_dict())

				for c_pos in lake.cells:
					var cell: WorldCell = cells[c_pos]
					var c_h: float = cell.raw_height
					var eff_depth: float = maxf(lake.water_height - c_h, 0.40)
					hydro.water_cells[c_pos] = {
						"type": "lake",
						"raw_height": c_h,
						"shoreline_height": lake.water_height + 0.05,
						"water_height": lake.water_height,
						"bed_height": lake.water_height - eff_depth,
						"terrain_height": lake.water_height - eff_depth,
						"depth": eff_depth,
						"lake_id": lake.id,
						"flow_dir": Vector2.ZERO
					}

				# Emisión causal del río saliente desde el vertedero
				var outflow = resolver.trace_lake_outflow(
					lake, flow_to, accumulation, next_river_id, profile.river_max_steps, river_cell_owner,
					cells, filled_height, basin_classifier
				)
				if outflow != null:
					lake.outflow_river_id = next_river_id
					hydro.lakes[-1]["outflow_river_id"] = next_river_id
					r.downstream_river = next_river_id
					network_rivers.append(outflow)
					for p_out in outflow.path:
						river_cell_owner[p_out] = next_river_id
					next_river_id += 1
				elif lake.outflow_river_id != -1:
					r.downstream_river = lake.outflow_river_id
			else:
				endpoint.destination_type = _RiverEndpointScript.DestinationType.TERMINATE
		elif dest == _RiverEndpointScript.DestinationType.JOIN_RIVER:
			if r.downstream_river == -1 and endpoint.target_river_id != -1:
				r.downstream_river = endpoint.target_river_id
				r.outlet = end_pos
				hydro.confluences.append({
					"position": end_pos,
					"upstream_rivers": [r.id],
					"downstream_river": endpoint.target_river_id
				})

		# Si el río quedó sin desembocadura conectada (TERMINATE), buscar si hay un cuerpo de agua contiguo a <= 2.5 celdas
		if endpoint.destination_type == _RiverEndpointScript.DestinationType.TERMINATE and r.downstream_river == -1:
			# 1. Buscar si hay un lago adyacente o cercano (radio 2, distancia <= 2.5) para conectar
			var near_lake_id: int = -1
			var near_lake_pos := Vector2i(-1, -1)
			var min_lake_dist: float = 999.0
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					var cp := end_pos + Vector2i(dx, dy)
					if hydro.is_lake(cp):
						var d: float = Vector2(end_pos).distance_to(Vector2(cp))
						if d <= 2.5 and d < min_lake_dist:
							min_lake_dist = d
							near_lake_pos = cp
							near_lake_id = int(hydro.water_cells[cp].get("lake_id", -1))

			if near_lake_id != -1 and near_lake_pos != Vector2i(-1, -1):
				var bridge: Array[Vector2i] = _trace_grid_line(end_pos, near_lake_pos)
				for bp in bridge:
					if bp != end_pos:
						r.path.append(bp)
						river_cell_owner[bp] = r.id
				r.length = float(r.path.size())
				end_pos = near_lake_pos
				r.outlet = end_pos
				endpoint.destination_type = _RiverEndpointScript.DestinationType.LAKE
				endpoint.target_lake_id = near_lake_id
				for lk_dict in hydro.lakes:
					if lk_dict.get("id", -1) == near_lake_id:
						if not lk_dict.get("source_river_ids", []).has(r.id):
							lk_dict["source_river_ids"].append(r.id)
						if lk_dict.has("outflow_river_id") and lk_dict["outflow_river_id"] != -1:
							r.downstream_river = lk_dict["outflow_river_id"]
						break
			else:
				# 2. Buscar si hay otro río cercano (radio 2, distancia <= 2.5) para fusionar
				var near_river_id: int = -1
				var near_river_pos := Vector2i(-1, -1)
				var min_riv_dist: float = 999.0
				for dx in range(-2, 3):
					for dy in range(-2, 3):
						var cp := end_pos + Vector2i(dx, dy)
						if river_cell_owner.has(cp) and river_cell_owner[cp] != r.id:
							var d: float = Vector2(end_pos).distance_to(Vector2(cp))
							if d <= 2.5 and d < min_riv_dist:
								min_riv_dist = d
								near_river_pos = cp
								near_river_id = river_cell_owner[cp]

				if near_river_id != -1 and near_river_pos != Vector2i(-1, -1):
					var bridge: Array[Vector2i] = _trace_grid_line(end_pos, near_river_pos)
					for bp in bridge:
						if bp != end_pos:
							r.path.append(bp)
							river_cell_owner[bp] = r.id
					r.length = float(r.path.size())
					end_pos = near_river_pos
					r.downstream_river = near_river_id
					r.outlet = end_pos
					endpoint.destination_type = _RiverEndpointScript.DestinationType.JOIN_RIVER
					endpoint.target_river_id = near_river_id
					hydro.confluences.append({
						"position": end_pos,
						"upstream_rivers": [r.id],
						"downstream_river": near_river_id
					})

		r.destination_type = endpoint.destination_type


## Traza una línea continua en la grilla discreta entre p0 y p1 (algoritmo Bresenham)
func _trace_grid_line(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
	var line: Array[Vector2i] = []
	var dx: int = absi(p1.x - p0.x)
	var dy: int = -absi(p1.y - p0.y)
	var sx: int = 1 if p0.x < p1.x else -1
	var sy: int = 1 if p0.y < p1.y else -1
	var err: int = dx + dy
	var curr := p0

	while true:
		line.append(curr)
		if curr == p1:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			curr.x += sx
		if e2 <= dx:
			err += dx
			curr.y += sy

	return line


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

			# Fallback causal (Priority-Flood): garantizar que ninguna celda interior sea sumidero ciego.
			# Si ninguna celda cumplió el criterio de pendiente/gradiente, fluir hacia el vecino con menor flood_rank
			if best_pos == pos:
				var min_fallback_rank: int = 999999999
				for offset in D8_OFFSETS:
					var neighbor: Vector2i = pos + offset
					if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
						continue
					if not cells.has(neighbor):
						continue
					var n_rank: int = flood_rank.get(neighbor, 999999999)
					if n_rank < min_fallback_rank:
						min_fallback_rank = n_rank
						best_pos = neighbor

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

			# Rastrear longitud potencial downstream con continuidad a través de vertederos de lagos
			var curr: Vector2i = pos
			var potential_length: float = 0.0
			var max_river_steps: int = maxi(profile.river_max_steps, (width + height) * 4)
			var visited_trace: Dictionary = {}
			for _step in range(max_river_steps):
				visited_trace[curr] = true
				var nxt: Vector2i = flow_to.get(curr, curr)
				if nxt == curr or visited_trace.has(nxt):
					break
				if hydro.is_lake(nxt):
					var lk_id: int = hydro.water_cells.get(nxt, {}).get("lake_id", -1)
					var spill: Vector2i = Vector2i(-1, -1)
					for lk in hydro.lakes:
						if lk.id == lk_id:
							spill = lk.get("spillway_pos", Vector2i(-1, -1))
							break
					if spill != Vector2i(-1, -1) and spill != curr and not visited_trace.has(spill):
						potential_length += 2.0
						curr = spill
						continue
					else:
						potential_length += 1.0
						break
				potential_length += 1.0
				curr = nxt

			var min_req_len: float = maxf(profile.min_river_length, float(width + height) * 0.28)
			if potential_length < min_req_len:
				continue

			var b_id: int = cell_basin_map.get(pos, 0)
			var b_area: float = float(basins[b_id]["area"]) if basins.has(b_id) else 1.0

			var score: float = (
				0.60 * clampf(potential_length / float(width + height), 0.0, 1.0) +
				0.25 * cell.normalized_height +
				0.15 * clampf(b_area / total_cells, 0.0, 1.0)
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
	main_channel_threshold: float,
	cells: Dictionary = {},
	filled_height: Dictionary = {}
) -> Dictionary:
	var rivers: Array = []
	var confluences: Array = []
	var river_cell_owner: Dictionary = {}  # pos -> river_id
	var rivers_by_id: Dictionary = {}      # id -> River
	var rendered_edges: Dictionary = {}    # "x,y->x,y" -> true
	var lakes_with_inflow: Dictionary = {} # lake_id -> incoming_river_id
	var current_river_id: int = 0
	var min_acceptable_pts: int = mini(10, maxi(6, int(profile.min_river_length * 0.4)))
	var basin_classifier = _HydraulicBasinClassifierScript.new()

	# 1. Trazar ríos desde las cabeceras aprobadas
	for head in headwaters:
		var path: Array[Vector2i] = [head]
		var curr: Vector2i = head
		var downstream_id: int = -1
		var confluence_pos: Vector2i = Vector2i(-1, -1)

		var max_river_steps: int = maxi(profile.river_max_steps, (width + height) * 4)
		for _step in range(max_river_steps):
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
				var lk_id: int = hydro.water_cells.get(nxt, {}).get("lake_id", -1)
				if lk_id != -1:
					lakes_with_inflow[lk_id] = current_river_id
				break

			if river_cell_owner.has(nxt):
				# Confluencia detectada
				path.append(nxt)
				rendered_edges[edge_key] = true
				downstream_id = river_cell_owner[nxt]
				confluence_pos = nxt
				break

			# Fusión lateral inmediata con río contiguo a 1 celda de distancia en valles
			var lateral_merged: bool = false
			for offset in D8_OFFSETS:
				var adj: Vector2i = nxt + offset
				if river_cell_owner.has(adj):
					var other_id: int = river_cell_owner[adj]
					if other_id != current_river_id:
						path.append(nxt)
						path.append(adj)
						rendered_edges[edge_key] = true
						downstream_id = other_id
						confluence_pos = adj
						lateral_merged = true
						break
			if lateral_merged:
				break

			# Intercepción 1: Depresión topográfica cerrada (candidato a lago)
			if not cells.is_empty() and basin_classifier.is_local_depression(nxt, cells, filled_height, 0.05):
				if path.size() >= min_acceptable_pts:
					path.append(nxt)
					rendered_edges[edge_key] = true
					break

			# Intercepción 2: Zona de convergencia en valle plano (múltiples ríos convergiendo)
			if not cells.is_empty() and cells.has(nxt):
				var nxt_cell: WorldCell = cells[nxt]
				var nxt_slope: float = nxt_cell.slope if nxt_cell != null else 10.0
				if basin_classifier.detect_convergence_zone(river_cell_owner, nxt, nxt_slope, 3, 2.0):
					if path.size() >= min_acceptable_pts:
						path.append(nxt)
						rendered_edges[edge_key] = true
						# Empalmar formalmente con el río existente más cercano en radio 2
						var best_p := Vector2i(-1, -1)
						var best_dist: float = 999.0
						var best_id: int = -1
						for dx in range(-2, 3):
							for dy in range(-2, 3):
								var cp := nxt + Vector2i(dx, dy)
								if river_cell_owner.has(cp) and river_cell_owner[cp] != current_river_id:
									var d: float = Vector2(nxt).distance_to(Vector2(cp))
									if d < best_dist:
										best_dist = d
										best_p = cp
										best_id = river_cell_owner[cp]
						if best_p != Vector2i(-1, -1):
							var connector: Array[Vector2i] = _trace_grid_line(nxt, best_p)
							for step_p in connector:
								if step_p != nxt:
									path.append(step_p)
							downstream_id = best_id
							confluence_pos = best_p
						break

			path.append(nxt)
			rendered_edges[edge_key] = true
			river_cell_owner[curr] = current_river_id
			curr = nxt

		if path.size() >= min_acceptable_pts:
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
		var lake_has_inflow: bool = lakes_with_inflow.has(lake.id)
		if not lake_has_inflow and float(accumulation.get(spill, 1.0)) < main_channel_threshold:
			continue
		if river_cell_owner.has(spill):
			continue  # Ya forma parte de un río existente

		var outflow_path: Array[Vector2i] = [spill]
		var curr_spill: Vector2i = spill
		var downstream_id: int = -1
		var confluence_pos: Vector2i = Vector2i(-1, -1)

		var max_river_steps: int = maxi(profile.river_max_steps, (width + height) * 4)
		for _step in range(max_river_steps):
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

		if outflow_path.size() >= min_acceptable_pts:
			var outflow_obj = _RiverScript.new(current_river_id, spill, outflow_path)
			outflow_obj.accumulation_start = float(accumulation.get(spill, 1.0))
			outflow_obj.accumulation_end = float(accumulation.get(outflow_path[-1], 1.0))
			outflow_obj.is_outflow = true
			outflow_obj.downstream_river = downstream_id

			if lake_has_inflow:
				var in_r_id: int = lakes_with_inflow[lake.id]
				if rivers_by_id.has(in_r_id):
					var in_r = rivers_by_id[in_r_id]
					in_r.downstream_river = current_river_id
					outflow_obj.upstream_rivers.append(in_r_id)

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

		# Anclar la cota al punto más bajo del corredor transversal inmediato
		# para asegurar que el agua nunca quede por encima de la cota lateral del terreno
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var npos := Vector2i(pos.x + dx, pos.y + dy)
				if cells.has(npos):
					var nc: WorldCell = cells[npos]
					var n_h: float = nc.raw_height if nc.raw_height != 0.0 else nc.height
					if n_h < c_h:
						c_h = n_h

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
			var max_meander: float = cell_w * 0.35
			if meander_offset.length() > max_meander:
				meander_offset = meander_offset.normalized() * max_meander

			pt.x += meander_offset.x
			pt.z += meander_offset.y

			var m_cx: int = clampi(int(round(pt.x)), 0, profile.width - 1)
			var m_cy: int = clampi(int(round(pt.z)), 0, profile.height - 1)
			var m_cell: WorldCell = cells.get(Vector2i(m_cx, m_cy))
			if m_cell != null:
				var m_h: float = m_cell.raw_height if m_cell.raw_height != 0.0 else m_cell.height
				if m_h < c_h:
					c_h = m_h
			pt.y = c_h

		points.append(pt)
		widths.append(base_w)
		depths.append(base_d)

		# Registrar celda de río si no es lago
		if not hydro.is_lake(pos):
			var flow_d: Vector2 = Vector2.ZERO
			if i < total_pts - 1:
				var nxt_c: Vector2i = path[i + 1]
				flow_d = Vector2(float(nxt_c.x - pos.x), float(nxt_c.y - pos.y)).normalized()

			var f_b: float = maxf(base_d * 0.75, 0.25)
			var w_h: float = c_h - f_b
			var b_h: float = w_h - base_d
			hydro.water_cells[pos] = {
				"type": "river",
				"raw_height": c_h,
				"shoreline_height": c_h,
				"water_height": w_h,
				"bed_height": b_h,
				"terrain_height": b_h,
				"depth": base_d,
				"flow_dir": flow_d,
				"river_index": river_id
			}

	# Monotonía descendente obligatoria para evitar flujo ascendente (Regla A)
	for i in range(1, points.size()):
		if points[i].y > points[i - 1].y:
			points[i] = Vector3(points[i].x, points[i - 1].y, points[i].z)

	# Continuidad de cota en desembocadura a lago: la lámina de agua del río (centerline_y - f_b)
	# se ancla exactamente a la cota del lago (target_h) y propaga monotonía aguas arriba
	if hydro.is_lake(path[-1]):
		var lake_data: Dictionary = hydro.get_cell_data(path[-1])
		var target_h: float = float(lake_data.get("water_height", points[-1].y))
		var f_b_end: float = maxf(depths[-1] * 0.75, 0.25)
		var end_y: float = target_h + f_b_end
		points[-1] = Vector3(points[-1].x, end_y, points[-1].z)
		for j in range(points.size() - 2, -1, -1):
			if points[j].y < points[j + 1].y:
				var c_raw: float = cells[path[j]].raw_height if cells.has(path[j]) else points[j + 1].y
				var f_b_j: float = maxf(depths[j] * 0.75, 0.25)
				points[j] = Vector3(points[j].x, minf(points[j + 1].y, c_raw + f_b_j * 0.90), points[j].z)

	# Continuidad de cota en nacimiento desde spillway: el río que nace del lago
	# parte a la cota exacta spill_h del espejo de agua del lago
	if river_obj.is_outflow:
		var spill_h: float = -1.0
		for lake in hydro.lakes:
			if lake.get("outflow_river_id") == river_id or lake.get("spillway_pos") == path[0]:
				spill_h = float(lake.get("water_height", points[0].y))
				break
		if spill_h < 0.0 and hydro.is_lake(path[0]):
			var lake_data: Dictionary = hydro.get_cell_data(path[0])
			spill_h = float(lake_data.get("water_height", points[0].y))

		if spill_h >= 0.0:
			var f_b_start: float = maxf(depths[0] * 0.75, 0.25)
			points[0] = Vector3(points[0].x, spill_h + f_b_start, points[0].z)
			for j in range(1, points.size()):
				if points[j].y > points[j - 1].y:
					points[j] = Vector3(points[j].x, points[j - 1].y, points[j].z)

	# Sincronizar water_cells con las cotas definitivas de points[i].y
	for i in range(total_pts):
		var pos: Vector2i = path[i]
		if not hydro.is_lake(pos) and hydro.water_cells.has(pos):
			var f_b: float = maxf(depths[i] * 0.75, 0.25)
			var w_h: float = points[i].y - f_b
			var b_h: float = w_h - depths[i]
			hydro.water_cells[pos]["water_height"] = w_h
			hydro.water_cells[pos]["bed_height"] = b_h
			hydro.water_cells[pos]["terrain_height"] = b_h
			hydro.water_cells[pos]["shoreline_height"] = points[i].y

	river_obj.points = points
	river_obj.widths = widths
	river_obj.depths = depths

	return river_obj.to_dict()


# =============================================================================
# BLOQUE 10: ESCULPIDO DEL CAUCE EN EL TERRENO (HYDRAULIC TERRAIN CARVING V2)
# =============================================================================

## Función de perfil transversal continuo para excavación geomorfológica hidráulica.
## Garantiza continuidad C0 estricta en las regiones:
##   BED -> Transición sumergida -> WATERLINE (water_y exacto) -> Talud de orilla -> RAW
func _carve_profile(
	distance: float,
	water_y: float,
	bed_y: float,
	transition_params: Dictionary
) -> float:
	var mode: String = transition_params.get("mode", "centerline")
	var raw_y: float = float(transition_params.get("raw_y", water_y + 1.0))
	var freeboard: float = float(transition_params.get("freeboard", 0.25))

	if mode == "centerline":
		var bed_radius: float = float(transition_params.get("bed_radius", 0.5))
		var water_radius: float = float(transition_params.get("water_radius", 1.0))
		var bank_radius: float = float(transition_params.get("bank_radius", 3.0))
		var trans_w: float = maxf(water_radius - bed_radius, 0.001)
		var bank_w: float = maxf(bank_radius - water_radius, 0.001)
		var prof = _HydraulicCarvingProfileScript.create_for_river(
			water_y - bed_y,
			bed_radius,
			trans_w,
			bank_w,
			freeboard
		)
		return prof.evaluate_centerline(distance, water_y, raw_y)

	elif mode == "boundary":
		var submerged_width: float = float(transition_params.get("submerged_width", 2.0))
		var bank_width: float = float(transition_params.get("bank_width", 3.5))
		var prof = _HydraulicCarvingProfileScript.create_for_lake(
			water_y - bed_y,
			submerged_width,
			bank_width,
			freeboard
		)
		return prof.evaluate_boundary(distance, water_y, raw_y)

	return raw_y


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
	var cell_size: float = profile.cell_size if profile != null else 1.0

	var lake_rim_water_h: Dictionary = {}
	if hydro != null and "lakes" in hydro:
		for lk in hydro.lakes:
			var lk_w_h: float = float(lk.get("water_height", 0.0))
			for c_pos in lk.get("cells", []):
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nb := Vector2i(c_pos.x + dx, c_pos.y + dy)
						if not hydro.is_lake(nb):
							if not lake_rim_water_h.has(nb) or lk_w_h > lake_rim_water_h[nb]:
								lake_rim_water_h[nb] = lk_w_h

	for river_data in rivers:
		var pts_arr: Array = river_data.get("points", [])
		var depths_arr: Array = river_data.get("depths", [])
		var widths_arr: Array = river_data.get("widths", [])
		var num_pts: int = pts_arr.size()

		if num_pts < 2:
			continue

		for j in range(num_pts - 1):
			var p0_3d: Vector3 = pts_arr[j]
			var p1_3d: Vector3 = pts_arr[j + 1]
			var p0 := Vector2(p0_3d.x, p0_3d.z)
			var p1 := Vector2(p1_3d.x, p1_3d.z)
			var v := p1 - p0
			var len_sq: float = v.length_squared()
			var inv_len_sq: float = 1.0 / len_sq if len_sq > 0.00001 else 0.0

			var w0: float = float(widths_arr[j])
			var w1: float = float(widths_arr[j + 1])
			var d0: float = float(depths_arr[j])
			var d1: float = float(depths_arr[j + 1])

			var max_w: float = maxf(w0, w1)
			var max_w_river: float = max_w * 0.5
			var max_w_bank_slope: float = maxf(max_w_river * 1.5, cell_size * 6.0)
			var max_w_bank: float = max_w_river + max_w_bank_slope

			var min_cx: int = clampi(int(floor((minf(p0.x, p1.x) - max_w_bank) / cell_size)), 0, width - 1)
			var max_cx: int = clampi(int(ceil((maxf(p0.x, p1.x) + max_w_bank) / cell_size)), 0, width - 1)
			var min_cy: int = clampi(int(floor((minf(p0.y, p1.y) - max_w_bank) / cell_size)), 0, height - 1)
			var max_cy: int = clampi(int(ceil((maxf(p0.y, p1.y) + max_w_bank) / cell_size)), 0, height - 1)

			for cy in range(min_cy, max_cy + 1):
				for cx in range(min_cx, max_cx + 1):
					var target_pos := Vector2i(cx, cy)
					if hydro.is_lake(target_pos):
						continue

					var cell: WorldCell = cells.get(target_pos)
					if cell == null:
						continue

					var q := Vector2(float(cx), float(cy)) * cell_size
					var t: float = clampf((q - p0).dot(v) * inv_len_sq, 0.0, 1.0)
					var proj: Vector2 = p0 + v * t
					var dist_m: float = q.distance_to(proj)

					var cur_w: float = lerpf(w0, w1, t)
					var cur_d: float = lerpf(d0, d1, t)
					var cur_w_river: float = cur_w * 0.5
					var f_bank: float = maxf(cur_d * 0.75, 0.25)
					var centerline_y: float = lerpf(p0_3d.y, p1_3d.y, t)
					var water_y: float = centerline_y - f_bank

					var delta_h: float = maxf(0.0, cell.raw_height - water_y)
					var needed_bank_w: float = delta_h / 0.65
					var w_bank_slope: float = maxf(maxf(cur_w_river * 1.5, cell_size * 4.0), minf(needed_bank_w, cell_size * 10.0))
					var cur_w_bank: float = cur_w_river + w_bank_slope

					if dist_m > cur_w_bank:
						continue

					var carving_profile = _HydraulicCarvingProfileScript.create_for_river(
						cur_d,
						cur_w_river * 0.45,
						cur_w_river * 0.55,
						w_bank_slope,
						f_bank
					)

					var influence: float = carving_profile.evaluate_influence_centerline(dist_m)
					var carved_h: float = carving_profile.evaluate_carved_height_centerline(dist_m, water_y)
					var target_h: float = lerpf(cell.raw_height, carved_h, influence)
					target_h = minf(cell.raw_height, target_h)
					if lake_rim_water_h.has(target_pos) and not hydro.is_river(target_pos):
						target_h = maxf(target_h, float(lake_rim_water_h[target_pos]))

					var current_carved: float = float(carved_cells.get(target_pos, cell.raw_height))
					if target_h < current_carved:
						carved_cells[target_pos] = target_h
						if hydro != null:
							var old_inf: float = float(hydro.hydraulic_influence.get(target_pos, 0.0))
							hydro.hydraulic_influence[target_pos] = maxf(old_inf, influence)

	# Aplicar el tallado sobre cell.height respetando cell.raw_height intacto
	for pos in carved_cells:
		var cell: WorldCell = cells[pos]
		cell.height = float(carved_cells[pos])
		if hydro != null:
			cell.hydraulic_influence = float(hydro.hydraulic_influence.get(pos, 0.0))
		if hydro != null and hydro.water_cells.has(pos):
			hydro.water_cells[pos]["bed_height"] = cell.height
			hydro.water_cells[pos]["terrain_height"] = cell.height
			var cur_w_h: float = float(hydro.water_cells[pos].get("water_height", cell.height))
			if cur_w_h < cell.height:
				hydro.water_cells[pos]["water_height"] = cell.height
			hydro.water_cells[pos]["depth"] = maxf(0.0, float(hydro.water_cells[pos].get("water_height", cell.height)) - cell.height)

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


# =============================================================================
# BLOQUE 10B: ESCULPIDO DE CUENCAS Y TALUDES DE LAGOS (LAKE CARVING V2)
# =============================================================================

func _carve_lake_basins(
	cells: Dictionary,
	lakes: Array,
	width: int,
	height: int,
	profile: WorldProfile,
	hydro: RefCounted
) -> void:
	if lakes.is_empty():
		return

	var cell_size: float = profile.cell_size if profile != null else 1.0
	var w_lake_bank: float = cell_size * 3.5
	var carved_lake_cells: Dictionary = {}
	var lake_water_levels: Dictionary = {}

	for lake in lakes:
		var water_y: float = float(lake.get("water_height", 0.0))
		var cluster: Array = lake.get("cells", [])
		if cluster.is_empty():
			continue

		var lake_set: Dictionary = {}
		for p in cluster:
			lake_set[p] = true

		var min_pos: Vector2i = lake.get("min_pos", Vector2i(0, 0))
		var max_pos: Vector2i = lake.get("max_pos", Vector2i(width - 1, height - 1))
		var search_margin: int = clampi(int(ceil(w_lake_bank / cell_size)) + 1, 1, 6)

		var bx0: int = clampi(min_pos.x - search_margin, 0, width - 1)
		var bx1: int = clampi(max_pos.x + search_margin, 0, width - 1)
		var by0: int = clampi(min_pos.y - search_margin, 0, height - 1)
		var by1: int = clampi(max_pos.y + search_margin, 0, height - 1)

		# 1. Identificar celdas de contorno / borde del lago (boundary cells)
		var boundary_cells: Array[Vector2i] = []
		for p in cluster:
			var is_boundary: bool = false
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not lake_set.has(p + offset):
					is_boundary = true
					break
			if is_boundary:
				boundary_cells.append(p)
		if boundary_cells.is_empty():
			boundary_cells = cluster

		# 2. Esculpir lecho sumergido y talud exterior continuo con HydraulicCarvingProfile
		var min_bed_depth: float = 0.40
		var submerged_width: float = cell_size * 2.0
		var bank_freeboard: float = 0.30

		var lake_carving_profile = _HydraulicCarvingProfileScript.create_for_lake(
			min_bed_depth,
			submerged_width,
			w_lake_bank,
			bank_freeboard
		)

		for cy in range(by0, by1 + 1):
			for cx in range(bx0, bx1 + 1):
				var pos := Vector2i(cx, cy)
				var is_inside: bool = lake_set.has(pos)

				# No levantar taludes de tierra sobre desembocaduras o nacimientos de ríos
				if not is_inside and hydro != null and hydro.has_method("is_river") and hydro.is_river(pos):
					continue

				var cell: WorldCell = cells.get(pos)
				if cell == null:
					continue

				var raw_h: float = cell.raw_height if cell.raw_height != 0.0 else cell.height

				# Calcular distancia euclidiana mínima a las celdas de borde
				var min_dist_sq: float = INF
				for bp in boundary_cells:
					var dx: float = float(cx - bp.x)
					var dy: float = float(cy - bp.y)
					var dsq: float = dx * dx + dy * dy
					if dsq < min_dist_sq:
						min_dist_sq = dsq

				var dist_m: float = sqrt(min_dist_sq) * cell_size
				var signed_d: float = 0.0

				var target_h: float = raw_h
				var influence: float = 0.0

				if is_inside:
					# Dentro del lago: excavar el lecho para garantizar lecho sumergido continuo
					var cell_depth: float = min_bed_depth
					if hydro != null and hydro.water_cells.has(pos):
						cell_depth = float(hydro.water_cells[pos].get("depth", min_bed_depth))
					var bed_y: float = water_y - cell_depth
					target_h = minf(raw_h, bed_y)
					influence = 1.0
				else:
					# Fuera del lago: talud de orilla hacia el terreno natural circundante
					signed_d = dist_m - 0.5 * cell_size
					if signed_d >= w_lake_bank:
						continue
					influence = lake_carving_profile.evaluate_influence_boundary(signed_d)
					var bank_target: float = lerpf(raw_h, water_y, influence)
					target_h = minf(raw_h, bank_target)

				var current_h: float = float(carved_lake_cells.get(pos, cell.height))
				if target_h < current_h:
					carved_lake_cells[pos] = target_h
					lake_water_levels[pos] = water_y
					if hydro != null:
						var old_inf: float = float(hydro.hydraulic_influence.get(pos, 0.0))
						hydro.hydraulic_influence[pos] = maxf(old_inf, influence)

	# Aplicar el tallado sobre cell.height y sincronizar water_cells
	for pos in carved_lake_cells:
		var cell: WorldCell = cells[pos]
		cell.height = float(carved_lake_cells[pos])
		var w_y: float = float(lake_water_levels.get(pos, cell.height))
		if hydro != null:
			cell.hydraulic_influence = float(hydro.hydraulic_influence.get(pos, 0.0))
		if hydro != null and hydro.water_cells.has(pos):
			hydro.water_cells[pos]["bed_height"] = cell.height
			hydro.water_cells[pos]["terrain_height"] = cell.height
			if hydro.water_cells[pos].get("type") == "lake":
				hydro.water_cells[pos]["water_height"] = w_y
				hydro.water_cells[pos]["shoreline_height"] = w_y + 0.30
				hydro.water_cells[pos]["depth"] = maxf(0.0, w_y - cell.height)
			else:
				var cur_w_h: float = float(hydro.water_cells[pos].get("water_height", cell.height))
				if cur_w_h < cell.height:
					hydro.water_cells[pos]["water_height"] = cell.height
				hydro.water_cells[pos]["depth"] = maxf(0.0, float(hydro.water_cells[pos].get("water_height", cell.height)) - cell.height)

	# Recalcular pendientes para celdas modificadas
	for pos in carved_lake_cells:
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


# =============================================================================
# BLOQUE 10B.2: RESTRICCIÓN DE TALUD HIDRÁULICO (PREVENCIÓN DE PAREDES VERTICALES)
# =============================================================================

## Restringe la pendiente máxima exclusivamente en la zona de transición alrededor
## de los cauces y masas hidráulicas, distribuyendo el desnivel suavemente hacia H_raw.
func _relax_hydraulic_banks(
	cells: Dictionary,
	width: int,
	height: int,
	profile: WorldProfile,
	hydro: RefCounted
) -> void:
	if hydro == null or hydro.water_cells.is_empty():
		return

	var cell_size: float = profile.cell_size if profile != null else 1.0
	var max_bank_slope: float = 0.65  # ~33 grados, talud natural de reposo
	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}
	var modified_cells: Dictionary = {}

	# Inicializar con todas las celdas de agua (ríos y lagos) como semillas del talud
	for pos in hydro.water_cells:
		queue.append(pos)
		visited[pos] = true
		hydro.hydraulic_influence[pos] = 1.0
		var c: WorldCell = cells.get(pos)
		if c != null:
			c.hydraulic_influence = 1.0

	var head: int = 0
	while head < queue.size():
		var u: Vector2i = queue[head]
		head += 1

		var u_cell: WorldCell = cells.get(u)
		if u_cell == null:
			continue

		var u_height: float = u_cell.height
		if hydro.is_water(u):
			u_height = float(hydro.get_water_height(u, u_height))

		for offset in D8_OFFSETS:
			var v: Vector2i = u + offset
			if v.x < 0 or v.x >= width or v.y < 0 or v.y >= height:
				continue
			if hydro.is_water(v):
				continue

			var v_cell: WorldCell = cells.get(v)
			if v_cell == null:
				continue

			var dist_mult: float = 1.41421356 if (offset.x != 0 and offset.y != 0) else 1.0
			var max_step: float = cell_size * dist_mult * max_bank_slope
			var max_allowed_h: float = u_height + max_step

			# Si la celda vecina genera un salto vertical que supera el talud admisible:
			if v_cell.height > max_allowed_h:
				var new_h: float = minf(v_cell.raw_height, max_allowed_h)
				if new_h < v_cell.height:
					v_cell.height = new_h
					var rel_inf: float = clampf((v_cell.raw_height - new_h) / maxf(v_cell.raw_height - u_height, 0.001), 0.0, 1.0)
					v_cell.hydraulic_influence = maxf(v_cell.hydraulic_influence, rel_inf)
					hydro.hydraulic_influence[v] = v_cell.hydraulic_influence
					modified_cells[v] = true
					if not visited.has(v):
						visited[v] = true
						queue.append(v)

	# Recalcular pendientes para celdas relajadas
	for pos in modified_cells:
		var x: int = pos.x
		var y: int = pos.y
		var cell: WorldCell = cells[pos]

		var h_left: float = cells[Vector2i(maxi(x - 1, 0), y)].height
		var h_right: float = cells[Vector2i(mini(x + 1, width - 1), y)].height
		var h_up: float = cells[Vector2i(x, maxi(y - 1, 0))].height
		var h_down: float = cells[Vector2i(x, mini(y + 1, height - 1))].height

		var grad_x := (h_right - h_left) / (2.0 * cell_size)
		var grad_y := (h_down - h_up) / (2.0 * cell_size)
		cell.slope = rad_to_deg(atan(sqrt(grad_x * grad_x + grad_y * grad_y)))


# =============================================================================
# BLOQUE 10B.3: VALIDACIÓN HIDRÁULICA SOBRE H_carved (HYDRAULIC GROUND TRUTH)
# =============================================================================

## Valida la presencia de agua exclusivamente en depresiones y canales físicos
## reales sobre H_carved. El terreno es la única autoridad:
## - Un lago solo existe si una cuenca real lo contiene físicamente.
## - El agua del lago queda estrictamente acotada por el vertedero natural de la cuenca.
## - Los ríos anclan su superficie de agua al lecho real tallado (H_bed <= H_water <= H_bank).
func _validate_hydraulic_ground_truth(
	cells: Dictionary,
	width: int,
	height: int,
	profile: WorldProfile,
	hydro: RefCounted
) -> void:
	if hydro == null:
		return

	# 1. VALIDAR LAGOS SOBRE H_carved (Contención física estricta)
	var valid_lakes: Array = []
	for lake in hydro.lakes:
		var cluster: Array = lake.get("cells", [])
		if cluster.is_empty():
			continue

		var lake_set: Dictionary = {}
		for p in cluster:
			lake_set[p] = true

		# Encontrar el borde exterior circundante (rim) en el terreno esculpido
		var min_rim_h: float = INF
		var spill_pos: Vector2i = Vector2i(-1, -1)
		for pos in cluster:
			for offset in D8_OFFSETS:
				var neighbor: Vector2i = pos + offset
				if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
					continue
				if lake_set.has(neighbor):
					continue
				if hydro.is_river(neighbor):
					continue
				var nc: WorldCell = cells.get(neighbor)
				if nc == null:
					continue
				if nc.height < min_rim_h:
					min_rim_h = nc.height
					spill_pos = neighbor

		if is_inf(min_rim_h):
			continue

		# La cota de agua no puede exceder el borde de contención físico
		var target_water_h: float = float(lake.get("water_height", min_rim_h))
		var contained_water_h: float = minf(target_water_h, min_rim_h)

		# Filtrar celdas que realmente quedan sumergidas bajo el agua (depth >= 0.04m)
		var valid_cells: Array[Vector2i] = []
		var min_pos := Vector2i(999999, 999999)
		var max_pos := Vector2i(-999999, -999999)

		for pos in cluster:
			var c: WorldCell = cells.get(pos)
			if c == null:
				continue
			if c.height <= contained_water_h - 0.04:
				valid_cells.append(pos)
				min_pos.x = mini(min_pos.x, pos.x)
				min_pos.y = mini(min_pos.y, pos.y)
				max_pos.x = maxi(max_pos.x, pos.x)
				max_pos.y = maxi(max_pos.y, pos.y)
			else:
				# Celda seca o emergida (playa o isla): remover de water_cells si era lago
				if hydro.water_cells.has(pos) and hydro.water_cells[pos].get("type") == "lake":
					hydro.water_cells.erase(pos)

		# Descartar si no cumple área mínima en la cubeta contenida
		if valid_cells.size() < profile.lake_minimum_area:
			for pos in valid_cells:
				if hydro.water_cells.has(pos) and hydro.water_cells[pos].get("type") == "lake":
					hydro.water_cells.erase(pos)
			continue

		# Recalcular cota de contención sobre el perímetro exacto de valid_cells
		var valid_lake_set: Dictionary = {}
		for p in valid_cells:
			valid_lake_set[p] = true

		var final_rim_h: float = INF
		for pos in valid_cells:
			for offset in D8_OFFSETS:
				var neighbor: Vector2i = pos + offset
				if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
					continue
				if not valid_lake_set.has(neighbor):
					if hydro.is_river(neighbor):
						continue
					var nc: WorldCell = cells.get(neighbor)
					if nc != null and nc.height < final_rim_h:
						final_rim_h = nc.height

		if not is_inf(final_rim_h):
			contained_water_h = minf(contained_water_h, final_rim_h)

		lake["water_height"] = contained_water_h
		lake["spillway_height"] = contained_water_h
		lake["spillway_pos"] = spill_pos
		lake["cells"] = valid_cells
		lake["min_pos"] = min_pos
		lake["max_pos"] = max_pos
		valid_lakes.append(lake)

		# Sincronizar water_cells con cotas reales de lecho y agua contenida
		for pos in valid_cells:
			var c: WorldCell = cells[pos]
			var eff_depth: float = contained_water_h - c.height
			hydro.water_cells[pos] = {
				"type": "lake",
				"raw_height": c.raw_height,
				"shoreline_height": contained_water_h + 0.05,
				"water_height": contained_water_h,
				"bed_height": c.height,
				"terrain_height": c.height,
				"depth": eff_depth,
				"lake_id": lake.id,
				"flow_dir": Vector2.ZERO
			}

	hydro.lakes = valid_lakes

	# 2. VALIDAR RÍOS SOBRE H_carved (Anclaje estricto lecho <= agua <= orilla)
	for river in hydro.rivers:
		var pts: Array = river.get("points", [])
		var path: Array = river.get("path", [])
		var depths: Array = river.get("depths", [])
		var n_pts: int = pts.size()

		for i in range(n_pts):
			var pos: Vector2i = path[i] if i < path.size() else Vector2i(int(round(pts[i].x)), int(round(pts[i].z)))
			var c: WorldCell = cells.get(pos)
			if c == null:
				continue

			var d: float = float(depths[i]) if i < depths.size() else 0.2
			var f_b: float = maxf(d * 0.75, 0.25)
			var bed_h: float = c.height

			# Si la celda es parte de un lago validado, hereda la cota exacta del lago
			if hydro.is_lake(pos):
				var lake_data: Dictionary = hydro.get_cell_data(pos)
				var l_water_h: float = float(lake_data.get("water_height", bed_h))
				pts[i] = Vector3(pts[i].x, l_water_h + f_b, pts[i].z)

			# Garantizar que la lámina de agua de río siempre cubra el lecho excavado (sin hundirse bajo tierra)
			var w_h: float = maxf(pts[i].y - f_b, bed_h + 0.08)
			pts[i] = Vector3(pts[i].x, w_h + f_b, pts[i].z)

			if hydro.water_cells.has(pos) and hydro.water_cells[pos].get("type") == "river":
				hydro.water_cells[pos]["bed_height"] = bed_h
				hydro.water_cells[pos]["terrain_height"] = bed_h
				hydro.water_cells[pos]["water_height"] = w_h
				hydro.water_cells[pos]["depth"] = maxf(0.0, w_h - bed_h)
				hydro.water_cells[pos]["shoreline_height"] = pts[i].y

		# Preservar estricta monotonía descendente hacia la desembocadura
		for k in range(1, n_pts):
			if pts[k].y > pts[k - 1].y:
				pts[k] = Vector3(pts[k].x, pts[k - 1].y, pts[k].z)


# =============================================================================
# BLOQUE 10C: CONSTRUCCIÓN DE ZONAS HIDROLÓGICAS Y MÁSCARA DE EXCLUSIÓN
# =============================================================================

func _build_hydrology_zones(
	width: int,
	height: int,
	profile: WorldProfile,
	hydro: RefCounted
) -> void:
	var cell_size: float = profile.cell_size if profile != null else 1.0
	var bank_clearance: float = profile.vegetation_bank_clearance if (profile != null and "vegetation_bank_clearance" in profile) else 1.5

	# 1. Inicializar todas las celdas como DRY
	for y in range(height):
		for x in range(width):
			hydro.zones[Vector2i(x, y)] = _HydrologyResultScript.HydrologyZone.DRY

	# 2. Lagos: Lake Water & Lake Bank
	var w_lake_bank: float = maxf(cell_size * 2.0, bank_clearance)
	for lake in hydro.lakes:
		var cluster: Array = lake.get("cells", [])
		var min_pos: Vector2i = lake.get("min_pos", Vector2i.ZERO)
		var max_pos: Vector2i = lake.get("max_pos", Vector2i(width - 1, height - 1))
		var lake_set: Dictionary = {}

		for p in cluster:
			lake_set[p] = true
			hydro.zones[p] = _HydrologyResultScript.HydrologyZone.LAKE_WATER

		var search_margin: int = clampi(int(ceil(w_lake_bank / cell_size)) + 1, 1, 5)
		var bx0: int = clampi(min_pos.x - search_margin, 0, width - 1)
		var bx1: int = clampi(max_pos.x + search_margin, 0, width - 1)
		var by0: int = clampi(min_pos.y - search_margin, 0, height - 1)
		var by1: int = clampi(max_pos.y + search_margin, 0, height - 1)

		for cy in range(by0, by1 + 1):
			for cx in range(bx0, bx1 + 1):
				var pos := Vector2i(cx, cy)
				if lake_set.has(pos):
					continue
				if hydro.zones.get(pos, 0) == _HydrologyResultScript.HydrologyZone.LAKE_WATER:
					continue

				var min_dist_sq: float = INF
				for lp in cluster:
					var dx: float = float(cx - lp.x)
					var dy: float = float(cy - lp.y)
					var dsq: float = dx * dx + dy * dy
					if dsq < min_dist_sq:
						min_dist_sq = dsq

				var dist_m: float = sqrt(min_dist_sq) * cell_size
				var dist_from_shore: float = maxf(0.0, dist_m - cell_size * 0.5)
				if dist_from_shore <= w_lake_bank:
					hydro.zones[pos] = _HydrologyResultScript.HydrologyZone.LAKE_BANK

	# 3. Ríos: River Water & River Bank (usando la geometría continua y anchos)
	for river_data in hydro.rivers:
		var pts_arr: Array = river_data.get("points", [])
		var widths_arr: Array = river_data.get("widths", [])
		var num_pts: int = pts_arr.size()
		if num_pts < 2:
			continue

		for j in range(num_pts - 1):
			var p0_3d: Vector3 = pts_arr[j]
			var p1_3d: Vector3 = pts_arr[j + 1]
			var p0 := Vector2(p0_3d.x, p0_3d.z)
			var p1 := Vector2(p1_3d.x, p1_3d.z)
			var v := p1 - p0
			var len_sq: float = v.length_squared()
			var inv_len_sq: float = 1.0 / len_sq if len_sq > 0.00001 else 0.0

			var w0: float = float(widths_arr[j])
			var w1: float = float(widths_arr[j + 1])
			var max_w: float = maxf(w0, w1)
			var max_w_river: float = max_w * 0.5
			var seg_bank_clearance: float = maxf(max_w_river * 0.8, bank_clearance)
			var max_w_bank: float = max_w_river + seg_bank_clearance

			var min_cx: int = clampi(int(floor((minf(p0.x, p1.x) - max_w_bank) / cell_size)), 0, width - 1)
			var max_cx: int = clampi(int(ceil((maxf(p0.x, p1.x) + max_w_bank) / cell_size)), 0, width - 1)
			var min_cy: int = clampi(int(floor((minf(p0.y, p1.y) - max_w_bank) / cell_size)), 0, height - 1)
			var max_cy: int = clampi(int(ceil((maxf(p0.y, p1.y) + max_w_bank) / cell_size)), 0, height - 1)

			for cy in range(min_cy, max_cy + 1):
				for cx in range(min_cx, max_cx + 1):
					var target_pos := Vector2i(cx, cy)
					# Si ya está catalogada como agua de lago, preservar LAKE_WATER
					if hydro.zones.get(target_pos, 0) == _HydrologyResultScript.HydrologyZone.LAKE_WATER:
						continue

					var q := Vector2(float(cx), float(cy)) * cell_size
					var t: float = clampf((q - p0).dot(v) * inv_len_sq, 0.0, 1.0)
					var proj: Vector2 = p0 + v * t
					var dist_m: float = q.distance_to(proj)

					var cur_w: float = lerpf(w0, w1, t)
					var cur_w_river: float = cur_w * 0.5
					var cur_w_bank: float = cur_w_river + maxf(cur_w_river * 0.8, bank_clearance)

					if dist_m <= cur_w_river:
						hydro.zones[target_pos] = _HydrologyResultScript.HydrologyZone.RIVER_WATER
					elif dist_m <= cur_w_bank:
						if hydro.zones.get(target_pos, 0) != _HydrologyResultScript.HydrologyZone.RIVER_WATER:
							hydro.zones[target_pos] = _HydrologyResultScript.HydrologyZone.RIVER_BANK

	# 4. Generar la máscara booleana de exclusión para vegetación O(1) con influencia hidráulica
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var zone: int = int(hydro.zones.get(pos, _HydrologyResultScript.HydrologyZone.DRY))
			var inf: float = float(hydro.hydraulic_influence.get(pos, 0.0))
			if zone == _HydrologyResultScript.HydrologyZone.DRY and inf > 0.0:
				hydro.zones[pos] = _HydrologyResultScript.HydrologyZone.RIVER_BANK
				zone = _HydrologyResultScript.HydrologyZone.RIVER_BANK
			if zone != _HydrologyResultScript.HydrologyZone.DRY or inf > 0.0:
				hydro.exclusion_mask[pos] = true
