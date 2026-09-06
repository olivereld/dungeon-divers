extends SceneTree

# Benchmark y Evaluación de Calidad Espacial para CompositionStrategy
# Evalúa métricas espaciales, topológicas, determinismo y ausencia total de solapamientos sobre 100 seeds.

const DungeonPipelineScript = preload("res://src/dungeon_generator/core/dungeon_pipeline.gd")
const DungeonConfigScript = preload("res://src/dungeon_generator/config/dungeon_config.gd")
const RoomDataScript = preload("res://src/dungeon_generator/core/data/room_data.gd")
const SpatialIntentBuilderScript = preload("res://src/dungeon_generator/core/grammars/spatial_intent_builder.gd")

func _init() -> void:
	print("================================================================================")
	print("       EVALUACIÓN Y BENCHMARK ESPACIAL: COMPOSITION STRATEGY")
	print("================================================================================")
	
	var seeds: Array[int] = []
	for s in range(10001, 10101): # 100 seeds
		seeds.append(s)
	
	var results: Array[Dictionary] = []
	var pipeline := DungeonPipelineScript.new()
	
	print("Ejecutando evaluación sobre %d seeds..." % seeds.size())
	
	for seed_val in seeds:
		var cfg := DungeonConfigScript.new()
		cfg.seed = seed_val
		cfg.grid_width = 64
		cfg.grid_height = 64
		var res: DungeonResult = pipeline.generate(cfg)
		
		if res != null:
			results.append(_analyze_result(res, seed_val))
		else:
			results.append({"valid": false, "seed": seed_val})
	
	# Verificación de Determinismo (re-ejecutar subconjunto)
	print("\nVerificando Determinismo...")
	var determinism_passed: bool = true
	var test_det_seeds: Array[int] = [10005, 10015, 10025, 10035, 10045, 10055, 10065, 10075, 10085, 10095]
	for det_seed in test_det_seeds:
		var cfg_a := DungeonConfigScript.new()
		cfg_a.seed = det_seed
		var r_a: DungeonResult = pipeline.generate(cfg_a)
		
		var cfg_b := DungeonConfigScript.new()
		cfg_b.seed = det_seed
		var r_b: DungeonResult = pipeline.generate(cfg_b)
		
		if r_a == null or r_b == null or r_a.rooms.size() != r_b.rooms.size():
			determinism_passed = false
			break
		for i in range(r_a.rooms.size()):
			if r_a.rooms[i].rect != r_b.rooms[i].rect:
				determinism_passed = false
				break
	
	_print_report(results, determinism_passed)
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
	
	# Verificar colisiones / solapamientos entre salas
	for i in range(res.rooms.size()):
		for j in range(i + 1, res.rooms.size()):
			if res.rooms[i].rect.intersects(res.rooms[j].rect):
				d["overlaps"] += 1
	
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
				if delta >= -0.5:
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
	
	return d

func _compute_topological_distance(graph: DungeonGraph, from_node: int, to_node: int) -> int:
	if graph == null or from_node < 0 or to_node < 0:
		return 0
	if from_node == to_node:
		return 0
	var visited: Dictionary = {}
	var queue: Array[Array] = [[from_node, 0]]
	visited[from_node] = true
	while not queue.is_empty():
		var curr = queue.pop_front()
		var u: int = curr[0]
		var d: int = curr[1]
		if u == to_node:
			return d
		for v in graph.get_neighbors(u):
			if not visited.has(v):
				visited[v] = true
				queue.append([v, d + 1])
	return 0

func _print_report(results: Array[Dictionary], determinism: bool) -> void:
	var total := results.size()
	var valid_count := 0
	var winnable_count := 0
	var total_overlaps := 0
	var sum_mono := 0.0
	var sum_spatial_dist := 0.0
	var sum_stretch := 0.0
	var sum_extreme := 0
	var sum_time := 0.0
	
	for r in results:
		if r.get("valid", false):
			valid_count += 1
			if r.get("winnable", false): winnable_count += 1
			total_overlaps += r.get("overlaps", 0)
			sum_mono += r.get("monotonicity_ratio", 0.0)
			sum_spatial_dist += r.get("spatial_start_to_boss", 0.0)
			sum_stretch += r.get("mean_stretch", 0.0)
			sum_extreme += r.get("extreme_stretch_count", 0)
			sum_time += r.get("gen_time_ms", 0.0)
			
	var v_denom := float(maxi(1, valid_count))
	
	print("\n================================================================================")
	print("                         RESULTADOS DEL BENCHMARK")
	print("================================================================================")
	print("Total Dungeons Evaluadas:     %d" % total)
	print("Tasa de Éxito:               %.1f%% (%d/%d)" % [float(valid_count) / float(total) * 100.0, valid_count, total])
	print("Tasa de Jugabilidad:         %.1f%% (%d/%d)" % [float(winnable_count) / float(total) * 100.0, winnable_count, total])
	print("Solapamientos Detectados:    %d" % total_overlaps)
	print("Monotonicidad Media:         %.2f%%" % [(sum_mono / v_denom) * 100.0])
	print("Distancia Media Start->Boss: %.2f celdas" % [sum_spatial_dist / v_denom])
	print("Mean Edge Stretch:           %.2f" % [sum_stretch / v_denom])
	print("Corredores Extremos (>2.2):  %d" % sum_extreme)
	print("Tiempo Medio de Generación:  %.2f ms" % [sum_time / v_denom])
	print("Determinismo:                %s" % ["PASADO [OK]" if determinism else "FALLADO [FAIL]"])
	print("================================================================================")
	
	assert(valid_count == total, "Todas las mazmorras deben generarse con éxito")
	assert(winnable_count == total, "Todas las mazmorras deben ser jugables/alcanzables")
	assert(total_overlaps == 0, "No debe haber ningún solapamiento de salas")
	assert(determinism, "La generación debe ser 100% determinista")
	print("BENCHMARK COMPLETADO EXITOSAMENTE CON 100% APROBACIÓN.")
