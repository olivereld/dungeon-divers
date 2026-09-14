class_name WaterTopologyBuilder
extends RefCounted

## Constructor de topología hidrológica unificada.
## Transforma el resultado de HydrologyStage en un grafo continuo de WaterCells
## y particiona el sistema hidrológico en componentes conexos (WaterRegion).

const _WaterCellScript = preload("res://src/world_generator/presentation/water/water_cell.gd")
const _WaterRegionScript = preload("res://src/world_generator/presentation/water/water_region.gd")

static func build_regions(result: WorldResult, profile: WorldProfile = null) -> Array:
	var regions: Array = []
	if result == null or result.hydrology == null:
		return regions

	var hydro = result.hydrology
	var raw_water_cells: Dictionary = hydro.water_cells
	if raw_water_cells.is_empty() and hydro.rivers.is_empty() and hydro.lakes.is_empty():
		return regions

	# 1. Construir el mapa de WaterCell base
	var cell_map: Dictionary = {} # Vector2i -> WaterCell
	_build_initial_water_cells(cell_map, hydro, result, profile)

	if cell_map.is_empty():
		return regions

	# 2. Identificar y clasificar celdas de transición (río -> lago) y emisarios (lago -> vertedero)
	_classify_transitions_and_outlets(cell_map, hydro, result)

	# 3. Establecer adyacencias y vecindad (D8 para continuidad de diagonales)
	_connect_neighbors(cell_map)

	# 4. Agrupar en regiones conectadas (Connected Components BFS)
	regions = _extract_connected_regions(cell_map, hydro)

	return regions

static func _build_initial_water_cells(
	cell_map: Dictionary,
	hydro: RefCounted,
	result: WorldResult,
	profile: WorldProfile
) -> void:
	var default_depth: float = 0.3
	if profile != null and "river_channel_depth" in profile:
		default_depth = float(profile.river_channel_depth)

	# 1. Celdas registradas en hydro.water_cells
	for pos in hydro.water_cells.keys():
		var data: Dictionary = hydro.water_cells[pos]
		var type_str: String = data.get("type", "river")
		var w_type: int = _WaterCellScript.Type.LAKE if type_str == "lake" else _WaterCellScript.Type.RIVER

		var w_height: float = float(data.get("water_height", 0.0))
		var b_height: float = float(data.get("bed_height", w_height - default_depth))
		var depth: float = float(data.get("depth", maxf(w_height - b_height, 0.05)))
		var flow: Vector2 = data.get("flow_dir", Vector2.ZERO)
		var r_id: int = int(data.get("river_index", -1))
		var l_id: int = int(data.get("lake_id", -1))

		var cell = _WaterCellScript.new(pos, w_height, b_height, depth, flow, w_type)
		cell.river_id = r_id
		cell.lake_id = l_id
		cell.shoreline_height = float(data.get("shoreline_height", w_height))
		cell_map[pos] = cell

	# 2. Asegurar que todas las celdas de los ríos estén en el mapa
	for r in hydro.rivers:
		var r_id: int = r.id if "id" in r else r.get("id", -1)
		var r_cells: Array = r.cells if "cells" in r else r.get("cells", [])
		var r_pts: Array = r.points if "points" in r else r.get("points", [])
		var r_widths: Array = r.widths if "widths" in r else r.get("widths", [])
		var r_depths: Array = r.depths if "depths" in r else r.get("depths", [])

		for i in range(r_cells.size()):
			var cpos: Vector2i = r_cells[i]
			if not cell_map.has(cpos):
				var w_h: float = 0.0
				var b_h: float = 0.0
				var d_val: float = default_depth
				var flow: Vector2 = Vector2.ZERO

				if i < r_pts.size():
					var pt3: Vector3 = r_pts[i]
					w_h = pt3.y
					if i < r_depths.size():
						d_val = float(r_depths[i])
					b_h = w_h - d_val
					if i + 1 < r_pts.size():
						var nxt3: Vector3 = r_pts[i + 1]
						var dir3: Vector3 = (nxt3 - pt3)
						flow = Vector2(dir3.x, dir3.z).normalized()
					elif i > 0:
						var prev3: Vector3 = r_pts[i - 1]
						var dir3: Vector3 = (pt3 - prev3)
						flow = Vector2(dir3.x, dir3.z).normalized()

				var cell = _WaterCellScript.new(cpos, w_h, b_h, d_val, flow, _WaterCellScript.Type.RIVER)
				cell.river_id = r_id
				cell.channel_width = float(r_widths[i]) if i < r_widths.size() else 1.0
				cell_map[cpos] = cell
			else:
				var existing = cell_map[cpos]
				if existing.river_id < 0:
					existing.river_id = r_id

	# 3. Asegurar que todas las celdas de los lagos estén en el mapa
	for lake in hydro.lakes:
		var l_id: int = lake.get("id", -1)
		var l_cells: Array = lake.get("cells", [])
		var l_water_h: float = float(lake.get("water_height", 0.0))

		for cpos in l_cells:
			if not cell_map.has(cpos):
				var cell = _WaterCellScript.new(cpos, l_water_h, l_water_h - 1.0, 1.0, Vector2.ZERO, _WaterCellScript.Type.LAKE)
				cell.lake_id = l_id
				cell_map[cpos] = cell
			else:
				var existing = cell_map[cpos]
				existing.lake_id = l_id
				if existing.water_type != _WaterCellScript.Type.RIVER:
					existing.water_type = _WaterCellScript.Type.LAKE
					existing.water_height = l_water_h

static func _classify_transitions_and_outlets(
	cell_map: Dictionary,
	hydro: RefCounted,
	result: WorldResult
) -> void:
	# Detectar desembocaduras de ríos en lagos (TRANSITION)
	for r in hydro.rivers:
		var r_cells: Array = r.cells if "cells" in r else r.get("cells", [])
		var r_id: int = r.id if "id" in r else r.get("id", -1)
		if r_cells.is_empty():
			continue

		var end_cell: Vector2i = r_cells[-1]
		# Buscar si el río termina adyacente a un lago o dentro de él
		for lake in hydro.lakes:
			var l_cells: Array = lake.get("cells", [])
			var l_id: int = lake.get("id", -1)
			var l_water_h: float = float(lake.get("water_height", 0.0))
			var l_set: Dictionary = {}
			for lc in l_cells:
				l_set[lc] = true

			var is_feeder: bool = false
			var feeder_idx: int = -1

			# Chequear los últimos 4 puntos del río para ver si tocan el lago
			var check_count: int = mini(4, r_cells.size())
			for k in range(r_cells.size() - check_count, r_cells.size()):
				var p: Vector2i = r_cells[k]
				if l_set.has(p):
					is_feeder = true
					feeder_idx = k
					break
				# Chequear adyacencia D8
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if l_set.has(p + Vector2i(dx, dy)):
							is_feeder = true
							feeder_idx = k
							break
					if is_feeder:
						break
				if is_feeder:
					break

			# Si no es adyacente pero está muy cerca (distancia <= 2.5), tender un puente de celdas TRANSITION
			if not is_feeder:
				var closest_lc := Vector2i(-1, -1)
				var min_dist: float = 999.0
				for lc in l_cells:
					var d: float = Vector2(end_cell).distance_to(Vector2(lc))
					if d <= 2.5 and d < min_dist:
						min_dist = d
						closest_lc = lc
				if closest_lc != Vector2i(-1, -1):
					var bridge_cells = _trace_line(end_cell, closest_lc)
					var end_h: float = cell_map[end_cell].water_height if cell_map.has(end_cell) else l_water_h
					for b_i in range(bridge_cells.size()):
						var bp: Vector2i = bridge_cells[b_i]
						var frac: float = float(b_i) / float(maxi(1, bridge_cells.size() - 1))
						var interp_h: float = lerpf(end_h, l_water_h, frac)
						if not cell_map.has(bp):
							var b_cell = _WaterCellScript.new(bp, interp_h, interp_h - 0.4, 0.4, Vector2.ZERO, _WaterCellScript.Type.TRANSITION)
							b_cell.river_id = r_id
							b_cell.lake_id = l_id
							cell_map[bp] = b_cell
						else:
							var ex_cell = cell_map[bp]
							ex_cell.water_type = _WaterCellScript.Type.TRANSITION
							ex_cell.lake_id = l_id
							ex_cell.water_height = interp_h
					is_feeder = true
					feeder_idx = r_cells.size() - 1

			if is_feeder and feeder_idx >= 0:
				# Marcar las celdas de la desembocadura como TRANSITION
				var start_blend: int = maxi(0, feeder_idx - 2)
				for k in range(start_blend, r_cells.size()):
					var tp: Vector2i = r_cells[k]
					if cell_map.has(tp):
						var tc = cell_map[tp]
						tc.water_type = _WaterCellScript.Type.TRANSITION
						tc.lake_id = l_id
						# Interpolar cota hacia la del lago
						var blend_frac: float = float(k - start_blend + 1) / float(r_cells.size() - start_blend + 1)
						tc.water_height = lerpf(tc.water_height, l_water_h, blend_frac)

	# Tender puentes si dos ríos terminan a distancia <= 2.0 celdas
	for r in hydro.rivers:
		var r_cells: Array = r.cells if "cells" in r else r.get("cells", [])
		var r_id: int = r.id if "id" in r else r.get("id", -1)
		var down_id: int = r.downstream_river if "downstream_river" in r else r.get("downstream_river", -1)
		if r_cells.is_empty() or down_id < 0:
			continue
		var end_cell: Vector2i = r_cells[-1]
		# Verificar si end_cell tiene vecinos D8 en cell_map con river_id == down_id
		var has_touch: bool = false
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var adj := end_cell + Vector2i(dx, dy)
				if cell_map.has(adj) and cell_map[adj].river_id == down_id:
					has_touch = true
					break
			if has_touch:
				break
		if not has_touch:
			for r2 in hydro.rivers:
				var r2_id: int = r2.id if "id" in r2 else r2.get("id", -1)
				if r2_id == down_id:
					var r2_cells: Array = r2.cells if "cells" in r2 else r2.get("cells", [])
					var best_p := Vector2i(-1, -1)
					var best_d: float = 999.0
					for p2 in r2_cells:
						var d: float = Vector2(end_cell).distance_to(Vector2(p2))
						if d <= 2.5 and d < best_d:
							best_d = d
							best_p = p2
					if best_p != Vector2i(-1, -1):
						var bridge = _trace_line(end_cell, best_p)
						var h0: float = cell_map[end_cell].water_height if cell_map.has(end_cell) else 0.0
						var h1: float = cell_map[best_p].water_height if cell_map.has(best_p) else h0
						for b_i in range(bridge.size()):
							var bp: Vector2i = bridge[b_i]
							if not cell_map.has(bp):
								var frac: float = float(b_i) / float(maxi(1, bridge.size() - 1))
								var interp_h: float = lerpf(h0, h1, frac)
								var b_cell = _WaterCellScript.new(bp, interp_h, interp_h - 0.4, 0.4, Vector2.ZERO, _WaterCellScript.Type.RIVER)
								b_cell.river_id = r_id
								cell_map[bp] = b_cell
					break

	# Detectar emisarios y vertederos de lagos (OUTLET)
	for lake in hydro.lakes:
		var l_id: int = lake.get("id", -1)
		var spill_pos: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		var l_water_h: float = float(lake.get("water_height", 0.0))
		var outflow_id: int = int(lake.get("outflow_river_id", -1))

		if spill_pos != Vector2i(-1, -1):
			if not cell_map.has(spill_pos):
				var sp_c = _WaterCellScript.new(spill_pos, l_water_h, l_water_h - 0.4, 0.4, Vector2.ZERO, _WaterCellScript.Type.OUTLET)
				cell_map[spill_pos] = sp_c
			var sp_cell = cell_map[spill_pos]
			sp_cell.water_type = _WaterCellScript.Type.OUTLET
			sp_cell.lake_id = l_id
			if outflow_id >= 0:
				sp_cell.river_id = outflow_id

			# Orientar el flujo del vertedero hacia el curso del río emisario y asegurar unión continua
			if outflow_id >= 0:
				for r in hydro.rivers:
					var rid: int = r.id if "id" in r else r.get("id", -1)
					if rid == outflow_id:
						var r_cells: Array = r.cells if "cells" in r else r.get("cells", [])
						if not r_cells.is_empty():
							var first_c: Vector2i = r_cells[0]
							var dist_to_first: float = Vector2(spill_pos).distance_to(Vector2(first_c))
							if dist_to_first > 1.5 and dist_to_first <= 2.5:
								var out_bridge = _trace_line(spill_pos, first_c)
								for bp in out_bridge:
									if not cell_map.has(bp):
										var b_cell = _WaterCellScript.new(bp, l_water_h, l_water_h - 0.4, 0.4, Vector2.ZERO, _WaterCellScript.Type.OUTLET)
										b_cell.river_id = outflow_id
										b_cell.lake_id = l_id
										cell_map[bp] = b_cell
						if r_cells.size() >= 2:
							var d_step: Vector2i = r_cells[1] - r_cells[0]
							sp_cell.flow_dir = Vector2(float(d_step.x), float(d_step.y)).normalized()
						break

static func _trace_line(p0: Vector2i, p1: Vector2i) -> Array[Vector2i]:
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

static func _connect_neighbors(cell_map: Dictionary) -> void:
	for pos in cell_map.keys():
		var cell = cell_map[pos]
		cell.neighbors.clear()
		var p: Vector2i = pos
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var npos: Vector2i = p + Vector2i(dx, dy)
				if cell_map.has(npos):
					cell.neighbors.append(npos)

static func _extract_connected_regions(cell_map: Dictionary, hydro: RefCounted) -> Array:
	var regions: Array = []
	var visited: Dictionary = {}
	var region_id: int = 0

	for start_pos in cell_map.keys():
		if visited.has(start_pos):
			continue

		var region = _WaterRegionScript.new(region_id)
		region_id += 1

		var queue: Array[Vector2i] = [start_pos]
		visited[start_pos] = true

		while not queue.is_empty():
			var curr: Vector2i = queue.pop_front()
			var cell = cell_map[curr]
			region.add_cell(cell)

			for npos in cell.neighbors:
				if not visited.has(npos):
					visited[npos] = true
					queue.append(npos)

		# Registrar ríos de entrada y de salida
		_resolve_region_inlets_and_outlets(region, hydro)
		regions.append(region)

	return regions

static func _resolve_region_inlets_and_outlets(region: RefCounted, hydro: RefCounted) -> void:
	for l_id in region.lake_ids:
		for lake in hydro.lakes:
			if int(lake.get("id", -1)) == l_id:
				var outflow_id: int = int(lake.get("outflow_river_id", -1))
				if outflow_id >= 0 and not region.outflow_rivers.has(outflow_id):
					region.outflow_rivers.append(outflow_id)

	for r_id in region.river_ids:
		if not region.outflow_rivers.has(r_id) and region.has_lakes:
			if not region.inlet_rivers.has(r_id):
				region.inlet_rivers.append(r_id)
