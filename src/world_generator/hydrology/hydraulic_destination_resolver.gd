class_name HydraulicDestinationResolver
extends RefCounted

const _RiverEndpointScript = preload("res://src/world_generator/hydrology/river_endpoint.gd")
const _LakeCandidateScript = preload("res://src/world_generator/hydrology/lake_candidate.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")

const D8_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)
]

## Resuelve el destino hidráulico de un endpoint fluvial
func resolve_destination(
	endpoint: RefCounted,
	width: int,
	height: int,
	river_cell_owner: Dictionary,
	cells: Dictionary,
	flow_to: Dictionary,
	_basins: Dictionary,
	filled_height: Dictionary = {}
) -> int:
	var p: Vector2i = endpoint.position

	# 1. Borde del mapa -> Salida natural del mundo (OUT_OF_WORLD)
	if p.x <= 0 or p.x >= width - 1 or p.y <= 0 or p.y >= height - 1:
		endpoint.destination_type = _RiverEndpointScript.DestinationType.OUT_OF_WORLD
		return endpoint.destination_type

	# 2. Confluencia con otro río existente (JOIN_RIVER)
	if river_cell_owner.has(p):
		var other_river_id: int = river_cell_owner[p]
		if other_river_id != endpoint.river_id:
			endpoint.destination_type = _RiverEndpointScript.DestinationType.JOIN_RIVER
			endpoint.target_river_id = other_river_id
			return endpoint.destination_type

	# 3. Sumidero o parada en el campo de flujo -> Candidato natural a lago (LAKE)
	var nxt: Vector2i = flow_to.get(p, p)
	if nxt == p:
		endpoint.destination_type = _RiverEndpointScript.DestinationType.LAKE
		return endpoint.destination_type

	# 4. Depresión topográfica en Priority-Flood (H_filled > H_raw)
	var curr_raw: float = cells[p].raw_height if cells.has(p) else endpoint.elevation
	var curr_filled: float = float(filled_height.get(p, curr_raw))
	if curr_filled > curr_raw + 0.02:
		endpoint.destination_type = _RiverEndpointScript.DestinationType.LAKE
		return endpoint.destination_type

	# 5. Terminación natural en terreno (TERMINATE)
	endpoint.destination_type = _RiverEndpointScript.DestinationType.TERMINATE
	return endpoint.destination_type

## Inunda la topografía desde el seed endpoint para construir un LakeCandidate contenido por su vertedero
func expand_lake_from_endpoint(
	endpoint: RefCounted,
	lake_id: int,
	cells: Dictionary,
	filled_height: Dictionary,
	flood_rank: Dictionary,
	width: int,
	height: int,
	min_area: int = 4
) -> RefCounted:
	var seed_pos: Vector2i = endpoint.position
	if not cells.has(seed_pos):
		return null

	var seed_raw: float = cells[seed_pos].raw_height
	var target_spillway_h: float = float(filled_height.get(seed_pos, seed_raw))

	# Condición física estricta: si H_filled <= H_raw, no existe depresión topográfica contenedora
	if target_spillway_h <= seed_raw + 0.02:
		return null

	var lake = _LakeCandidateScript.new(lake_id, endpoint)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [seed_pos]
	visited[seed_pos] = true

	# Expansión topográfica BFS contenida bajo target_spillway_h (sin límites artificiales de celdas)
	var max_lake_cells: int = width * height
	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		lake.add_cell(curr)
		if lake.cells.size() >= max_lake_cells:
			break

		for offset in D8_OFFSETS:
			var nb: Vector2i = curr + offset
			if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= height:
				continue
			if visited.has(nb):
				continue

			var nc: WorldCell = cells.get(nb)
			if nc == null:
				continue

			# La celda pertenece a la cuenca si su terreno natural está contenido bajo el nivel de vertedero
			if nc.raw_height < target_spillway_h - 0.001:
				visited[nb] = true
				queue.append(nb)

	if lake.cells.size() < min_area:
		return null

	# Encontrar el vertedero real (spillway) de cota mínima en el perímetro circundante
	var lake_set: Dictionary = {}
	for c in lake.cells:
		lake_set[c] = true

	var true_rim_h: float = INF
	var true_spill: Vector2i = Vector2i(-1, -1)
	var min_spill_rank: int = 999999999

	for pos in lake.cells:
		for offset in D8_OFFSETS:
			var nb: Vector2i = pos + offset
			if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= height:
				continue
			if not lake_set.has(nb):
				var nc: WorldCell = cells.get(nb)
				if nc != null:
					var r_val: int = flood_rank.get(nb, 999999999)
					if nc.raw_height < true_rim_h - 0.001:
						true_rim_h = nc.raw_height
						true_spill = nb
						min_spill_rank = r_val
					elif absf(nc.raw_height - true_rim_h) <= 0.001 and r_val < min_spill_rank:
						# Desempate por orden hidrológico Priority-Flood
						true_rim_h = nc.raw_height
						true_spill = nb
						min_spill_rank = r_val

	if true_spill == Vector2i(-1, -1):
		return null

	lake.spillway_pos = true_spill
	lake.spillway_height = true_rim_h
	lake.water_height = true_rim_h

	# Filtrar solo celdas que realmente quedan sumergidas bajo el agua (depth >= 0.04m)
	var submerged_cells: Array[Vector2i] = []
	for c_pos in lake.cells:
		if cells.has(c_pos) and cells[c_pos].raw_height <= lake.water_height - 0.04:
			submerged_cells.append(c_pos)

	if submerged_cells.size() < min_area:
		return null

	lake.cells = submerged_cells
	return lake

## Emite y traza un río efluente saliente desde el vertedero de un lago
func trace_lake_outflow(
	lake: RefCounted,
	flow_to: Dictionary,
	accumulation: Dictionary,
	outflow_river_id: int,
	max_steps: int = 350,
	river_cell_owner: Dictionary = {},
	cells: Dictionary = {},
	filled_height: Dictionary = {},
	basin_classifier: RefCounted = null
) -> RefCounted:
	var spill: Vector2i = lake.spillway_pos
	if spill == Vector2i(-1, -1):
		return null

	# Si el vertedero ya está sobre una celda de un río existente, se conecta directamente como confluencia
	if river_cell_owner.has(spill):
		var target_id: int = river_cell_owner[spill]
		lake.outflow_river_id = target_id
		return null

	var outflow_path: Array[Vector2i] = [spill]
	var curr: Vector2i = spill
	var downstream_id: int = -1
	var confluence_pos: Vector2i = Vector2i(-1, -1)

	for _step in range(max_steps):
		var nxt: Vector2i = flow_to.get(curr, curr)
		if nxt == curr:
			break

		if river_cell_owner.has(nxt):
			outflow_path.append(nxt)
			downstream_id = river_cell_owner[nxt]
			confluence_pos = nxt
			break

		# Intercepción 1: Depresión topográfica cerrada aguas abajo
		if basin_classifier != null and not cells.is_empty() and basin_classifier.is_local_depression(nxt, cells, filled_height, 0.05):
			if outflow_path.size() >= 10:
				outflow_path.append(nxt)
				break

		# Intercepción 2: Zona de convergencia en valle plano
		if basin_classifier != null and not cells.is_empty() and cells.has(nxt):
			var nxt_cell: WorldCell = cells[nxt]
			var nxt_slope: float = nxt_cell.slope if nxt_cell != null else 10.0
			if basin_classifier.detect_convergence_zone(river_cell_owner, nxt, nxt_slope, 3, 2.0):
				if outflow_path.size() >= 10:
					outflow_path.append(nxt)
					break

		outflow_path.append(nxt)
		curr = nxt

	if outflow_path.size() < 2:
		return null

	var outflow = _RiverScript.new(outflow_river_id, spill, outflow_path)
	outflow.is_outflow = true
	outflow.accumulation_start = float(accumulation.get(spill, 1.0))
	outflow.accumulation_end = float(accumulation.get(outflow_path[-1], 1.0))
	outflow.downstream_river = downstream_id
	if downstream_id != -1:
		outflow.outlet = confluence_pos

	for src_id in lake.source_river_ids:
		outflow.upstream_rivers.append(src_id)

	lake.outflow_river_id = outflow_river_id
	return outflow
