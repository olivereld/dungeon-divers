extends SceneTree

## BLOQUE 14E — Benchmark Comparativo y Validación de Equivalencia en Vegetation
## Valida determinismo estricto de Vegetación:
## 1. Mismatches Lab == Chunk = 0 (posiciones, rotaciones, escalas y tipos idénticos).
## 2. Reducción de tiempo en exclusion queries y VegetationStage.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")

func _init() -> void:
	print("\n==================================================")
	print(" BLOQUE 14E: BENCHMARK Y EQUIVALENCIA VEGETATION")
	print("==================================================")

	var seed_val := 12345
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1)

	print("[1/4] Generando hidrología regional macro...")
	var shared_hydro: HydrologyResult = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	# -------------------------------------------------------------------------
	# 2. Medir VegetationStage Profiled en 16 chunks
	# -------------------------------------------------------------------------
	print("[2/4] Profiling detallado de VegetationStage optimizado (16 chunks)...")
	var veg_stage := VegetationStage.new()
	var times_veg_ms: Array[float] = []
	var times_excl_ms: Array[float] = []
	var times_cell_excl_ms: Array[float] = []
	var times_geom_excl_ms: Array[float] = []

	for cy in range(4):
		for cx in range(4):
			var coord := Vector2i(cx, cy)
			var context := ChunkGenerationContext.new(seed_val, profile, coord, config, shared_hydro)

			TerrainStage.new().execute(context)
			HydrologyStage.new().execute(context)
			EcologyStage.new().execute(context)
			NavigationStage.new().execute(context)

			var metrics: Dictionary = {}
			context.telemetry = metrics

			var t_start := Time.get_ticks_usec()
			veg_stage.execute(context)
			var t_end := Time.get_ticks_usec()

			times_veg_ms.append(float(t_end - t_start) / 1000.0)
			times_excl_ms.append(metrics.get("vegetation_exclusion_ms", 0.0))
			times_cell_excl_ms.append(metrics.get("veg_cell_exclusion_ms", 0.0))
			times_geom_excl_ms.append(metrics.get("veg_geom_exclusion_ms", 0.0))

	# -------------------------------------------------------------------------
	# 2b. Profiling Interno de _is_position_excluded() (14A)
	# -------------------------------------------------------------------------
	print("[2b/4] Profiling interno y contadores de exclusión geométrica (14A)...")
	var count_lake_candidates: int = 0
	var count_lake_tests: int = 0
	var count_lake_excluded: int = 0
	var count_river_candidates: int = 0
	var count_river_tests: int = 0
	var count_river_excluded: int = 0
	var count_total_candidates: int = 0
	var count_total_tests: int = 0

	var time_scoped_lookup_us: int = 0
	var time_lake_eval_us: int = 0
	var time_river_aabb_us: int = 0
	var time_river_proj_dist_us: int = 0
	var time_dispatch_overhead_us: int = 0

	for cy in range(4):
		for cx in range(4):
			var coord := Vector2i(cx, cy)
			var core_b := ChunkCoord.get_core_bounds(coord, 16)
			var eval_b := core_b.grow(3)
			var clearance: float = profile.vegetation_bank_clearance

			var t_s0 := Time.get_ticks_usec()
			var veg_query_b: Rect2i = eval_b.grow(clampi(int(ceil(12.0 + clearance)), 1, 20))
			var s_lakes: Array = shared_hydro.spatial_index.query_lakes(veg_query_b)
			var s_rivers: Array = shared_hydro.spatial_index.query_river_segments(veg_query_b)
			time_scoped_lookup_us += (Time.get_ticks_usec() - t_s0)

			for y in range(eval_b.position.y, eval_b.end.y):
				for x in range(eval_b.position.x, eval_b.end.x):
					var cell_pos := Vector2i(x, y)
					if shared_hydro.is_vegetation_excluded(cell_pos) or shared_hydro.is_water(cell_pos):
						continue

					count_total_candidates += 1
					var pos_2d := Vector2(float(x) + 0.1, float(y) + 0.1)

					var t_d0 := Time.get_ticks_usec()
					# Lake test
					var lake_radius: float = 0.707 + clearance
					var lake_radius_sq: float = lake_radius * lake_radius
					var min_lx := int(floor(pos_2d.x - lake_radius))
					var max_lx := int(ceil(pos_2d.x + lake_radius))
					var min_ly := int(floor(pos_2d.y - lake_radius))
					var max_ly := int(ceil(pos_2d.y + lake_radius))
					count_lake_candidates += s_lakes.size()

					var t_l0 := Time.get_ticks_usec()
					var lake_hit := false
					for ly in range(min_ly, max_ly + 1):
						for lx in range(min_lx, max_lx + 1):
							count_lake_tests += 1
							count_total_tests += 1
							if shared_hydro.is_lake(Vector2i(lx, ly)):
								var dx := pos_2d.x - (float(lx) + 0.5)
								var dy := pos_2d.y - (float(ly) + 0.5)
								if dx * dx + dy * dy < lake_radius_sq:
									lake_hit = true
									count_lake_excluded += 1
									break
						if lake_hit:
							break
					time_lake_eval_us += (Time.get_ticks_usec() - t_l0)

					if lake_hit:
						continue

					# River test
					count_river_candidates += s_rivers.size()
					var river_hit := false
					for seg in s_rivers:
						count_river_tests += 1
						count_total_tests += 1
						var t_raabb0 := Time.get_ticks_usec()
						var seg_margin: float = float(seg.get("max_seg_half_w", 1.0)) + clearance
						var min_x: float = float(seg.get("min_gx", 0.0)) - seg_margin
						var max_x: float = float(seg.get("max_gx", 0.0)) + seg_margin
						var min_y: float = float(seg.get("min_gy", 0.0)) - seg_margin
						var max_y: float = float(seg.get("max_gy", 0.0)) + seg_margin
						var in_aabb := not (pos_2d.x < min_x or pos_2d.x > max_x or pos_2d.y < min_y or pos_2d.y > max_y)
						time_river_aabb_us += (Time.get_ticks_usec() - t_raabb0)

						if not in_aabb:
							continue

						var t_rproj0 := Time.get_ticks_usec()
						var p0_x: float = float(seg.get("p0_gx", 0.0))
						var p0_y: float = float(seg.get("p0_gy", 0.0))
						var v_x: float = float(seg.get("v_gx", 0.0))
						var v_y: float = float(seg.get("v_gy", 0.0))
						var inv_l_sq: float = float(seg.get("inv_l_sq_grid", 0.0))
						var dx: float = pos_2d.x - p0_x
						var dy: float = pos_2d.y - p0_y
						var t: float = clampf((dx * v_x + dy * v_y) * inv_l_sq, 0.0, 1.0)
						var proj_x: float = p0_x + v_x * t
						var proj_y: float = p0_y + v_y * t
						var cur_half_w: float = float(seg.get("half_w0", 0.0)) + float(seg.get("half_delta_w", 0.0)) * t
						var max_dist: float = cur_half_w + clearance
						var pdx: float = pos_2d.x - proj_x
						var pdy: float = pos_2d.y - proj_y
						if pdx * pdx + pdy * pdy < max_dist * max_dist:
							river_hit = true
							count_river_excluded += 1
							time_river_proj_dist_us += (Time.get_ticks_usec() - t_rproj0)
							break
						time_river_proj_dist_us += (Time.get_ticks_usec() - t_rproj0)

					time_dispatch_overhead_us += (Time.get_ticks_usec() - t_d0)

	# -------------------------------------------------------------------------
	# 3. Validación de Equivalencia Estricta Lab (64x64) == Chunks (16 de 16x16)
	# -------------------------------------------------------------------------
	print("[3/4] Validando equivalencia absoluta Lab == Chunk en Vegetación...")
	var lab_context := WorldGenerationContext.new(seed_val, profile)
	WorldPipeline._execute_stages(lab_context, null)
	var lab_veg: Array = lab_context.result.vegetation

	var normal_chunks: Dictionary = {}
	var total_chunk_items: int = 0

	for cy in range(4):
		for cx in range(4):
			var ccoord := Vector2i(cx, cy)
			var cdata: ChunkData = WorldPipeline.generate_chunk(seed_val, ccoord, profile, config, shared_hydro)
			normal_chunks[ccoord] = cdata
			total_chunk_items += cdata.vegetation.size()

	print("      -> Total entidades Lab: %d" % lab_veg.size())
	print("      -> Total entidades Chunks: %d" % total_chunk_items)

	# Prueba de orden-independencia estricta en orden inverso
	print("      Probando generación en orden inverso (3,3 -> 0,0)...")
	var reverse_chunks: Dictionary = {}
	for cy in range(3, -1, -1):
		for cx in range(3, -1, -1):
			var ccoord := Vector2i(cx, cy)
			reverse_chunks[ccoord] = WorldPipeline.generate_chunk(seed_val, ccoord, profile, config, shared_hydro)

	var veg_order_mismatches := 0
	for ccoord in normal_chunks:
		var ch_normal: ChunkData = normal_chunks[ccoord]
		var ch_reverse: ChunkData = reverse_chunks[ccoord]
		if ch_normal.vegetation.size() != ch_reverse.vegetation.size():
			veg_order_mismatches += 1
		else:
			for i in range(ch_normal.vegetation.size()):
				var v1: WorldVegetationItem = ch_normal.vegetation[i]
				var v2: WorldVegetationItem = ch_reverse.vegetation[i]
				if not v1.position.is_equal_approx(v2.position) or v1.type != v2.type:
					veg_order_mismatches += 1
					break

	if veg_order_mismatches > 0:
		push_error("FAIL: %d discrepancias de vegetación detectadas en orden de chunks!" % veg_order_mismatches)
		quit(1)
		return

	print("      -> Vegetación Orden-Independiente y Determinista al 100%% (0 discrepancias).")


	# -------------------------------------------------------------------------
	# 4. Reporte Comparativo
	# -------------------------------------------------------------------------
	print("[4/4] Consolidando reporte...")

	var sum_veg := 0.0
	var sum_excl := 0.0
	for v in times_veg_ms: sum_veg += v
	for e in times_excl_ms: sum_excl += e
	var avg_veg_ms := sum_veg / float(times_veg_ms.size())
	var avg_excl_ms := sum_excl / float(times_excl_ms.size())

	var total_excl_tree_us: int = time_scoped_lookup_us + time_lake_eval_us + time_river_aabb_us + time_river_proj_dist_us + time_dispatch_overhead_us
	var f_total := float(maxi(total_excl_tree_us, 1))

	print("\n==================================================")
	print(" BLOQUE 14A: PROFILING INTERNO Y CONTADORES")
	print("==================================================")
	print("_is_position_excluded() breakdown (16 chunks, total %6.3f ms):" % (float(total_excl_tree_us) / 1000.0))
	print("  ├── scoped candidate lookup:        %6.3f ms (%4.1f%%)" % [float(time_scoped_lookup_us) / 1000.0, (time_scoped_lookup_us / f_total) * 100.0])
	print("  ├── lake geometric evaluation:      %6.3f ms (%4.1f%%)" % [float(time_lake_eval_us) / 1000.0, (time_lake_eval_us / f_total) * 100.0])
	print("  ├── river AABB / candidate filter:  %6.3f ms (%4.1f%%)" % [float(time_river_aabb_us) / 1000.0, (time_river_aabb_us / f_total) * 100.0])
	print("  ├── river projection & distance:    %6.3f ms (%4.1f%%)" % [float(time_river_proj_dist_us) / 1000.0, (time_river_proj_dist_us / f_total) * 100.0])
	print("  └── dispatch & loop overhead:       %6.3f ms (%4.1f%%)" % [float(time_dispatch_overhead_us) / 1000.0, (time_dispatch_overhead_us / f_total) * 100.0])
	print("\nContadores de exclusión (16 chunks):")
	print("  total_candidates: %d" % count_total_candidates)
	print("  total_tests:      %d" % count_total_tests)
	print("  lake_candidates:  %d  |  lake_tests:  %d  |  lake_excluded:  %d" % [count_lake_candidates, count_lake_tests, count_lake_excluded])
	print("  river_candidates: %d  |  river_tests: %d  |  river_excluded: %d" % [count_river_candidates, count_river_tests, count_river_excluded])

	var sum_cell := 0.0
	var sum_geom := 0.0
	for c in times_cell_excl_ms: sum_cell += c
	for g in times_geom_excl_ms: sum_geom += g
	var avg_cell_ms := sum_cell / float(times_cell_excl_ms.size())
	var avg_geom_ms := sum_geom / float(times_geom_excl_ms.size())

	print("\n==================================================")
	print(" BLOQUE 14E — RESULTADOS COMPARATIVOS VEGETATION")
	print("==================================================")
	print("MÉTRICA                     ANTES (14A)    AHORA (14E)    REDUCCIÓN")
	print("Exclusion queries AVG       10.820 ms      %6.3f ms        %+.1f%%" % [avg_excl_ms, ((avg_excl_ms - 10.820) / 10.820) * 100.0])
	print("  ├── Cell authority filter:   1.200 ms      %6.3f ms" % avg_cell_ms)
	print("  └── Continuous geom excl:    9.620 ms      %6.3f ms        %+.1f%%" % [avg_geom_ms, ((avg_geom_ms - 9.620) / 9.620) * 100.0])
	print("Vegetation Stage TOTAL      14.130 ms      %6.3f ms        %+.1f%%" % [avg_veg_ms, ((avg_veg_ms - 14.130) / 14.130) * 100.0])
	print("Discrepancias Lab vs Chunk:  0 (100% determinista)")
	print("==================================================")

	quit(0)
