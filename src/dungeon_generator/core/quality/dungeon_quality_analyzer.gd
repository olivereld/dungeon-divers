class_name DungeonQualityAnalyzer
extends RefCounted

## Analizador objetivo de calidad para mazmorras generadas y previamente validadas.
## Calcula métricas espaciales (D1), de corredores (D2), de jugabilidad (D3) y valida los gates (D4).
## 100% puro y determinista: no altera el CellGrid, ni el RoomPlacementPlan, ni los artefactos del pipeline.

const _DungeonQualityReportScript = preload("res://src/dungeon_generator/core/quality/data/dungeon_quality_report.gd")
const _RoomPlacementPlanScript = preload("res://src/dungeon_generator/core/data/room_placement_plan.gd")
const _CorridorPathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")
const _DungeonSemanticResultScript = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
const _GameplayValidationResultScript = preload("res://src/dungeon_generator/core/semantic/data/gameplay_validation_result.gd")
const _KeyDataScript = preload("res://src/dungeon_generator/core/semantic/data/key_data.gd")
const _LockDataScript = preload("res://src/dungeon_generator/core/semantic/data/lock_data.gd")
const _ObjectiveDataScript = preload("res://src/dungeon_generator/core/semantic/data/objective_data.gd")

## Punto de entrada principal a partir de DungeonResult y DungeonSemanticResult opcional.
func analyze(
	dungeon_result: DungeonResult,
	semantic_result: _DungeonSemanticResultScript = null,
	config: DungeonConfig = null
) -> _DungeonQualityReportScript:
	var report := _DungeonQualityReportScript.new()
	if dungeon_result == null:
		report.seal()
		return report

	report.set_seed_val(dungeon_result.seed_used)

	# 1. Determinar Fiabilidad (D4 - Gates)
	var semantic_valid: bool = false
	var gameplay_valid: bool = false

	if semantic_result != null:
		semantic_valid = semantic_result.is_committed and not semantic_result.critical_path_rooms.is_empty()
		if semantic_result.validation_result != null:
			gameplay_valid = semantic_result.validation_result.is_valid()
		else:
			gameplay_valid = semantic_result.gameplay_valid
	elif dungeon_result.get_meta("semantic_result", null) != null:
		var meta_sem = dungeon_result.get_meta("semantic_result")
		semantic_valid = meta_sem.is_committed
		gameplay_valid = meta_sem.gameplay_valid
		semantic_result = meta_sem

	report.set_validity(semantic_valid, gameplay_valid)

	# Si no supera los gates de fiabilidad obligatorios (D4), no calcular métricas D1-D3
	# para evitar introducir ruido estadístico.
	if not (semantic_valid and gameplay_valid):
		report.seal()
		return report

	# 2. Obtener dimensiones del grid si están disponibles
	var grid_bounds := Vector2i.ZERO
	if config != null:
		grid_bounds = Vector2i(config.grid_width, config.grid_height)
	elif dungeon_result.grid != null:
		grid_bounds = Vector2i(dungeon_result.grid.width, dungeon_result.grid.height)

	# 3. Calcular Métricas D1 — Rooms
	var room_metrics := compute_room_metrics(
		dungeon_result.rooms,
		dungeon_result.connections,
		dungeon_result.corridor_paths,
		grid_bounds
	)
	report.set_room_metrics(room_metrics)

	# 4. Calcular Métricas D2 — Corridors
	var corridor_metrics := compute_corridor_metrics(dungeon_result.corridor_paths)
	report.set_corridor_metrics(corridor_metrics)

	# 5. Calcular Métricas D3 — Gameplay
	var gameplay_metrics := compute_gameplay_metrics(
		dungeon_result.rooms,
		dungeon_result.connections,
		dungeon_result.corridor_paths,
		semantic_result
	)
	report.set_gameplay_metrics(gameplay_metrics)

	# 6. Sellar reporte inmutable
	report.seal()
	return report


# =========================================================================
# D1 — ROOM METRICS (Espaciales)
# =========================================================================
func compute_room_metrics(
	rooms: Array, # Array[RoomData]
	connections: Array = [], # Array[RoomConnection]
	corridor_paths: Array = [], # Array[CorridorPath]
	grid_bounds: Vector2i = Vector2i.ZERO
) -> Dictionary:
	var res: Dictionary = {
		"room_fill_ratio": 0.0,
		"nearest_neighbor_cv": 0.0,
		"radial_variance": 0.0,
		"edge_stretch": 0.0
	}

	if rooms.is_empty():
		return res

	# 1. room_fill_ratio
	var total_room_area: int = 0
	var min_x: int = 999999
	var max_x: int = -999999
	var min_y: int = 999999
	var max_y: int = -999999

	for r in rooms:
		if r == null:
			continue
		total_room_area += r.get_area()
		min_x = mini(min_x, r.rect.position.x)
		max_x = maxi(max_x, r.rect.end.x)
		min_y = mini(min_y, r.rect.position.y)
		max_y = maxi(max_y, r.rect.end.y)

	var bounds_area: int = 0
	if grid_bounds.x > 0 and grid_bounds.y > 0:
		bounds_area = grid_bounds.x * grid_bounds.y
	elif max_x > min_x and max_y > min_y:
		bounds_area = (max_x - min_x) * (max_y - min_y)

	if bounds_area > 0:
		res["room_fill_ratio"] = roundf((float(total_room_area) / float(bounds_area)) * 10000.0) / 10000.0

	# 2. nearest_neighbor_cv (Coeficiente de variación de distancia al vecino más cercano)
	if rooms.size() >= 2:
		var nn_distances: Array[float] = []
		for i in range(rooms.size()):
			var c1: Vector2i = rooms[i].get_center()
			var min_dist: float = 1e9
			for j in range(rooms.size()):
				if i == j:
					continue
				var c2: Vector2i = rooms[j].get_center()
				var d: float = c1.distance_to(c2)
				if d < min_dist:
					min_dist = d
			nn_distances.append(min_dist)

		var sum_nn: float = 0.0
		for d in nn_distances:
			sum_nn += d
		var mean_nn: float = sum_nn / float(nn_distances.size())

		var var_nn: float = 0.0
		for d in nn_distances:
			var_nn += (d - mean_nn) * (d - mean_nn)
		var_nn /= float(nn_distances.size())
		var std_nn: float = sqrt(var_nn)

		if mean_nn > 0.0:
			res["nearest_neighbor_cv"] = roundf((std_nn / mean_nn) * 10000.0) / 10000.0

	# 3. radial_variance (Equilibrio respecto al centro / START)
	if rooms.size() >= 2:
		var start_room = null
		var centers: Array[Vector2i] = []
		for r in rooms:
			if r == null:
				continue
			centers.append(r.get_center())
			if r.room_type == &"start" and start_room == null:
				start_room = r

		var origin: Vector2i
		if start_room != null:
			origin = start_room.get_center()
		else:
			# Centroide
			var sx: int = 0
			var sy: int = 0
			for c in centers:
				sx += c.x
				sy += c.y
			origin = Vector2i(roundi(float(sx) / float(centers.size())), roundi(float(sy) / float(centers.size())))

		var radial_dists: Array[float] = []
		for c in centers:
			if c == origin:
				continue
			radial_dists.append(origin.distance_to(c))

		if not radial_dists.is_empty():
			var sum_r: float = 0.0
			for d in radial_dists:
				sum_r += d
			var mean_r: float = sum_r / float(radial_dists.size())
			var var_r: float = 0.0
			for d in radial_dists:
				var_r += (d - mean_r) * (d - mean_r)
			var_r /= float(radial_dists.size())
			res["radial_variance"] = roundf(var_r * 100.0) / 100.0

	# 4. edge_stretch (Longitud real del corredor / Distancia euclidiana entre salas)
	if not connections.is_empty() and not corridor_paths.is_empty():
		var corridor_by_conn: Dictionary = {}
		for cp in corridor_paths:
			if cp != null:
				corridor_by_conn[cp.connection_id] = cp

		var room_by_id: Dictionary = {}
		for r in rooms:
			if r != null:
				room_by_id[r.id] = r

		var stretches: Array[float] = []
		for conn in connections:
			if conn == null or not corridor_by_conn.has(conn.id):
				continue
			var cp = corridor_by_conn[conn.id]
			if cp == null or cp.centerline_cells.is_empty():
				continue
			var ra = room_by_id.get(conn.room_a_id)
			var rb = room_by_id.get(conn.room_b_id)
			if ra == null or rb == null:
				continue
			var euclid_dist: float = ra.get_center().distance_to(rb.get_center())
			if euclid_dist > 0.0:
				var path_len: float = float(cp.centerline_cells.size())
				stretches.append(path_len / euclid_dist)

		if not stretches.is_empty():
			var sum_stretch: float = 0.0
			for st in stretches:
				sum_stretch += st
			res["edge_stretch"] = roundf((sum_stretch / float(stretches.size())) * 10000.0) / 10000.0

	return res


# =========================================================================
# D2 — CORRIDOR METRICS (Geometría de corredores)
# =========================================================================
func compute_corridor_metrics(corridor_paths: Array) -> Dictionary:
	var res: Dictionary = {
		"length_stats": {
			"min": 0,
			"max": 0,
			"mean": 0.0,
			"median": 0
		},
		"length_variance": 0.0,
		"short_corridor_rate": 0.0,
		"turn_count_stats": {
			"min": 0,
			"max": 0,
			"mean": 0.0,
			"total": 0
		},
		"longest_straight_run": 0
	}

	if corridor_paths.is_empty():
		return res

	var lengths: Array[int] = []
	var turns: Array[int] = []
	var max_straight: int = 0
	var short_count: int = 0

	for cp in corridor_paths:
		if cp == null:
			continue
		var l: int = cp.centerline_cells.size()
		lengths.append(l)
		if l <= 3:
			short_count += 1

		var t: int = cp.turn_count
		turns.append(t)

		if cp.longest_straight_run > max_straight:
			max_straight = cp.longest_straight_run

	if lengths.is_empty():
		return res

	lengths.sort()
	turns.sort()
	var n: int = lengths.size()

	# Length stats
	var sum_len: int = 0
	for l in lengths:
		sum_len += l
	var mean_len: float = float(sum_len) / float(n)

	var len_median: int = lengths[n / 2] if n % 2 != 0 else int(roundf(float(lengths[(n / 2) - 1] + lengths[n / 2]) / 2.0))

	res["length_stats"]["min"] = lengths[0]
	res["length_stats"]["max"] = lengths[n - 1]
	res["length_stats"]["mean"] = roundf(mean_len * 100.0) / 100.0
	res["length_stats"]["median"] = len_median

	# Length variance
	var var_len: float = 0.0
	for l in lengths:
		var_len += float((l - mean_len) * (l - mean_len))
	var_len /= float(n)
	res["length_variance"] = roundf(var_len * 100.0) / 100.0

	# Short corridor rate (<= 3 celdas)
	res["short_corridor_rate"] = roundf((float(short_count) / float(n)) * 10000.0) / 10000.0

	# Turn count stats
	var sum_turns: int = 0
	for t in turns:
		sum_turns += t
	res["turn_count_stats"]["min"] = turns[0]
	res["turn_count_stats"]["max"] = turns[n - 1]
	res["turn_count_stats"]["mean"] = roundf((float(sum_turns) / float(n)) * 100.0) / 100.0
	res["turn_count_stats"]["total"] = sum_turns

	# Longest straight run
	res["longest_straight_run"] = max_straight

	return res


# =========================================================================
# D3 — GAMEPLAY METRICS (Experiencia jugable y progresión)
# =========================================================================
func compute_gameplay_metrics(
	rooms: Array,
	connections: Array,
	corridor_paths: Array,
	semantic_result: _DungeonSemanticResultScript
) -> Dictionary:
	var res: Dictionary = {
		"critical_path_length": 0.0,
		"critical_path_room_count": 0,
		"objective_spacing": 0.0,
		"key_lock_spacing": 0.0,
		"start_boss_distance": 0.0,
		"start_goal_distance": 0.0,
		"branch_count": 0,
		"optional_branch_depth": 0.0
	}

	if semantic_result == null:
		return res

	var room_by_id: Dictionary = {}
	for r in rooms:
		if r != null:
			room_by_id[r.id] = r

	var conn_by_pair: Dictionary = {}
	var conn_by_id: Dictionary = {}
	for c in connections:
		if c != null:
			conn_by_id[c.id] = c
			var pair_key1: int = (c.room_a_id << 16) | c.room_b_id
			var pair_key2: int = (c.room_b_id << 16) | c.room_a_id
			conn_by_pair[pair_key1] = c
			conn_by_pair[pair_key2] = c

	var corridor_by_conn: Dictionary = {}
	for cp in corridor_paths:
		if cp != null:
			corridor_by_conn[cp.connection_id] = cp

	# 1. Critical path room count
	var crit_rooms: Array[int] = semantic_result.critical_path_rooms
	res["critical_path_room_count"] = crit_rooms.size()

	# 2. Critical path length (Suma de celdas de corredores a lo largo del camino crítico)
	var cp_length: float = 0.0
	for i in range(crit_rooms.size() - 1):
		var u: int = crit_rooms[i]
		var v: int = crit_rooms[i + 1]
		var pair_key: int = (u << 16) | v
		if conn_by_pair.has(pair_key):
			var conn = conn_by_pair[pair_key]
			if corridor_by_conn.has(conn.id):
				var cp = corridor_by_conn[conn.id]
				cp_length += float(cp.centerline_cells.size())
			elif room_by_id.has(u) and room_by_id.has(v):
				cp_length += room_by_id[u].get_center().distance_to(room_by_id[v].get_center())
			else:
				cp_length += 1.0
		elif room_by_id.has(u) and room_by_id.has(v):
			cp_length += room_by_id[u].get_center().distance_to(room_by_id[v].get_center())
		else:
			cp_length += 1.0

	res["critical_path_length"] = roundf(cp_length * 100.0) / 100.0

	# 3. Objective Spacing (Distribución a lo largo de la profundidad)
	var objectives = semantic_result.objectives
	if not objectives.is_empty():
		var depths: Array[int] = []
		for obj in objectives:
			if obj != null:
				var d: int = semantic_result.depth_map.get(obj.room_id, 0)
				depths.append(d)
		depths.sort()

		if depths.size() >= 2:
			var diff_sum: float = 0.0
			for i in range(depths.size() - 1):
				diff_sum += float(depths[i + 1] - depths[i])
			res["objective_spacing"] = roundf((diff_sum / float(depths.size() - 1)) * 100.0) / 100.0
		elif depths.size() == 1:
			res["objective_spacing"] = float(depths[0])

	# 4. Key-Lock Spacing (Distancia espacial euclidiana entre llave y su cerradura)
	var keys = semantic_result.keys
	var locks = semantic_result.locks
	if not keys.is_empty() and not locks.is_empty():
		var lock_by_id: Dictionary = {}
		var lock_by_req_key: Dictionary = {}
		for l in locks:
			if l != null:
				lock_by_id[l.id] = l
				if l.required_key_id >= 0:
					lock_by_req_key[l.required_key_id] = l

		var kl_distances: Array[float] = []
		for k in keys:
			if k == null:
				continue
			var target_lock = null
			if lock_by_req_key.has(k.id):
				target_lock = lock_by_req_key[k.id]
			elif k.unlocks >= 0 and lock_by_id.has(k.unlocks):
				target_lock = lock_by_id[k.unlocks]

			if target_lock == null:
				continue

			var k_room = room_by_id.get(k.room_id)
			if k_room == null:
				continue
			var k_pos: Vector2i = k_room.get_center()

			var l_pos: Vector2 = Vector2.ZERO
			if target_lock.connection_id >= 0 and conn_by_id.has(target_lock.connection_id):
				var conn = conn_by_id[target_lock.connection_id]
				var ra = room_by_id.get(conn.room_a_id)
				var rb = room_by_id.get(conn.room_b_id)
				if ra != null and rb != null:
					l_pos = (Vector2(ra.get_center()) + Vector2(rb.get_center())) * 0.5
				elif ra != null:
					l_pos = Vector2(ra.get_center())
				elif rb != null:
					l_pos = Vector2(rb.get_center())
			elif target_lock.room_id >= 0 and room_by_id.has(target_lock.room_id):
				l_pos = Vector2(room_by_id[target_lock.room_id].get_center())

			if l_pos != Vector2.ZERO:
				kl_distances.append(Vector2(k_pos).distance_to(l_pos))

		if not kl_distances.is_empty():
			var sum_kl: float = 0.0
			for dist in kl_distances:
				sum_kl += dist
			res["key_lock_spacing"] = roundf((sum_kl / float(kl_distances.size())) * 100.0) / 100.0

	# 5. Start-Boss Distance & Start-Goal Distance
	var start_room = room_by_id.get(semantic_result.start_room_id)
	var boss_room = room_by_id.get(semantic_result.boss_room_id)

	if start_room != null and boss_room != null:
		res["start_boss_distance"] = roundf(start_room.get_center().distance_to(boss_room.get_center()) * 100.0) / 100.0

	# Buscar goal room si es diferente de boss
	var goal_room = null
	for r in rooms:
		if r != null and r.room_type == &"goal" and r.id != semantic_result.boss_room_id:
			goal_room = r
			break
	if start_room != null and goal_room != null:
		res["start_goal_distance"] = roundf(start_room.get_center().distance_to(goal_room.get_center()) * 100.0) / 100.0

	# 6. Branch Count & Optional Branch Depth
	var crit_set: Dictionary = {}
	for r_id in crit_rooms:
		crit_set[r_id] = true

	# Construir adyacencia
	var adj: Dictionary = {}
	for c in connections:
		if c == null:
			continue
		if not adj.has(c.room_a_id): adj[c.room_a_id] = []
		if not adj.has(c.room_b_id): adj[c.room_b_id] = []
		adj[c.room_a_id].append(c.room_b_id)
		adj[c.room_b_id].append(c.room_a_id)

	var branch_roots: Array[int] = []
	for c_id in crit_rooms:
		for neighbor in adj.get(c_id, []):
			if not crit_set.has(neighbor):
				if not branch_roots.has(neighbor):
					branch_roots.append(neighbor)

	res["branch_count"] = branch_roots.size()

	if not branch_roots.is_empty():
		var branch_depths: Array[int] = []
		for root_id in branch_roots:
			# BFS en salas fuera del camino crítico
			var visited: Dictionary = {}
			visited[root_id] = 1
			var queue: Array[int] = [root_id]
			var max_d: int = 1

			while not queue.is_empty():
				var curr: int = queue.pop_front()
				var d: int = visited[curr]
				if d > max_d:
					max_d = d
				for nbr in adj.get(curr, []):
					if not crit_set.has(nbr) and not visited.has(nbr):
						visited[nbr] = d + 1
						queue.append(nbr)

			branch_depths.append(max_d)

		var sum_depth: int = 0
		for bd in branch_depths:
			sum_depth += bd
		res["optional_branch_depth"] = roundf((float(sum_depth) / float(branch_depths.size())) * 100.0) / 100.0

	return res
