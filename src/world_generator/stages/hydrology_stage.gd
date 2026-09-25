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

## Routing Height (Señal continua analítica para Priority Flood, Gradiente, D8 y Trazado)
static func get_routing_height(cell: WorldCell) -> float:
	if cell == null:
		return 0.0
	return cell.raw_height if cell.raw_height != 0.0 else cell.height

## Physical Terrain Height (Cota física escalonada para Lecho, Orillas, Espejo de Agua y Malla)
static func get_terrain_height(cell: WorldCell) -> float:
	if cell == null:
		return 0.0
	return cell.height

## Min-heap binario O(N log N) para resolución de depresiones por Priority-Flood
## Implementa desempate determinista:
##   primary   = routing_height
##   secondary = deterministic spatial key (evita orden incidental del heap)
class PriorityQueue:
	var _data: Array[Dictionary] = []

	func push(pos: Vector2i, height: float, spatial_key: int = -1) -> void:
		var key: int = spatial_key if spatial_key != -1 else (pos.y * 65536 + pos.x)
		_data.append({ "pos": pos, "height": height, "spatial_key": key })
		var idx := _data.size() - 1
		while idx > 0:
			var parent := (idx - 1) >> 1
			if _is_higher_priority(idx, parent):
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
				if left < count and _is_higher_priority(left, smallest):
					smallest = left
				if right < count and _is_higher_priority(right, smallest):
					smallest = right
				if smallest != idx:
					var tmp: Dictionary = _data[idx]
					_data[idx] = _data[smallest]
					_data[smallest] = tmp
					idx = smallest
				else:
					break
		return root

	func _is_higher_priority(a_idx: int, b_idx: int) -> bool:
		var ha: float = _data[a_idx]["height"]
		var hb: float = _data[b_idx]["height"]
		if ha != hb:
			return ha < hb
		return _data[a_idx]["spatial_key"] < _data[b_idx]["spatial_key"]

	func is_empty() -> bool:
		return _data.is_empty()

	func size() -> int:
		return _data.size()


static func solve_global(context: WorldGenerationContext) -> HydrologyResult:
	var stage := HydrologyStage.new()
	return stage._solve_global_impl(context)


static func apply_local(context: WorldGenerationContext, hydro: HydrologyResult) -> void:
	var stage := HydrologyStage.new()
	stage._apply_local_impl(context, hydro)


func execute(context: WorldGenerationContext) -> void:
	var is_chunk: bool = context.has_method("is_chunk_context") and context.is_chunk_context()
	var hydro: HydrologyResult = context.result.hydrology

	if is_chunk and hydro != null:
		apply_local(context, hydro)
		return

	hydro = solve_global(context)
	context.result.hydrology = hydro
	apply_local(context, hydro)


func _apply_local_impl(context: WorldGenerationContext, hydro: HydrologyResult) -> void:
	if hydro == null:
		return
	var profile: WorldProfile = context.profile
	if not profile.hydrology_enabled:
		return

	var is_profiling: bool = (context.telemetry != null and not context.telemetry.is_empty())
	var t_start := Time.get_ticks_usec() if is_profiling else 0

	var cells: Dictionary = context.result.cells
	var validated_rivers: Array = hydro.rivers
	var accumulation: Dictionary = hydro.accumulation
	var context_bounds: Rect2i = context.get_generation_bounds() if context.has_method("get_generation_bounds") else Rect2i(0, 0, profile.width, profile.height)

	var is_chunk: bool = context.has_method("is_chunk_context") and context.is_chunk_context()
	var is_unbounded: bool = is_chunk and "config" in context and context.config != null and context.config.is_unbounded

	var t0 := Time.get_ticks_usec() if is_profiling else 0
	var slope_river_us: int = _carve_river_channels(cells, validated_rivers, accumulation, profile, hydro, is_profiling, context_bounds, is_chunk, is_unbounded)
	var t1 := Time.get_ticks_usec() if is_profiling else 0

	var slope_lake_us: int = _carve_lake_basins(cells, hydro.lakes, profile, hydro, is_profiling, is_chunk, is_unbounded)
	var t2 := Time.get_ticks_usec() if is_profiling else 0

	# BLOQUE 9: Se elimina definitivamente _relax_hydraulic_banks() del pipeline.
	# Los acantilados permanecen como acantilados verticales (cliff -> cliff).
	# Las transiciones transitables (rampas/escaleras/puentes) se delegan fuera de Hydrology.
	var t3 := Time.get_ticks_usec() if is_profiling else 0

	# BLOQUE 1: Blindaje del contrato del fondo marino (Seabed Contract)
	# Para toda celda de agua dentro de los bounds locales/generados:
	# 1. cell.height == bed_height
	# 2. bed_height <= water_height
	# 3. depth == water_height - bed_height
	_validate_water_bed_contract(cells, hydro)

	if is_profiling:
		var total_ms := float(t3 - t_start) / 1000.0
		var river_raw_ms := float((t1 - t0) - slope_river_us) / 1000.0
		var lake_raw_ms := float((t2 - t1) - slope_lake_us) / 1000.0
		var banks_ms := 0.0
		var slope_ms := float(slope_river_us + slope_lake_us) / 1000.0
		var sub_sum := river_raw_ms + lake_raw_ms + banks_ms + slope_ms
		var other_ms := maxf(total_ms - sub_sum, 0.0)

		context.telemetry["hydro_river_ms"] = river_raw_ms
		context.telemetry["hydro_lake_ms"] = lake_raw_ms
		context.telemetry["hydro_banks_ms"] = banks_ms
		context.telemetry["hydro_slope_ms"] = slope_ms
		context.telemetry["hydro_other_ms"] = other_ms
		context.telemetry["hydro_total_ms"] = total_ms


func _validate_water_bed_contract(cells: Dictionary, hydro: HydrologyResult) -> void:
	if hydro == null or hydro.water_cells.is_empty():
		return
	for pos in hydro.water_cells:
		var cell: WorldCell = cells.get(pos)
		if cell == null:
			continue
		var data: Dictionary = hydro.water_cells[pos]
		var w_h: float = float(data.get("water_height", cell.height))
		var b_h: float = float(data.get("bed_height", cell.height))

		# Sincronización explícita
		if not is_equal_approx(cell.height, b_h):
			cell.height = b_h

		assert(is_equal_approx(cell.height, b_h),
			"Violación Contrato Marino: cell.height (%.4f) != bed_height (%.4f) en %s" % [cell.height, b_h, str(pos)])
		assert(b_h <= w_h + 0.001,
			"Violación Contrato Marino: bed_height (%.4f) > water_height (%.4f) en %s" % [b_h, w_h, str(pos)])



func _solve_global_impl(context: WorldGenerationContext) -> HydrologyResult:
	var profile: WorldProfile = context.profile
	var hydro = _HydrologyResultScript.new()

	if not profile.hydrology_enabled:
		return hydro

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
			var raw_h: float = get_routing_height(cell)
			debug_raw_height[pos] = raw_h
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
		cells, filled_height, flood_rank, width, height, profile.cell_size
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
		hydro.basins, hydro, width, height, profile, gradient_magnitudes,
		filled_height
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

	# Garantizar monotonicidad no creciente estricta aguas abajo en todos los ríos
	for river_data in hydro.rivers:
		var path: Array = river_data.get("path", [])
		var prev_h: float = INF
		for pos in path:
			if hydro.water_cells.has(pos) and not hydro.is_lake(pos):
				var cur_h: float = float(hydro.water_cells[pos].get("water_height", 0.0))
				if cur_h > prev_h:
					cur_h = prev_h
					hydro.water_cells[pos]["water_height"] = cur_h
					var b_h: float = float(hydro.water_cells[pos].get("bed_height", cur_h - 0.5))
					if b_h > cur_h - 0.10:
						b_h = cur_h - 0.10
						hydro.water_cells[pos]["bed_height"] = b_h
					hydro.water_cells[pos]["depth"] = cur_h - b_h
				prev_h = cur_h

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

	# Acumulación y extremos regionales de elevación para normalización determinista
	hydro.accumulation = accumulation

	var h_min: float = INF
	var h_max: float = -INF
	for cell in cells.values():
		if cell.raw_height < h_min:
			h_min = cell.raw_height
		if cell.raw_height > h_max:
			h_max = cell.raw_height
	hydro.height_min = h_min
	hydro.height_max = h_max

	# Construir índice espacial acelerador derivado
	var t_build_start := Time.get_ticks_usec()
	hydro.build_spatial_index(profile.cell_size)
	var t_build_end := Time.get_ticks_usec()
	if context.telemetry != null:
		context.telemetry["spatial_index_build_ms"] = float(t_build_end - t_build_start) / 1000.0

	return hydro


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
	var raw_clusters: Array = []
	var next_lake_id: int = 1

	# 1. Extraer todos los clusters candidatos bajo el umbral lake_threshold
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

			raw_clusters.append(cluster)

	if raw_clusters.is_empty():
		return

	# 2. FUSIÓN Y CONEXIÓN DIRECTA DE LAGOS Y CHARCOS CERCANOS
	# Si dos clusters están a una distancia <= lake_merge_distance, se excava un canal/cuello
	# conectivo entre sus puntos más cercanos y se fusionan en un único cuerpo de agua.
	var merge_dist: float = profile.lake_merge_distance if "lake_merge_distance" in profile else 4.0
	var merge_dist_sq: float = merge_dist * merge_dist

	# Grafo de adyacencia de fusiones
	var num_clusters: int = raw_clusters.size()
	var parent: Array[int] = []
	parent.resize(num_clusters)
	for i in range(num_clusters):
		parent[i] = i

	var find_root = func(i: int, self_fn: Callable) -> int:
		if parent[i] == i:
			return i
		parent[i] = self_fn.call(parent[i], self_fn)
		return parent[i]

	var bridge_cells: Array[Vector2i] = []

	if merge_dist > 0.0:
		for i in range(num_clusters):
			var c_a: Array = raw_clusters[i]
			for j in range(i + 1, num_clusters):
				var c_b: Array = raw_clusters[j]

				var min_d_sq: float = INF
				var best_pa := Vector2i(-1, -1)
				var best_pb := Vector2i(-1, -1)

				for pa in c_a:
					for pb in c_b:
						var dx: float = float(pa.x - pb.x)
						var dy: float = float(pa.y - pb.y)
						var d2: float = dx * dx + dy * dy
						if d2 < min_d_sq:
							min_d_sq = d2
							best_pa = pa
							best_pb = pb

				if min_d_sq <= merge_dist_sq and best_pa != Vector2i(-1, -1):
					var root_a: int = find_root.call(i, find_root)
					var root_b: int = find_root.call(j, find_root)
					parent[root_b] = root_a

					# Trazar canal conector lineal (Bresenham / D8) entre best_pa y best_pb
					var line_pts := _trace_grid_line(best_pa, best_pb)
					for lp in line_pts:
						bridge_cells.append(lp)

	# Agrupar clusters por su raíz de componente conexa
	var merged_groups: Dictionary = {}
	for i in range(num_clusters):
		var root: int = find_root.call(i, find_root)
		if not merged_groups.has(root):
			merged_groups[root] = []
		merged_groups[root].append_array(raw_clusters[i])

	# Añadir celdas de puente a los grupos que conectan
	for bp in bridge_cells:
		var bp_cell: WorldCell = cells.get(bp)
		if bp_cell != null:
			# Rebajar terreno para garantizar continuidad sumergida
			bp_cell.normalized_height = minf(bp_cell.normalized_height, profile.lake_threshold - 0.01)

		# Asignar la celda al grupo más cercano
		var best_root: int = -1
		var best_dist: float = INF
		for root in merged_groups:
			for gp in merged_groups[root]:
				var dsq: float = float((gp.x - bp.x) * (gp.x - bp.x) + (gp.y - bp.y) * (gp.y - bp.y))
				if dsq < best_dist:
					best_dist = dsq
					best_root = root
		if best_root != -1:
			merged_groups[best_root].append(bp)

	# 3. CONSOLIDACIÓN DE LAGOS FINALES
	var global_claimed_lake_cells: Dictionary = {}
	for root in merged_groups:
		var raw_list: Array = merged_groups[root]
		# Eliminar celdas duplicadas y celdas ya absorbidas por un lago anterior
		var unique_dict: Dictionary = {}
		var cluster: Array[Vector2i] = []
		for p in raw_list:
			if not unique_dict.has(p) and not global_claimed_lake_cells.has(p):
				unique_dict[p] = true
				cluster.append(p)

		# Descartar si el lago final consolidado no cumple el área mínima
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
				spillway_height = cells[cluster[0]].raw_height

		if max_cluster_h > spillway_height:
			spillway_height = max_cluster_h

		# 3b. Inundación hidrológica completa de la cuenca (Depression Inundation):
		# Toda celda contigua de la depresión que Priority-Flood llenó a esta cota y cuya
		# cota de terreno quede sumergida bajo el spillway es parte física del lago.
		var flood_queue: Array[Vector2i] = []
		flood_queue.append_array(cluster)
		while not flood_queue.is_empty():
			var curr: Vector2i = flood_queue.pop_front()
			for offset in D8_OFFSETS:
				var neighbor: Vector2i = curr + offset
				if neighbor.x < 0 or neighbor.x >= width or neighbor.y < 0 or neighbor.y >= height:
					continue
				if cluster_set.has(neighbor):
					continue
				var n_cell: WorldCell = cells.get(neighbor)
				if n_cell == null:
					continue
				var n_h: float = n_cell.raw_height if n_cell.raw_height != 0.0 else n_cell.height
				var n_filled: float = float(filled_height.get(neighbor, 0.0))
				if absf(n_filled - spillway_height) < 0.05 and (spillway_height - n_h) >= 0.20:
					cluster_set[neighbor] = true
					cluster.append(neighbor)
					flood_queue.append(neighbor)

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
			var raw_depth: float = maxf(0.0, spillway_height - c_h)
			var min_lake_depth: float = 0.50
			var effective_depth: float = maxf(raw_depth, min_lake_depth)
			var bed_h: float = spillway_height - effective_depth

			hydro.water_cells[pos] = {
				"type": "lake",
				"shoreline_height": spillway_height + 0.05,
				"water_height": spillway_height,
				"bed_height": bed_h,
				"depth": effective_depth,
				"initial_depth": effective_depth,
				"lake_id": lake_id,
				"flow_dir": Vector2.ZERO
			}

			debug_drainage[pos] = maxf(
				float(debug_drainage.get(pos, 0.0)),
				10.0 + effective_depth * 5.0
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

		for p in cluster:
			global_claimed_lake_cells[p] = true

	# 3c. Poda morfológica de filamentos y espículas de 1 celda en lagos
	var lake_cells_to_prune: Array[Vector2i] = []
	for p in hydro.water_cells:
		if hydro.water_cells[p].get("type") == "lake":
			var d4_count := 0
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if hydro.water_cells.has(p + off):
					d4_count += 1
			if d4_count <= 1:
				lake_cells_to_prune.append(p)

	for p in lake_cells_to_prune:
		hydro.water_cells.erase(p)
		for lk in hydro.lakes:
			var idx: int = lk["cells"].find(p)
			if idx != -1:
				lk["cells"].remove_at(idx)


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
			var ch: float = get_routing_height(c)
			filled[p_top] = ch
			pq.push(p_top, ch, p_top.y * width + p_top.x)
		if cells.has(p_bot) and not visited.has(p_bot):
			visited[p_bot] = true
			var c: WorldCell = cells[p_bot]
			var ch: float = get_routing_height(c)
			filled[p_bot] = ch
			pq.push(p_bot, ch, p_bot.y * width + p_bot.x)

	for y in range(height):
		var p_left := Vector2i(0, y)
		var p_right := Vector2i(width - 1, y)
		if cells.has(p_left) and not visited.has(p_left):
			visited[p_left] = true
			var c: WorldCell = cells[p_left]
			var ch: float = get_routing_height(c)
			filled[p_left] = ch
			pq.push(p_left, ch, p_left.y * width + p_left.x)
		if cells.has(p_right) and not visited.has(p_right):
			visited[p_right] = true
			var c: WorldCell = cells[p_right]
			var ch: float = get_routing_height(c)
			filled[p_right] = ch
			pq.push(p_right, ch, p_right.y * width + p_right.x)

	# 2. Priority-Flood expande desde los bordes hacia el interior (Barnes et al. 2014)
	# Los lagos se llenan naturalmente al alcanzarse su cota de spillway desde el downstream.

	# 3. Main loop de Priority-Flood (Barnes et al. 2014)
	# Desempate determinista: primary = routing_height, secondary = spatial_key
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
			var neighbor_height: float = get_routing_height(neighbor_cell)

			var resolved_height: float = maxf(neighbor_height, current_filled)
			filled[neighbor] = resolved_height
			pq.push(neighbor, resolved_height, neighbor.y * width + neighbor.x)

	return {
		"filled": filled,
		"flood_rank": flood_rank
	}


# =============================================================================
# BLOQUE 2: GRADIENT ANALÍTICO CONTINUO (∇H_filled) Y FLOW FIELD
# =============================================================================

func _build_gradient_and_flow_field(
	cells: Dictionary,
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
			# Altura de routing: filled_height virtual si existe (depresiones resueltas)
			# o raw_height continuo (get_routing_height). Nunca cell.height discretizado.
			var h_c: float = float(filled_height.get(pos, get_routing_height(cells.get(pos))))

			# Diferencias finitas en X
			var dh_dx: float = 0.0
			if x > 0 and x < width - 1:
				var p_r := Vector2i(x + 1, y)
				var p_l := Vector2i(x - 1, y)
				var h_r: float = float(filled_height.get(p_r, get_routing_height(cells.get(p_r))))
				var h_l: float = float(filled_height.get(p_l, get_routing_height(cells.get(p_l))))
				dh_dx = (h_r - h_l) * inv_2_cell
			elif x == 0:
				var p_r := Vector2i(x + 1, y)
				var h_r: float = float(filled_height.get(p_r, get_routing_height(cells.get(p_r))))
				dh_dx = (h_r - h_c) * inv_cell
			else:
				var p_l := Vector2i(x - 1, y)
				var h_l: float = float(filled_height.get(p_l, get_routing_height(cells.get(p_l))))
				dh_dx = (h_c - h_l) * inv_cell

			# Diferencias finitas en Z (Y en grilla 2D)
			var dh_dz: float = 0.0
			if y > 0 and y < height - 1:
				var p_d := Vector2i(x, y + 1)
				var p_u := Vector2i(x, y - 1)
				var h_d: float = float(filled_height.get(p_d, get_routing_height(cells.get(p_d))))
				var h_u: float = float(filled_height.get(p_u, get_routing_height(cells.get(p_u))))
				dh_dz = (h_d - h_u) * inv_2_cell
			elif y == 0:
				var p_d := Vector2i(x, y + 1)
				var h_d: float = float(filled_height.get(p_d, get_routing_height(cells.get(p_d))))
				dh_dz = (h_d - h_c) * inv_cell
			else:
				var p_u := Vector2i(x, y - 1)
				var h_u: float = float(filled_height.get(p_u, get_routing_height(cells.get(p_u))))
				dh_dz = (h_c - h_u) * inv_cell

			# Vector de descenso físico: F = -∇H_routing
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

			var current_h: float = float(filled_height.get(pos, get_routing_height(cells.get(pos))))
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

				var neighbor_h: float = float(filled_height.get(neighbor, get_routing_height(cells.get(neighbor))))
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
	profile: WorldProfile,
	gradient_magnitudes: Dictionary = {},
	filled_height: Dictionary = {}
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
			var max_river_steps: int = maxi(profile.river_max_steps, (width + height) * 4)
			for _step in range(max_river_steps):
				var nxt: Vector2i = flow_to.get(curr, curr)
				if nxt == curr or hydro.is_lake(nxt):
					break
				potential_length += 1.0
				curr = nxt

			if potential_length < HEADWATER_MIN_LENGTH:
				continue

			var b_id: int = cell_basin_map.get(pos, 0)
			var b_area: float = float(basins[b_id]["area"]) if basins.has(b_id) else 1.0

			# En terreno escalonado, la calidad hidráulica se evalúa mediante la pendiente continua
			# derivada de raw_height / filled_height (no cell.slope escalonado: evita sesgo 0° en mesetas y 90° en cliffs)
			var hydraulic_slope: float = 0.0
			if not gradient_magnitudes.is_empty() and gradient_magnitudes.has(pos):
				hydraulic_slope = float(gradient_magnitudes[pos])
			else:
				var h_c: float = float(filled_height.get(pos, get_routing_height(cell)))
				var p_r := Vector2i(pos.x + 1, pos.y)
				var p_l := Vector2i(pos.x - 1, pos.y)
				var p_d := Vector2i(pos.x, pos.y + 1)
				var p_u := Vector2i(pos.x, pos.y - 1)
				var h_r: float = float(filled_height.get(p_r, get_routing_height(cells.get(p_r, cell)))) if pos.x < width - 1 else h_c
				var h_l: float = float(filled_height.get(p_l, get_routing_height(cells.get(p_l, cell)))) if pos.x > 0 else h_c
				var h_d: float = float(filled_height.get(p_d, get_routing_height(cells.get(p_d, cell)))) if pos.y < height - 1 else h_c
				var h_u: float = float(filled_height.get(p_u, get_routing_height(cells.get(p_u, cell)))) if pos.y > 0 else h_c
				var cs: float = profile.cell_size if profile != null and profile.cell_size > 0.0 else 1.0
				var dh_dx: float = (h_r - h_l) / (2.0 * cs if (pos.x > 0 and pos.x < width - 1) else cs)
				var dh_dz: float = (h_d - h_u) / (2.0 * cs if (pos.y > 0 and pos.y < height - 1) else cs)
				hydraulic_slope = sqrt(dh_dx * dh_dx + dh_dz * dh_dz)

			var slope_term: float = clampf(hydraulic_slope / 0.12, 0.0, 1.0)

			var score: float = (
				0.30 * cell.normalized_height +
				0.25 * slope_term +
				0.25 * clampf(potential_length / float(width + height), 0.0, 1.0) +
				0.20 * clampf(b_area / total_cells, 0.0, 1.0)
			)

			candidates.append({
				"pos": pos,
				"score": score
			})

	# Ordenar deterministamente por score descendente con desempate espacial estricto
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(a["score"], b["score"]):
			return a["score"] > b["score"]
		var pa: Vector2i = a["pos"]
		var pb: Vector2i = b["pos"]
		if pa.y != pb.y:
			return pa.y < pb.y
		return pa.x < pb.x
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
		var c_h: float = get_terrain_height(cell)

		var acc: float = float(accumulation.get(pos, 1.0))
		var acc_norm: float = clampf(log(acc + 1.0) / maxf(log(network_max_acc + 1.0), 0.001), 0.0, 1.0)

		# Ancho y profundidad modulados hidrológicamente por acumulación, orden Strahler y pendiente
		var order_w_mult: float = 1.0 + float(river_order - 1) * 0.30
		var order_d_mult: float = 1.0 + float(river_order - 1) * 0.20
		var slope_w_factor: float = clampf(1.0 - (cell.slope / 45.0) * 0.25, 0.75, 1.0)

		var min_c: float = float(profile.river_min_cells) if "river_min_cells" in profile else 3.0
		var max_c: float = float(profile.river_max_cells) if "river_max_cells" in profile else 8.0
		var w_cells: float = clampf(
			lerpf(min_c, max_c, pow(acc_norm, profile.river_width_response)) * order_w_mult * slope_w_factor,
			min_c,
			max_c
		)
		var base_w: float = w_cells * profile.cell_size
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

		points.append(pt)
		widths.append(base_w)
		depths.append(base_d)

	# BLOQUE 7: Agrupar en tramos de terraza contiguos (terrace reaches)
	# Política hidráulica:
	# - Dentro de una terraza: H_water = constante.
	# - Al cambiar de nivel: salto vertical (cascada), sin rampa de agua continua.
	var pt_levels: Array[int] = []
	var cur_max_lvl: int = cells[path[0]].elevation_level
	for i in range(total_pts):
		var lvl: int = mini(cells[path[i]].elevation_level, cur_max_lvl)
		cur_max_lvl = lvl
		pt_levels.append(lvl)

	var reaches: Array = []
	var cur_reach_start: int = 0
	for i in range(1, total_pts):
		if pt_levels[i] != pt_levels[cur_reach_start]:
			reaches.append({
				"start": cur_reach_start,
				"end": i - 1,
				"level": pt_levels[cur_reach_start]
			})
			cur_reach_start = i
	reaches.append({
		"start": cur_reach_start,
		"end": total_pts - 1,
		"level": pt_levels[cur_reach_start]
	})

	var cfg_freeboard: float = profile.river_freeboard if (profile != null and "river_freeboard" in profile) else 0.08

	for reach in reaches:
		var r_lvl: int = reach["level"]
		var r_terrace_h: float = profile.base_height + float(r_lvl) * profile.elevation_step_height
		var r_bed_lvl: int = maxi(0, r_lvl - 1)
		var r_bed_h: float = profile.base_height + float(r_bed_lvl) * profile.elevation_step_height
		if r_bed_h >= r_terrace_h:
			r_bed_h = maxf(0.0, r_terrace_h - profile.elevation_step_height * 0.5)
		var r_wh: float = (r_terrace_h + r_bed_h) * 0.5
		reach["fb"] = r_terrace_h - r_wh
		reach["terrace_h"] = r_terrace_h
		reach["bed_h"] = r_bed_h
		reach["wh"] = r_wh

	# Continuidad de cota en confluencias o lagos dentro de la misma terraza:
	for reach in reaches:
		for i in range(reach["start"], reach["end"] + 1):
			var pos: Vector2i = path[i]
			if hydro.is_lake(pos):
				var lake_data: Dictionary = hydro.get_cell_data(pos)
				var target_h: float = float(lake_data.get("water_height", reach["wh"]))
				if absf(target_h - reach["wh"]) < profile.elevation_step_height * 0.5:
					reach["wh"] = minf(reach["wh"], target_h)
					reach["bed_h"] = minf(reach["bed_h"], float(lake_data.get("bed_height", reach["bed_h"])))
			elif hydro.water_cells.has(pos):
				var ex_cell: Dictionary = hydro.water_cells[pos]
				var ex_r_id: int = int(ex_cell.get("river_index", -1))
				if ex_r_id != -1 and ex_r_id != river_id:
					var target_h: float = float(ex_cell.get("water_height", reach["wh"]))
					if absf(target_h - reach["wh"]) < profile.elevation_step_height * 0.5:
						reach["wh"] = target_h
						var ex_b: float = float(ex_cell.get("bed_height", reach["bed_h"]))
						if ex_b < target_h and (target_h - ex_b) <= profile.elevation_step_height:
							reach["bed_h"] = ex_b

	# Continuidad en nacimiento desde spillway si el lago está en la misma terraza:
	if river_obj.is_outflow and hydro.is_lake(path[0]):
		var first_reach: Dictionary = reaches[0]
		var lake_data: Dictionary = hydro.get_cell_data(path[0])
		var spill_h: float = float(lake_data.get("water_height", first_reach["wh"]))
		if absf(spill_h - first_reach["wh"]) < profile.elevation_step_height * 0.5:
			first_reach["wh"] = minf(first_reach["wh"], spill_h)
			first_reach["bed_h"] = minf(first_reach["bed_h"], float(lake_data.get("bed_height", first_reach["bed_h"])))

	# Monotonía descendente obligatoria entre tramos sucesivos (salto vertical de cascada)
	for k in range(1, reaches.size()):
		var prev_r: Dictionary = reaches[k - 1]
		var cur_r: Dictionary = reaches[k]
		if cur_r["wh"] >= prev_r["wh"]:
			cur_r["wh"] = prev_r["wh"] - 0.05
		if cur_r["bed_h"] >= cur_r["wh"]:
			cur_r["bed_h"] = cur_r["wh"] - 0.5

	# Asignar cotas definitivas a points[i].y, pt_w_h[i] y pt_bed_h[i]:
	var pt_w_h: Array[float] = []
	var pt_bed_h: Array[float] = []
	pt_w_h.resize(total_pts)
	pt_bed_h.resize(total_pts)
	for reach in reaches:
		var r_wh: float = reach["wh"]
		var r_bed: float = reach["bed_h"]
		var r_fb: float = reach["fb"]
		for i in range(reach["start"], reach["end"] + 1):
			pt_w_h[i] = r_wh
			pt_bed_h[i] = r_bed
			points[i].y = r_wh + r_fb
			depths[i] = maxf(r_wh - r_bed, 0.05)

	# 1. Asegurar que las celdas directas del eje discreto path[i] están inicializadas
	var river_cell_dist: Dictionary = {}
	for i in range(total_pts):
		var pos: Vector2i = path[i]
		var p_2d := Vector2(points[i].x, points[i].z)
		var pt_dist: float = (Vector2(float(pos.x), float(pos.y)) - p_2d).length()
		river_cell_dist[pos] = pt_dist

		if not hydro.is_lake(pos):
			var b_h: float = pt_bed_h[i]
			var is_confluence_outlet: bool = (river_obj.downstream_river != -1 and i == total_pts - 1)
			if is_confluence_outlet and hydro.water_cells.has(pos):
				var existing_w_h: float = float(hydro.water_cells[pos].get("water_height", pt_w_h[i]))
				var existing_b_h: float = float(hydro.water_cells[pos].get("bed_height", b_h))
				if absf(existing_w_h - pt_w_h[i]) < 0.1:
					hydro.water_cells[pos]["bed_height"] = minf(existing_b_h, b_h)
					hydro.water_cells[pos]["depth"] = existing_w_h - float(hydro.water_cells[pos]["bed_height"])
			elif hydro.water_cells.has(pos):
				var existing: Dictionary = hydro.water_cells[pos]
				var ex_r_id: int = int(existing.get("river_index", -1))
				if ex_r_id != -1 and ex_r_id != river_id:
					# Otra confluencia o río cruzado: respetar la cota del río receptor existente
					var ex_wh: float = float(existing.get("water_height", pt_w_h[i]))
					var ex_bed: float = float(existing.get("bed_height", b_h))
					if absf(ex_wh - pt_w_h[i]) < 0.1:
						existing["bed_height"] = minf(ex_bed, b_h)
						existing["depth"] = ex_wh - float(existing["bed_height"])
				else:
					existing["water_height"] = pt_w_h[i]
					existing["bed_height"] = b_h
					existing["depth"] = depths[i]
					existing["shoreline_height"] = points[i].y
					existing["river_index"] = river_id
			else:
				hydro.water_cells[pos] = {
					"type": "river",
					"shoreline_height": points[i].y,
					"water_height": pt_w_h[i],
					"bed_height": b_h,
					"depth": depths[i],
					"flow_dir": Vector2.ZERO if i == total_pts - 1 else Vector2(float(path[i + 1].x - pos.x), float(path[i + 1].y - pos.y)).normalized(),
					"river_index": river_id
				}

	# 2. Rasterizar el corredor transversal de la cápsula para cada segmento (P_j -> P_{j+1})
	for j in range(total_pts - 1):
		var p0_2d := Vector2(points[j].x, points[j].z)
		var p1_2d := Vector2(points[j + 1].x, points[j + 1].z)
		var seg_v := p1_2d - p0_2d
		var seg_len_sq: float = seg_v.length_squared()
		var seg_inv_len: float = 1.0 / seg_len_sq if seg_len_sq > 0.0001 else 0.0
		var seg_dir: Vector2 = seg_v.normalized() if seg_len_sq > 0.0001 else Vector2.DOWN

		var w_c0: float = widths[j] / maxf(profile.cell_size, 0.001)
		var w_c1: float = widths[j + 1] / maxf(profile.cell_size, 0.001)
		# Semiancho en celdas: para ancho 3 celdas radio = 1.0, para 8 celdas radio = 3.5
		var r0: float = (w_c0 - 1.0) * 0.5
		var r1: float = (w_c1 - 1.0) * 0.5
		var max_r: float = maxf(r0, r1)

		var min_cx: int = clampi(int(floor(minf(p0_2d.x, p1_2d.x) - max_r - 1.0)), 0, profile.width - 1)
		var max_cx: int = clampi(int(ceil(maxf(p0_2d.x, p1_2d.x) + max_r + 1.0)), 0, profile.width - 1)
		var min_cy: int = clampi(int(floor(minf(p0_2d.y, p1_2d.y) - max_r - 1.0)), 0, profile.height - 1)
		var max_cy: int = clampi(int(ceil(maxf(p0_2d.y, p1_2d.y) + max_r + 1.0)), 0, profile.height - 1)

		var lvl_j: int = pt_levels[j]
		var lvl_j1: int = pt_levels[j + 1]
		var is_level_transition: bool = (lvl_j != lvl_j1)

		for cy in range(min_cy, max_cy + 1):
			for cx in range(min_cx, max_cx + 1):
				var c_pos := Vector2i(cx, cy)
				if hydro.is_lake(c_pos):
					continue

				var q := Vector2(float(cx), float(cy))
				var t: float = clampf((q - p0_2d).dot(seg_v) * seg_inv_len, 0.0, 1.0)
				var proj: Vector2 = p0_2d + seg_v * t
				var dist: float = q.distance_to(proj)

				var cur_r: float = lerpf(r0, r1, t)
				if dist > cur_r:
					continue

				# Determinar cota de agua y lecho según la política de terrazas (Bloques 6, 7 y 10):
				# Dentro de una terraza: H_water = constante, H_bed = constante.
				# Al cambiar de nivel: salto vertical (cascada), NUNCA rampa continua diagonal.
				var cur_wh: float
				var cur_bed: float
				var cur_shoreline: float
				if not is_level_transition:
					# Misma terraza: altura de agua y lecho estrictamente constante
					cur_wh = pt_w_h[j]
					cur_bed = pt_bed_h[j]
					cur_shoreline = points[j].y
				else:
					# Transición de nivel: asignar cota según el nivel físico de la celda
					var c_cell: WorldCell = cells.get(c_pos)
					var c_lvl: int = c_cell.elevation_level if c_cell != null else (lvl_j if t < 0.5 else lvl_j1)
					if c_lvl >= lvl_j:
						cur_wh = pt_w_h[j]
						cur_bed = pt_bed_h[j]
						cur_shoreline = points[j].y
					elif c_lvl <= lvl_j1:
						cur_wh = pt_w_h[j + 1]
						cur_bed = pt_bed_h[j + 1]
						cur_shoreline = points[j + 1].y
					else:
						if t < 0.5:
							cur_wh = pt_w_h[j]
							cur_bed = pt_bed_h[j]
							cur_shoreline = points[j].y
						else:
							cur_wh = pt_w_h[j + 1]
							cur_bed = pt_bed_h[j + 1]
							cur_shoreline = points[j + 1].y

				# Fondo plano uniforme a través de todo el ancho del canal
				var cur_d: float = maxf(cur_wh - cur_bed, 0.05)

				if hydro.water_cells.has(c_pos):
					var existing: Dictionary = hydro.water_cells[c_pos]
					if existing.get("type") == "lake":
						continue
					var existing_river_id: int = int(existing.get("river_index", -1))
					if existing_river_id != -1 and existing_river_id != river_id:
						# Celda perteneciente a otro río (ej. río receptor en confluencia)
						# Respetar la cota de agua del río receptor; solo profundizar el lecho si este afluente está en la misma cota
						var ex_wh: float = float(existing.get("water_height", cur_wh))
						if absf(ex_wh - cur_wh) < 0.1:
							var b_h: float = ex_wh - cur_d
							var ex_bed: float = float(existing.get("bed_height", b_h))
							existing["bed_height"] = minf(ex_bed, b_h)
							existing["depth"] = ex_wh - float(existing["bed_height"])
					else:
						# Mismo río: asignar propiedades del segmento geométrico más cercano
						# para garantizar lámina de agua transversalmente plana y sin jorobas/crestas
						var prev_dist: float = float(river_cell_dist.get(c_pos, INF))
						if dist < prev_dist:
							river_cell_dist[c_pos] = dist
							existing["water_height"] = cur_wh
							existing["shoreline_height"] = cur_shoreline
							existing["flow_dir"] = seg_dir
							existing["bed_height"] = cur_bed
							existing["depth"] = cur_d
				else:
					river_cell_dist[c_pos] = dist
					hydro.water_cells[c_pos] = {
						"type": "river",
						"shoreline_height": cur_shoreline,
						"water_height": cur_wh,
						"bed_height": cur_bed,
						"depth": cur_d,
						"flow_dir": seg_dir,
						"river_index": river_id
					}

	river_obj.points = points
	river_obj.widths = widths
	river_obj.depths = depths
	river_obj.levels = pt_levels

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
	profile: WorldProfile,
	hydro: RefCounted,
	record_slope: bool = false,
	context_bounds: Rect2i = Rect2i(),
	is_chunk: bool = false,
	is_unbounded: bool = false
) -> int:
	var carved_cells: Dictionary = {}
	var cell_size: float = profile.cell_size if profile != null else 1.0
	var freeboard_base: float = profile.river_freeboard if (profile != null and "river_freeboard" in profile) else 0.08

	var has_spatial_index: bool = (hydro != null and hydro.spatial_index != null and context_bounds.size != Vector2i.ZERO)

	if has_spatial_index:
		var candidate_segments: Array[Dictionary] = hydro.spatial_index.query_river_segments(context_bounds)
		for seg in candidate_segments:
			var p0_3d: Vector3 = seg["p0_3d"]
			var p1_3d: Vector3 = seg["p1_3d"]
			var p0: Vector2 = seg["p0"]
			var p1: Vector2 = seg["p1"]
			var v: Vector2 = seg["v"]
			var inv_len_sq: float = seg["inv_len_sq"]
			var w0: float = seg["w0"]
			var w1: float = seg["w1"]
			var d0: float = seg["d0"]
			var d1: float = seg["d1"]
			var delta_w: float = seg.get("delta_w", w1 - w0)
			var delta_d: float = seg.get("delta_d", d1 - d0)
			var delta_y: float = seg.get("delta_y", p1_3d.y - p0_3d.y)
			var p0_y: float = seg.get("p0_y", p0_3d.y)
			var max_w_river: float = seg["max_w_river"]
			var max_w_bank_slope: float = seg["max_w_bank_slope"]
			var max_w_bank: float = seg["max_w_bank"]

			# Intersección directa entre el AABB del segmento y los bounds de generación del contexto (BLOQUE 13D)
			var min_cx: int = maxi(seg["min_cx"], context_bounds.position.x)
			var max_cx: int = mini(seg["max_cx"], context_bounds.end.x - 1)
			var min_cy: int = maxi(seg["min_cy"], context_bounds.position.y)
			var max_cy: int = mini(seg["max_cy"], context_bounds.end.y - 1)

			if min_cx > max_cx or min_cy > max_cy:
				continue

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

					var cur_w: float = w0 + delta_w * t
					var cur_d: float = d0 + delta_d * t
					var cur_w_river: float = cur_w * 0.5
					var f_bank: float = maxf(cur_d * 0.50, freeboard_base)
					var centerline_y: float = p0_y + delta_y * t
					var water_y: float = centerline_y - f_bank
					if hydro != null and hydro.water_cells.has(target_pos):
						water_y = float(hydro.water_cells[target_pos].get("water_height", water_y))

					# BLOQUE 6 & 10: Solo tallar celdas que forman parte efectiva del canal de agua.
					# Hydrology solo puede excavar donde realmente existe agua/cauce (hydro.water_cells).
					# El terreno seco circundante conserva estrictamente su nivel físico intacto.
					if hydro != null and not hydro.water_cells.is_empty() and not hydro.water_cells.has(target_pos):
						continue

					if dist_m > cur_w_river:
						continue

					# Si SÍ: H_bed < H_water y se excava el canal con fondo plano uniforme dentro de los límites del agua.
					var bed_y: float = water_y - maxf(0.01, cur_d)
					if hydro != null and hydro.water_cells.has(target_pos):
						bed_y = float(hydro.water_cells[target_pos].get("bed_height", bed_y))
					var carved_h: float = bed_y
					var target_h: float = minf(cell.height, carved_h)

					var current_carved: float = float(carved_cells.get(target_pos, cell.height))
					if target_h < current_carved:
						carved_cells[target_pos] = target_h
						if hydro != null:
							hydro.hydraulic_influence[target_pos] = 1.0
	else:
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
				var p0 := Vector2(p0_3d.x, p0_3d.z) * cell_size
				var p1 := Vector2(p1_3d.x, p1_3d.z) * cell_size
				var v := p1 - p0
				var len_sq: float = v.length_squared()
				var inv_len_sq: float = 1.0 / len_sq if len_sq > 0.00001 else 0.0

				var w0: float = float(widths_arr[j])
				var w1: float = float(widths_arr[j + 1])
				var d0: float = float(depths_arr[j])
				var d1: float = float(depths_arr[j + 1])
				var delta_w: float = w1 - w0
				var delta_d: float = d1 - d0
				var delta_y: float = p1_3d.y - p0_3d.y
				var p0_y: float = p0_3d.y

				var max_w: float = maxf(w0, w1)
				var max_w_river: float = max_w * 0.5
				var max_w_bank_slope: float = maxf(max_w_river * 1.5, cell_size * 10.0)
				var max_w_bank: float = max_w_river + max_w_bank_slope

				var min_cx: int = int(floor((minf(p0.x, p1.x) - max_w_bank) / cell_size))
				var max_cx: int = int(ceil((maxf(p0.x, p1.x) + max_w_bank) / cell_size))
				var min_cy: int = int(floor((minf(p0.y, p1.y) - max_w_bank) / cell_size))
				var max_cy: int = int(ceil((maxf(p0.y, p1.y) + max_w_bank) / cell_size))

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

						var cur_w: float = w0 + delta_w * t
						var cur_d: float = d0 + delta_d * t
						var cur_w_river: float = cur_w * 0.5
						var f_bank: float = maxf(cur_d * 0.50, freeboard_base)
						var centerline_y: float = p0_y + delta_y * t
						var water_y: float = centerline_y - f_bank
						if hydro != null and hydro.water_cells.has(target_pos):
							water_y = float(hydro.water_cells[target_pos].get("water_height", water_y))

						# BLOQUE 6 & 10: Solo tallar celdas que forman parte efectiva del canal de agua.
						# Hydrology solo puede excavar donde realmente existe agua/cauce (hydro.water_cells).
						# El terreno seco circundante conserva estrictamente su nivel físico intacto.
						if hydro != null and not hydro.water_cells.is_empty() and not hydro.water_cells.has(target_pos):
							continue

						if dist_m > cur_w_river:
							continue

						# Si SÍ: H_bed < H_water y se excava el canal con fondo plano uniforme dentro de los límites del agua.
						var bed_y: float = water_y - maxf(0.01, cur_d)
						if hydro != null and hydro.water_cells.has(target_pos):
							bed_y = float(hydro.water_cells[target_pos].get("bed_height", bed_y))
						var carved_h: float = bed_y
						var target_h: float = minf(cell.height, carved_h)

						var current_carved: float = float(carved_cells.get(target_pos, cell.height))
						if target_h < current_carved:
							carved_cells[target_pos] = target_h
							if hydro != null:
								hydro.hydraulic_influence[target_pos] = 1.0


	# Aplicar el tallado sobre cell.height respetando cell.raw_height intacto
	for pos in carved_cells:
		var cell: WorldCell = cells[pos]
		cell.height = float(carved_cells[pos])
		if hydro != null:
			cell.hydraulic_influence = float(hydro.hydraulic_influence.get(pos, 0.0))
		if hydro != null and hydro.water_cells.has(pos):
			var cur_w_h: float = float(hydro.water_cells[pos].get("water_height", cell.height))
			var b_h: float = minf(cell.height, cur_w_h)
			hydro.water_cells[pos]["bed_height"] = b_h
			hydro.water_cells[pos]["depth"] = cur_w_h - b_h

	var t_slope_start := Time.get_ticks_usec() if record_slope else 0
	# Recalcular pendientes para celdas modificadas
	for pos in carved_cells:
		var x: int = pos.x
		var y: int = pos.y
		var cell: WorldCell = cells.get(pos)
		if cell == null:
			continue

		var is_bounded: bool = (not is_unbounded) and profile != null and profile.width > 0 and profile.height > 0
		var clamp_left: bool = is_bounded and (x == 0 if is_chunk else x <= 0)
		var clamp_right: bool = is_bounded and (x == profile.width - 1 if is_chunk else x >= profile.width - 1)
		var clamp_up: bool = is_bounded and (y == 0 if is_chunk else y <= 0)
		var clamp_down: bool = is_bounded and (y == profile.height - 1 if is_chunk else y >= profile.height - 1)

		var c_left: WorldCell = cell if clamp_left else cells.get(Vector2i(x - 1, y), cell)
		var c_right: WorldCell = cell if clamp_right else cells.get(Vector2i(x + 1, y), cell)
		var c_up: WorldCell = cell if clamp_up else cells.get(Vector2i(x, y - 1), cell)
		var c_down: WorldCell = cell if clamp_down else cells.get(Vector2i(x, y + 1), cell)

		var h_left: float = c_left.height if c_left != null else cell.height
		var h_right: float = c_right.height if c_right != null else cell.height
		var h_up: float = c_up.height if c_up != null else cell.height
		var h_down: float = c_down.height if c_down != null else cell.height

		var grad_x := (h_right - h_left) / (2.0 * profile.cell_size)
		var grad_y := (h_down - h_up) / (2.0 * profile.cell_size)
		cell.slope = rad_to_deg(atan(sqrt(grad_x * grad_x + grad_y * grad_y)))

	return (Time.get_ticks_usec() - t_slope_start) if record_slope else 0


# =============================================================================
# BLOQUE 10B: ESCULPIDO DE CUENCAS Y TALUDES DE LAGOS (LAKE CARVING V2)
# =============================================================================

func _carve_lake_basins(
	cells: Dictionary,
	lakes: Array,
	profile: WorldProfile,
	hydro: RefCounted,
	record_slope: bool = false,
	is_chunk: bool = false,
	is_unbounded: bool = false
) -> int:
	if lakes.is_empty():
		return 0

	var carved_lake_cells: Dictionary = {}
	var lake_water_levels: Dictionary = {}
	var lake_shore_levels: Dictionary = {}

	for lake in lakes:
		var cluster: Array = lake.get("cells", [])
		if cluster.is_empty():
			continue

		var lake_set: Dictionary = {}
		for p in cluster:
			lake_set[p] = true

		var shore_h: float
		var bed_h: float
		var water_y: float

		if is_chunk and lake.has("bed_height") and lake.has("water_height"):
			bed_h = float(lake["bed_height"])
			water_y = float(lake["water_height"])
			shore_h = float(lake.get("shoreline_height", water_y + 1.0))
		else:
			# 1. Determinar el nivel de terraza de la orilla circundante
			var max_shore_level: int = -1
			for p in cluster:
				for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var np: Vector2i = p + offset
					if not lake_set.has(np):
						var nc: WorldCell = cells.get(np)
						if nc != null and nc.elevation_level > max_shore_level:
							max_shore_level = nc.elevation_level

			if max_shore_level == -1:
				for p in cluster:
					var c: WorldCell = cells.get(p)
					if c != null and c.elevation_level > max_shore_level:
						max_shore_level = c.elevation_level

			var step: float = profile.elevation_step_height if (profile != null and profile.elevation_step_height > 0.0) else 2.0
			var base: float = profile.base_height if profile != null else 2.0

			shore_h = base + float(max_shore_level) * step
			var bed_level: int = maxi(0, max_shore_level - 1)
			bed_h = base + float(bed_level) * step
			if bed_h >= shore_h:
				bed_h = maxf(0.0, shore_h - step * 0.5)

			# H_water centrado verticalmente a mitad de camino del cliff
			water_y = (shore_h + bed_h) * 0.5
			lake["water_height"] = water_y
			lake["bed_height"] = bed_h
			lake["shoreline_height"] = shore_h

		# 2. FLATTEN WATER TERRAIN: Fondo plano uniforme para todo el cuerpo del lago
		# cell.height recibe la cota plana común bed_h, sin tocar celdas secas exteriores
		for pos in cluster:
			var cell: WorldCell = cells.get(pos)
			if cell == null:
				continue
			carved_lake_cells[pos] = bed_h
			lake_water_levels[pos] = water_y
			lake_shore_levels[pos] = shore_h
			if hydro != null:
				hydro.hydraulic_influence[pos] = 1.0

	# Aplicar el fondo plano uniforme sobre cell.height y sincronizar water_cells
	for pos in carved_lake_cells:
		var cell: WorldCell = cells[pos]
		cell.height = float(carved_lake_cells[pos])
		var w_y: float = float(lake_water_levels.get(pos, cell.height))
		var s_h: float = float(lake_shore_levels.get(pos, w_y + 1.0))
		if hydro != null:
			cell.hydraulic_influence = float(hydro.hydraulic_influence.get(pos, 0.0))
		if hydro != null and hydro.water_cells.has(pos):
			var b_h: float = cell.height
			hydro.water_cells[pos]["bed_height"] = b_h
			hydro.water_cells[pos]["water_height"] = w_y
			hydro.water_cells[pos]["shoreline_height"] = s_h
			hydro.water_cells[pos]["depth"] = w_y - b_h

	var t_slope_start := Time.get_ticks_usec() if record_slope else 0
	# Recalcular pendientes para celdas modificadas
	for pos in carved_lake_cells:
		var x: int = pos.x
		var y: int = pos.y
		var cell: WorldCell = cells.get(pos)
		if cell == null:
			continue

		var is_bounded: bool = (not is_unbounded) and profile != null and profile.width > 0 and profile.height > 0
		var clamp_left: bool = is_bounded and (x == 0 if is_chunk else x <= 0)
		var clamp_right: bool = is_bounded and (x == profile.width - 1 if is_chunk else x >= profile.width - 1)
		var clamp_up: bool = is_bounded and (y == 0 if is_chunk else y <= 0)
		var clamp_down: bool = is_bounded and (y == profile.height - 1 if is_chunk else y >= profile.height - 1)

		var c_left: WorldCell = cell if clamp_left else cells.get(Vector2i(x - 1, y), cell)
		var c_right: WorldCell = cell if clamp_right else cells.get(Vector2i(x + 1, y), cell)
		var c_up: WorldCell = cell if clamp_up else cells.get(Vector2i(x, y - 1), cell)
		var c_down: WorldCell = cell if clamp_down else cells.get(Vector2i(x, y + 1), cell)

		var h_left: float = c_left.height if c_left != null else cell.height
		var h_right: float = c_right.height if c_right != null else cell.height
		var h_up: float = c_up.height if c_up != null else cell.height
		var h_down: float = c_down.height if c_down != null else cell.height

		var grad_x := (h_right - h_left) / (2.0 * profile.cell_size)
		var grad_y := (h_down - h_up) / (2.0 * profile.cell_size)
		cell.slope = rad_to_deg(atan(sqrt(grad_x * grad_x + grad_y * grad_y)))

	return (Time.get_ticks_usec() - t_slope_start) if record_slope else 0


# =============================================================================
# BLOQUE 9: RESTRICCIÓN DE TALUD HIDRÁULICO (DEPRECADO / NO EJECUTADO)
# =============================================================================

## DEPRECADO (Bloque 9): Los acantilados permanecen como paredes verticales (cliff -> cliff).
## Hydrology nunca suaviza el terreno seco ni genera rampas para acomodar agua.
## Esta función ha sido removida del pipeline y retorna inmediatamente.
func _relax_hydraulic_banks(
	cells: Dictionary,
	profile: WorldProfile,
	hydro: RefCounted,
	is_chunk: bool = false,
	is_unbounded: bool = false
) -> void:
	return

	var cell_size: float = profile.cell_size if profile != null else 1.0
	var modified_cells: Dictionary = {}

	# Inicializar con todas las celdas de agua (ríos y lagos) como semillas de influencia
	for pos in hydro.water_cells:
		hydro.hydraulic_influence[pos] = 1.0
		var c: WorldCell = cells.get(pos)
		if c != null:
			c.hydraulic_influence = 1.0

	# BLOQUE 6: Se elimina la relajación BFS de talud artificial que degradaba acantilados secos.
	# Los acantilados permanecen como acantilados verticales salvo donde el canal realmente los atraviesa.

	# -------------------------------------------------------------------------
	# Bisel de Ribera (Shoreline Bank Bevel / Freeboard):
	# Garantiza que el 100% de las orillas secas queden elevadas (+0.18m sobre el agua adyacente)
	# para que la tierra quede siempre por encima del flujo del agua, formando una ribera
	# natural y conteniendo físicamente la superficie del agua.
	# -------------------------------------------------------------------------
	for pos in cells:
		if not hydro.water_cells.has(pos):
			var max_adj_wh: float = -INF
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var np: Vector2i = pos + Vector2i(dx, dy)
					if hydro.water_cells.has(np):
						var wh: float = float(hydro.water_cells[np].get("water_height", 0.0))
						if wh > max_adj_wh:
							max_adj_wh = wh
			if max_adj_wh != -INF:
				var bevel_val: float = profile.shoreline_bank_bevel if (profile != null and "shoreline_bank_bevel" in profile) else 0.18
				var min_bank_h: float = max_adj_wh + bevel_val
				var cell_p: WorldCell = cells.get(pos)
				if cell_p != null and cell_p.height < min_bank_h:
					cell_p.height = min_bank_h
					cell_p.hydraulic_influence = maxf(cell_p.hydraulic_influence, 0.5)
					if hydro != null:
						hydro.hydraulic_influence[pos] = cell_p.hydraulic_influence
					modified_cells[pos] = true

	# Recalcular pendientes para celdas relajadas y biseladas
	for pos in modified_cells:
		var x: int = pos.x
		var y: int = pos.y
		var cell: WorldCell = cells.get(pos)
		if cell == null:
			continue

		var is_bounded: bool = (not is_unbounded) and profile != null and profile.width > 0 and profile.height > 0
		var clamp_left: bool = is_bounded and (x == 0 if is_chunk else x <= 0)
		var clamp_right: bool = is_bounded and (x == profile.width - 1 if is_chunk else x >= profile.width - 1)
		var clamp_up: bool = is_bounded and (y == 0 if is_chunk else y <= 0)
		var clamp_down: bool = is_bounded and (y == profile.height - 1 if is_chunk else y >= profile.height - 1)

		var c_left: WorldCell = cell if clamp_left else cells.get(Vector2i(x - 1, y), cell)
		var c_right: WorldCell = cell if clamp_right else cells.get(Vector2i(x + 1, y), cell)
		var c_up: WorldCell = cell if clamp_up else cells.get(Vector2i(x, y - 1), cell)
		var c_down: WorldCell = cell if clamp_down else cells.get(Vector2i(x, y + 1), cell)

		var h_left: float = c_left.height if c_left != null else cell.height
		var h_right: float = c_right.height if c_right != null else cell.height
		var h_up: float = c_up.height if c_up != null else cell.height
		var h_down: float = c_down.height if c_down != null else cell.height

		var grad_x := (h_right - h_left) / (2.0 * cell_size)
		var grad_y := (h_down - h_up) / (2.0 * cell_size)
		cell.slope = rad_to_deg(atan(sqrt(grad_x * grad_x + grad_y * grad_y)))


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
