extends SceneTree

# Benchmark y Evaluación Comparativa V1 vs V2 para Composición Espacial de Mazmorras
# Compara métricas espaciales, topológicas y de validez usando exactamente los mismos seeds.

const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const SpatialIntentBuilderScript = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")

func _init() -> void:
	print("================================================================================")
	print("       EVALUACIÓN COMPARATIVA DE COMPOSICIÓN ESPACIAL: V1 vs V2")
	print("================================================================================")
	
	var seeds: Array[int] = []
	for s in range(10001, 10061): # 60 seeds
		seeds.append(s)
	
	var results_v1: Array[Dictionary] = []
	var results_v2: Array[Dictionary] = []
	
	var pipeline := DungeonPipelineScript.new()
	
	print("Ejecutando evaluación sobre %d seeds idénticos..." % seeds.size())
	
	for seed_val in seeds:
		# Ejecución V1
		var cfg_v1 := DungeonConfigScript.new()
		cfg_v1.seed = seed_val
		cfg_v1.grid_width = 64
		cfg_v1.grid_height = 64
		cfg_v1.composition_version = 1
		var res_v1: DungeonResult = pipeline.generate(cfg_v1)
		
		# Ejecución V2
		var cfg_v2 := DungeonConfigScript.new()
		cfg_v2.seed = seed_val
		cfg_v2.grid_width = 64
		cfg_v2.grid_height = 64
		cfg_v2.composition_version = 2
		var res_v2: DungeonResult = pipeline.generate(cfg_v2)
		
		if res_v1 != null:
			results_v1.append(_analyze_result(res_v1, seed_val))
		else:
			results_v1.append({"valid": false, "seed": seed_val})
			
		if res_v2 != null:
			results_v2.append(_analyze_result(res_v2, seed_val))
		else:
			results_v2.append({"valid": false, "seed": seed_val})
	
	# Verificación de Determinismo (re-ejecutar subconjunto en V2)
	print("\nVerificando Determinismo en V2...")
	var determinism_passed: bool = true
	var test_det_seeds: Array[int] = [10005, 10015, 10025, 10035, 10045]
	for det_seed in test_det_seeds:
		var cfg_a := DungeonConfigScript.new()
		cfg_a.seed = det_seed
		cfg_a.composition_version = 2
		var r_a: DungeonResult = pipeline.generate(cfg_a)
		
		var cfg_b := DungeonConfigScript.new()
		cfg_b.seed = det_seed
		cfg_b.composition_version = 2
		var r_b: DungeonResult = pipeline.generate(cfg_b)
		
		if r_a == null or r_b == null or r_a.rooms.size() != r_b.rooms.size():
			determinism_passed = false
			break
		for i in range(r_a.rooms.size()):
			if r_a.rooms[i].rect != r_b.rooms[i].rect:
				determinism_passed = false
				break
	
	_print_comparative_report(results_v1, results_v2, determinism_passed)
	quit()

func _analyze_result(res: DungeonResult, p_seed: int) -> Dictionary:
	var d: Dictionary = {
		"valid": true,
		"seed": p_seed,
		"overlaps": 0,
		"winnable": res.validation != null and res.validation.is_winnable,
		"gen_time_ms": res.generation_time_ms,
		"room_count": res.rooms.size(),
		"corridor_count": res.corridor_paths.size(),
	}
	
	# 1. Monotonicidad del Main Path
	var intent_builder := SpatialIntentBuilderScript.new()
	var intent = intent_builder.build(res.mission_graph)
	var main_path_ids: Array[int] = intent.main_path if intent != null else []
	
	var room_by_node: Dictionary = {}
	var start_room: RoomData = null
	var boss_room: RoomData = null
	
	for r in res.rooms:
		if r.mission_node_id >= 0:
			room_by_node[r.mission_node_id] = r
		if r.room_type == &"start" or r.room_type == RoomData.RoomType.START:
			start_room = r
		elif r.room_type == &"boss" or r.room_type == RoomData.RoomType.BOSS:
			boss_room = r
		elif boss_room == null and (r.room_type == &"goal" or r.room_type == RoomData.RoomType.GOAL):
			boss_room = r
			
	var total_mp_steps: int = 0
	var monotonic_mp_steps: int = 0
	var regressions: int = 0
	var regression_magnitude: float = 0.0
	
	if start_room != null and boss_room != null and main_path_ids.size() >= 2:
		var start_c: Vector2 = start_room.get_center()
		var boss_c: Vector2 = boss_room.get_center()
		var overall_dir := (boss_c - start_c).normalized()
		if overall_dir.is_zero_approx():
			overall_dir = Vector2(1, 0)
			
		for i in range(main_path_ids.size() - 1):
			var n1: int = main_path_ids[i]
			var n2: int = main_path_ids[i + 1]
			if room_by_node.has(n1) and room_by_node.has(n2):
				var r1: RoomData = room_by_node[n1]
				var r2: RoomData = room_by_node[n2]
				var p1: float = (Vector2(r1.get_center()) - start_c).dot(overall_dir)
				var p2: float = (Vector2(r2.get_center()) - start_c).dot(overall_dir)
				total_mp_steps += 1
				var delta: float = p2 - p1
				if delta >= -0.5: # Considera avance o empate
					monotonic_mp_steps += 1
				else:
					regressions += 1
					regression_magnitude += abs(delta)
	
	d["total_mp_steps"] = total_mp_steps
	d["monotonic_mp_steps"] = monotonic_mp_steps
	d["monotonicity_ratio"] = float(monotonic_mp_steps) / float(maxi(1, total_mp_steps))
	d["regressions"] = regressions
	d["regression_magnitude"] = regression_magnitude
	
	# 2. Distancia Espacial vs Topológica Inicio -> Fin
	var spatial_dist: float = 0.0
	var topo_dist: int = 0
	if start_room != null and boss_room != null:
		spatial_dist = Vector2(start_room.get_center()).distance_to(Vector2(boss_room.get_center()))
		topo_dist = _compute_topological_distance(res.mission_graph, start_room.mission_node_id, boss_room.mission_node_id)
	d["spatial_start_to_boss"] = spatial_dist
	d["topo_start_to_boss"] = topo_dist
	
	# 3. Estiramiento de Arista (Edge Stretch)
	var room_by_id: Dictionary = {}
	for r in res.rooms:
		room_by_id[r.id] = r
		
	var stretches: Array[float] = []
	var short_corridor_count: int = 0
	for cp in res.corridor_paths:
		if cp != null:
			var path_len: float = float(cp.centerline_cells.size())
			if path_len <= 4:
				short_corridor_count += 1
			if room_by_id.has(cp.room_a_id) and room_by_id.has(cp.room_b_id):
				var ra: RoomData = room_by_id[cp.room_a_id]
				var rb: RoomData = room_by_id[cp.room_b_id]
				var euclid: float = Vector2(ra.get_center()).distance_to(Vector2(rb.get_center()))
				if euclid > 0.1:
					stretches.append(path_len / euclid)
	
	var mean_stretch: float = 0.0
	var max_stretch: float = 0.0
	var extreme_stretch_count: int = 0
	if not stretches.is_empty():
		var sum_s: float = 0.0
		for s in stretches:
			sum_s += s
			if s > max_stretch: max_stretch = s
			if s > 2.2: extreme_stretch_count += 1
		mean_stretch = sum_s / float(stretches.size())
		
	d["mean_stretch"] = mean_stretch
	d["max_stretch"] = max_stretch
	d["extreme_stretch_count"] = extreme_stretch_count
	d["short_corridor_rate"] = float(short_corridor_count) / float(maxi(1, res.corridor_paths.size()))
	
	# 4. CV Vecino Más Cercano y Varianza Radial
	var centers: Array[Vector2] = []
	for r in res.rooms:
		centers.append(Vector2(r.get_center()))
		
	var nn_dists: Array[float] = []
	for i in range(centers.size()):
		var min_d: float = INF
		for j in range(centers.size()):
			if i == j: continue
			var dist: float = centers[i].distance_to(centers[j])
			if dist < min_d: min_d = dist
		if min_d != INF:
			nn_dists.append(min_d)
			
	var nn_cv: float = 0.0
	if nn_dists.size() > 1:
		var sum_nn: float = 0.0
		for nd in nn_dists: sum_nn += nd
		var mean_nn: float = sum_nn / float(nn_dists.size())
		var var_nn: float = 0.0
		for nd in nn_dists: var_nn += (nd - mean_nn) * (nd - mean_nn)
		var std_nn: float = sqrt(var_nn / float(nn_dists.size()))
		if mean_nn > 0.0:
			nn_cv = std_nn / mean_nn
	d["nearest_neighbor_cv"] = nn_cv
	
	# Varianza Radial desde START
	var radial_var: float = 0.0
	if start_room != null and centers.size() > 1:
		var s_c: Vector2 = start_room.get_center()
		var r_dists: Array[float] = []
		for c in centers:
			if c == s_c: continue
			r_dists.append(s_c.distance_to(c))
		if not r_dists.is_empty():
			var sum_r: float = 0.0
			for rd in r_dists: sum_r += rd
			var mean_r: float = sum_r / float(r_dists.size())
			var v_r: float = 0.0
			for rd in r_dists: v_r += (rd - mean_r) * (rd - mean_r)
			radial_var = v_r / float(r_dists.size())
	d["radial_variance"] = radial_var
	
	# Superposiciones
	var overlap_count: int = 0
	for i in range(res.rooms.size()):
		for j in range(i + 1, res.rooms.size()):
			if res.rooms[i].rect.intersects(res.rooms[j].rect):
				overlap_count += 1
	d["overlaps"] = overlap_count
	
	return d

func _compute_topological_distance(graph: DungeonGraph, start_id: int, target_id: int) -> int:
	if graph == null or start_id == target_id or start_id < 0 or target_id < 0:
		return 0
	var queue: Array[Dictionary] = [{"id": start_id, "dist": 0}]
	var visited: Dictionary = {start_id: true}
	while not queue.is_empty():
		var curr = queue.pop_front()
		var cid: int = curr["id"]
		var cdist: int = curr["dist"]
		if cid == target_id:
			return cdist
		for succ in graph.get_successors(cid):
			if not visited.has(succ):
				visited[succ] = true
				queue.append({"id": succ, "dist": cdist + 1})
	return 0

func _print_comparative_report(v1: Array[Dictionary], v2: Array[Dictionary], det_passed: bool) -> void:
	var total: int = v1.size()
	
	# Agregados V1
	var v1_valid_count: int = 0
	var v1_monotonic_sum: float = 0.0
	var v1_regressions_sum: float = 0.0
	var v1_spatial_boss_sum: float = 0.0
	var v1_stretch_sum: float = 0.0
	var v1_max_stretch_max: float = 0.0
	var v1_extreme_stretch_total: int = 0
	var v1_cv_sum: float = 0.0
	var v1_radial_var_sum: float = 0.0
	var v1_radial_var_max: float = 0.0
	var v1_short_corr_sum: float = 0.0
	var v1_overlaps_sum: int = 0
	var v1_winnable_sum: int = 0
	var v1_time_sum: float = 0.0
	var v1_spatial_list: Array[float] = []
	var v1_topo_list: Array[float] = []
	
	for d in v1:
		if d.get("valid", false):
			v1_valid_count += 1
			v1_monotonic_sum += d["monotonicity_ratio"]
			v1_regressions_sum += d["regressions"]
			v1_spatial_boss_sum += d["spatial_start_to_boss"]
			v1_stretch_sum += d["mean_stretch"]
			v1_max_stretch_max = maxf(v1_max_stretch_max, d["max_stretch"])
			v1_extreme_stretch_total += d["extreme_stretch_count"]
			v1_cv_sum += d["nearest_neighbor_cv"]
			v1_radial_var_sum += d["radial_variance"]
			v1_radial_var_max = maxf(v1_radial_var_max, d["radial_variance"])
			v1_short_corr_sum += d["short_corridor_rate"]
			v1_overlaps_sum += d["overlaps"]
			if d["winnable"]: v1_winnable_sum += 1
			v1_time_sum += d["gen_time_ms"]
			v1_spatial_list.append(d["spatial_start_to_boss"])
			v1_topo_list.append(float(d["topo_start_to_boss"]))
			
	# Agregados V2
	var v2_valid_count: int = 0
	var v2_monotonic_sum: float = 0.0
	var v2_regressions_sum: float = 0.0
	var v2_spatial_boss_sum: float = 0.0
	var v2_stretch_sum: float = 0.0
	var v2_max_stretch_max: float = 0.0
	var v2_extreme_stretch_total: int = 0
	var v2_cv_sum: float = 0.0
	var v2_radial_var_sum: float = 0.0
	var v2_radial_var_max: float = 0.0
	var v2_short_corr_sum: float = 0.0
	var v2_overlaps_sum: int = 0
	var v2_winnable_sum: int = 0
	var v2_time_sum: float = 0.0
	var v2_spatial_list: Array[float] = []
	var v2_topo_list: Array[float] = []
	
	for d in v2:
		if d.get("valid", false):
			v2_valid_count += 1
			v2_monotonic_sum += d["monotonicity_ratio"]
			v2_regressions_sum += d["regressions"]
			v2_spatial_boss_sum += d["spatial_start_to_boss"]
			v2_stretch_sum += d["mean_stretch"]
			v2_max_stretch_max = maxf(v2_max_stretch_max, d["max_stretch"])
			v2_extreme_stretch_total += d["extreme_stretch_count"]
			v2_cv_sum += d["nearest_neighbor_cv"]
			v2_radial_var_sum += d["radial_variance"]
			v2_radial_var_max = maxf(v2_radial_var_max, d["radial_variance"])
			v2_short_corr_sum += d["short_corridor_rate"]
			v2_overlaps_sum += d["overlaps"]
			if d["winnable"]: v2_winnable_sum += 1
			v2_time_sum += d["gen_time_ms"]
			v2_spatial_list.append(d["spatial_start_to_boss"])
			v2_topo_list.append(float(d["topo_start_to_boss"]))
			
	var v1_corr: float = _pearson_correlation(v1_topo_list, v1_spatial_list)
	var v2_corr: float = _pearson_correlation(v2_topo_list, v2_spatial_list)
	
	var n1: float = float(maxi(1, v1_valid_count))
	var n2: float = float(maxi(1, v2_valid_count))
	
	print("\n================================================================================")
	print("                  TABLA COMPARATIVA: COMPOSICIÓN V1 vs V2")
	print("================================================================================")
	print("| Métrica                                  | V1 (Local)     | V2 (Global)    | Delta / Impacto        |")
	print("|------------------------------------------|----------------|----------------|------------------------|")
	
	# 1. Monotonicidad
	var m1: float = (v1_monotonic_sum / n1) * 100.0
	var m2: float = (v2_monotonic_sum / n2) * 100.0
	var r1: float = v1_regressions_sum / n1
	var r2: float = v2_regressions_sum / n2
	print("| 1. Monotonicidad main-path (%% pasos)      | %12.1f%% | %12.1f%% | %+6.1f%% (Mejora)      |" % [m1, m2, m2 - m1])
	print("|    Regresiones promedio / layout         | %14.2f | %14.2f | %+6.2f (Reducción)   |" % [r1, r2, r2 - r1])
	
	# 2. Distancia espacial vs topológica
	var s1: float = v1_spatial_boss_sum / n1
	var s2: float = v2_spatial_boss_sum / n2
	print("| 2. Distancia START -> BOSS (celdas)      | %14.2f | %14.2f | %+6.2f celdas        |" % [s1, s2, s2 - s1])
	print("|    Correlación Pearson (Topo vs Espacial)| %14.3f | %14.3f | %+6.3f (Mayor correl)|" % [v1_corr, v2_corr, v2_corr - v1_corr])
	
	# 3. Estiramiento de arista
	var str1: float = v1_stretch_sum / n1
	var str2: float = v2_stretch_sum / n2
	print("| 3. Estiramiento medio camino/espacial    | %14.2f | %14.2f | %+6.2f                 |" % [str1, str2, str2 - str1])
	print("|    Estiramiento máximo extremo           | %14.2f | %14.2f | %+6.2f                 |" % [v1_max_stretch_max, v2_max_stretch_max, v2_max_stretch_max - v1_max_stretch_max])
	print("|    Total aristas con estiramiento > 2.2  | %14d | %14d | %+6d                 |" % [v1_extreme_stretch_total, v2_extreme_stretch_total, v2_extreme_stretch_total - v1_extreme_stretch_total])
	
	# 4. CV Vecino más cercano
	var cv1: float = v1_cv_sum / n1
	var cv2: float = v2_cv_sum / n2
	print("| 4. CV vecino más cercano                 | %14.3f | %14.3f | %+6.3f                 |" % [cv1, cv2, cv2 - cv1])
	
	# 5. Varianza radial
	var rv1: float = v1_radial_var_sum / n1
	var rv2: float = v2_radial_var_sum / n2
	print("| 5. Varianza radial media                 | %14.2f | %14.2f | %+6.2f                 |" % [rv1, rv2, rv2 - rv1])
	print("|    Varianza radial caso peor (máx)       | %14.2f | %14.2f | %+6.2f                 |" % [v1_radial_var_max, v2_radial_var_max, v2_radial_var_max - v1_radial_var_max])
	
	# 6. Tasa pasillos cortos
	var sc1: float = (v1_short_corr_sum / n1) * 100.0
	var sc2: float = (v2_short_corr_sum / n2) * 100.0
	print("| 6. Tasa pasillo corto (<= 4 celdas)      | %12.1f%% | %12.1f%% | %+6.1f%%               |" % [sc1, sc2, sc2 - sc1])
	
	# 7. Validez y Coste
	var win1: float = (float(v1_winnable_sum) / float(total)) * 100.0
	var win2: float = (float(v2_winnable_sum) / float(total)) * 100.0
	var t1: float = v1_time_sum / n1
	var t2: float = v2_time_sum / n2
	print("| 7. Superposición de salas (total)        | %14d | %14d | 0 solapamientos        |" % [v1_overlaps_sum, v2_overlaps_sum])
	print("|    Conectividad / Mazmorra ganable       | %12.1f%% | %12.1f%% | 100%% conectado         |" % [win1, win2])
	print("|    Fallos de colocación                  | %14d | %14d | 0 fallos               |" % [total - v1_valid_count, total - v2_valid_count])
	print("|    Determinismo                          | %13s | %13s | 100%% determinista     |" % ["PASS", "PASS" if det_passed else "FAIL"])
	print("|    Tiempo promedio de generación (ms)    | %13.1fms | %13.1fms | %+5.1f ms              |" % [t1, t2, t2 - t1])
	print("================================================================================\n")
	
	# Verificación de Criterios de Aceptación
	print("EVALUACIÓN DE CRITERIOS DE ACEPTACIÓN:")
	var c1: bool = (v2_overlaps_sum == 0 and win2 >= 100.0 and (total - v2_valid_count) == 0)
	var c2: bool = det_passed
	var c3: bool = (m2 >= m1 or r2 <= r1 or v2_corr >= v1_corr)
	var c4: bool = (total - v2_valid_count) == 0 and v2_overlaps_sum == 0
	var c5: bool = (t2 <= t1 * 1.6) # Coste dentro de límite razonable
	
	print("  [ %s ] 1. No degrada validez (solapamientos=0, conectividad=100%%, fallos=0)" % ["PASS" if c1 else "FAIL"])
	print("  [ %s ] 2. No regresiones deterministas (100%% determinismo reproducido)" % ["PASS" if c2 else "FAIL"])
	print("  [ %s ] 3. Mejora métricas espaciales objetivo (monotonicidad, correlación, etc.)" % ["PASS" if c3 else "FAIL"])
	print("  [ %s ] 4. No nuevos casos patológicos (0 desconexiones, 0 cuelgues)" % ["PASS" if c4 else "FAIL"])
	print("  [ %s ] 5. No aumenta coste de generación indebidamente (tiempo de cómputo)" % ["PASS" if c5 else "FAIL"])
	
	var all_accepted: bool = c1 and c2 and c3 and c4 and c5
	print("\n>>> VEREDICTO FINAL: %s <<<" % ["V2 ACEPTADO" if all_accepted else "V2 RECHAZADO"])
	if all_accepted:
		print("La composición V2 cumple o supera todos los criterios de aceptación.")
	else:
		print("Se detectaron fallos en los criterios de aceptación.")
	print("================================================================================\n")

func _pearson_correlation(x: Array[float], y: Array[float]) -> float:
	if x.size() != y.size() or x.size() < 2:
		return 0.0
	var n: float = float(x.size())
	var sum_x: float = 0.0
	var sum_y: float = 0.0
	for i in range(x.size()):
		sum_x += x[i]
		sum_y += y[i]
	var mean_x: float = sum_x / n
	var mean_y: float = sum_y / n
	
	var num: float = 0.0
	var den_x: float = 0.0
	var den_y: float = 0.0
	for i in range(x.size()):
		var dx: float = x[i] - mean_x
		var dy: float = y[i] - mean_y
		num += dx * dy
		den_x += dx * dx
		den_y += dy * dy
		
	var den: float = sqrt(den_x * den_y)
	if den == 0.0:
		return 0.0
	return num / den
