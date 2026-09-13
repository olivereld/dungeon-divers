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
	_basins: Dictionary
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

	# 4. Verificar si es un mínimo local relativo (depresión)
	var curr_h: float = cells[p].raw_height if cells.has(p) else endpoint.elevation
	var is_local_depression: bool = true
	for offset in D8_OFFSETS:
		var nb: Vector2i = p + offset
		if cells.has(nb):
			if cells[nb].raw_height < curr_h - 0.01:
				is_local_depression = false
				break

	if is_local_depression:
		endpoint.destination_type = _RiverEndpointScript.DestinationType.LAKE
		return endpoint.destination_type

	endpoint.destination_type = _RiverEndpointScript.DestinationType.LAKE
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
	if target_spillway_h <= seed_raw:
		target_spillway_h = seed_raw + 0.60

	var lake = _LakeCandidateScript.new(lake_id, endpoint)
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [seed_pos]
	visited[seed_pos] = true

	var spill_pos: Vector2i = Vector2i(-1, -1)
	var min_rim_rank: int = 999999999
	var min_rim_h: float = INF

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		lake.add_cell(curr)

		for offset in D8_OFFSETS:
			var nb: Vector2i = curr + offset
			if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= height:
				continue
			if visited.has(nb):
				continue

			var nc: WorldCell = cells.get(nb)
			if nc == null:
				continue

			if nc.raw_height <= target_spillway_h + 0.001 and lake.cells.size() < 120:
				visited[nb] = true
				queue.append(nb)
			else:
				var r_val: int = flood_rank.get(nb, 999999999)
				if r_val < min_rim_rank:
					min_rim_rank = r_val
					spill_pos = nb
					min_rim_h = nc.raw_height

	if lake.cells.size() < min_area:
		return null

	# Encontrar el spillway de cota mínima en el perímetro circundante
	var lake_set: Dictionary = {}
	for c in lake.cells:
		lake_set[c] = true

	var true_rim_h: float = INF
	var true_spill: Vector2i = Vector2i(-1, -1)
	for pos in lake.cells:
		for offset in D8_OFFSETS:
			var nb: Vector2i = pos + offset
			if nb.x < 0 or nb.x >= width or nb.y < 0 or nb.y >= height:
				continue
			if not lake_set.has(nb):
				var nc: WorldCell = cells.get(nb)
				if nc != null and nc.raw_height < true_rim_h:
					true_rim_h = nc.raw_height
					true_spill = nb

	lake.spillway_pos = true_spill if true_spill != Vector2i(-1, -1) else spill_pos
	lake.spillway_height = true_rim_h if not is_inf(true_rim_h) else target_spillway_h
	lake.water_height = minf(target_spillway_h, lake.spillway_height)

	return lake

## Emite y traza un río efluente saliente desde el vertedero de un lago
func trace_lake_outflow(
	lake: RefCounted,
	flow_to: Dictionary,
	accumulation: Dictionary,
	outflow_river_id: int,
	max_steps: int = 350
) -> RefCounted:
	var spill: Vector2i = lake.spillway_pos
	if spill == Vector2i(-1, -1):
		return null

	var outflow_path: Array[Vector2i] = [spill]
	var curr: Vector2i = spill

	for _step in range(max_steps):
		var nxt: Vector2i = flow_to.get(curr, curr)
		if nxt == curr:
			break
		outflow_path.append(nxt)
		curr = nxt

	if outflow_path.size() < 4:
		return null

	var outflow = _RiverScript.new(outflow_river_id, spill, outflow_path)
	outflow.is_outflow = true
	outflow.accumulation_start = float(accumulation.get(spill, 1.0))
	outflow.accumulation_end = float(accumulation.get(outflow_path[-1], 1.0))

	for src_id in lake.source_river_ids:
		outflow.upstream_rivers.append(src_id)

	lake.outflow_river_id = outflow_river_id
	return outflow
