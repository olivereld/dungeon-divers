extends SceneTree

## BLOQUE 9 — Profiling y Presupuesto de Rendimiento
## Mide los costes de CPU por etapa, tiempo de integración en Main Thread,
## telemetría de streaming y estabilidad de memoria en un recorrido representativo.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkWorldIntegrationScript = preload("res://src/world_generator/scenes/chunk_world_integration.gd")

func _init() -> void:
	print("\n==================================================")
	print(" INICIANDO BENCHMARK DE RENDIMIENTO (BLOQUE 9)")
	print("==================================================")

	var seed_val := 12345
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1)

	# -------------------------------------------------------------------------
	# 1. Medición de Memoria Baseline Inicial
	# -------------------------------------------------------------------------
	var mem_baseline_bytes: int = OS.get_static_memory_usage()
	var mem_peak_bytes: int = mem_baseline_bytes

	print("[1/5] Generando hidrología regional macro...")
	var shared_hydro: HydrologyResult = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	mem_peak_bytes = maxi(mem_peak_bytes, OS.get_static_memory_usage())

	# -------------------------------------------------------------------------
	# 2. Profiling CPU por Stage (Muestra de 10 Chunks)
	# -------------------------------------------------------------------------
	print("[2/5] Profiling detallado de CPU por etapa (10 chunks de muestra)...")
	var cpu_terrain: Array[float] = []
	var cpu_hydro: Array[float] = []
	var cpu_eco: Array[float] = []
	var cpu_nav: Array[float] = []
	var cpu_veg: Array[float] = []
	var cpu_total: Array[float] = []

	for i in range(10):
		var coord := Vector2i(i, i)
		var res: Dictionary = _WorldPipelineScript.generate_chunk_profiled(
			seed_val, coord, profile, config, shared_hydro
		)
		var m: Dictionary = res["metrics"]
		cpu_terrain.append(m["terrain_ms"])
		cpu_hydro.append(m["hydrology_ms"])
		cpu_eco.append(m["ecology_ms"])
		cpu_nav.append(m["navigation_ms"])
		cpu_veg.append(m["vegetation_ms"])
		cpu_total.append(m["generation_total_ms"])
		mem_peak_bytes = maxi(mem_peak_bytes, OS.get_static_memory_usage())

	# -------------------------------------------------------------------------
	# 3. Inicializar Escena de Integración y Streaming Real
	# -------------------------------------------------------------------------
	print("[3/5] Inicializando escena y ejecutando recorrido continuo (>100 cruces)...")
	var scene = _ChunkWorldIntegrationScript.new()
	scene.world_seed = seed_val
	root.add_child(scene)
	if scene.chunk_world == null:
		scene._ready()

	var world: ChunkWorld = scene.chunk_world
	var player: CharacterBody3D = scene.player
	var manager: WorldChunkManager = world.chunk_manager

	manager.reset_stats()

	var mem_after_10: int = 0
	var mem_after_50: int = 0
	var mem_after_100: int = 0

	var total_crossings := 0

	# 3.1 Recorrido en X (50 cruces a 16m por chunk)
	for step in range(1, 55):
		player.position = Vector3(float(step) * 16.0 + 8.0, 20.0, 8.0)
		world.update_player_streaming()
		world.flush_async_queue()
		total_crossings += 1

		var cur_mem: int = OS.get_static_memory_usage()
		mem_peak_bytes = maxi(mem_peak_bytes, cur_mem)
		if total_crossings == 10:
			mem_after_10 = cur_mem
		elif total_crossings == 50:
			mem_after_50 = cur_mem

	# 3.2 Recorrido en Z (55 cruces a 16m por chunk)
	for step in range(1, 56):
		player.position = Vector3(player.position.x, 20.0, float(step) * 16.0 + 8.0)
		world.update_player_streaming()
		world.flush_async_queue()
		total_crossings += 1

		var cur_mem: int = OS.get_static_memory_usage()
		mem_peak_bytes = maxi(mem_peak_bytes, cur_mem)
		if total_crossings == 100:
			mem_after_100 = cur_mem

	print("      -> Recorrido continuo completado: %d cruces de chunks." % total_crossings)

	# -------------------------------------------------------------------------
	# 4. Movimiento Rápido (Ráfaga / Teleport) para Descarte Cooperativo
	# -------------------------------------------------------------------------
	print("[4/5] Simulando ráfagas y teleports para medir descartes por token...")
	# Ráfaga rápida cambiando de dirección antes de procesar la cola
	player.position = Vector3(2000.0, 20.0, 2000.0)
	world.update_player_streaming()
	player.position = Vector3(-1500.0, 20.0, -1500.0)
	world.update_player_streaming()
	player.position = Vector3(500.0, 20.0, -500.0)
	world.update_player_streaming()
	# Procesar
	world.flush_async_queue()

	# -------------------------------------------------------------------------
	# 5. Regreso al Origen y Medición de Convergencia
	# -------------------------------------------------------------------------
	print("[5/5] Regresando al origen y midiendo tiempo de convergencia...")
	player.position = Vector3(8.0, 20.0, 8.0)

	var t_conv_start := Time.get_ticks_usec()
	world.update_player_streaming()
	world.flush_async_queue()
	var t_conv_end := Time.get_ticks_usec()

	var convergence_ms := float(t_conv_end - t_conv_start) / 1000.0

	var mem_final_bytes: int = OS.get_static_memory_usage()
	mem_peak_bytes = maxi(mem_peak_bytes, mem_final_bytes)

	# -------------------------------------------------------------------------
	# Cálculo de Métricas y Estadísticas
	# -------------------------------------------------------------------------
	var s_terrain := _calc_stats(cpu_terrain)
	var s_hydro := _calc_stats(cpu_hydro)
	var s_eco := _calc_stats(cpu_eco)
	var s_nav := _calc_stats(cpu_nav)
	var s_veg := _calc_stats(cpu_veg)
	var s_total_cpu := _calc_stats(cpu_total)

	# Métricas de Main Thread Integration
	var int_mesh: Array[float] = []
	var int_col: Array[float] = []
	var int_veg: Array[float] = []
	var int_total: Array[float] = []

	for timing in world.integration_timings:
		int_mesh.append(timing["mesh_ms"])
		int_col.append(timing["collision_ms"])
		int_veg.append(timing["vegetation_ms"])
		int_total.append(timing["total_ms"])

	var s_mesh := _calc_stats(int_mesh)
	var s_col := _calc_stats(int_col)
	var s_iveg := _calc_stats(int_veg)
	var s_itotal := _calc_stats(int_total)

	world.shutdown()

	# -------------------------------------------------------------------------
	# Emisión del Reporte
	# -------------------------------------------------------------------------
	var to_mb := 1.0 / (1024.0 * 1024.0)
	var base_mb := float(mem_baseline_bytes) * to_mb
	var peak_mb := float(mem_peak_bytes) * to_mb
	var final_mb := float(mem_final_bytes) * to_mb
	var delta_mb := final_mb - base_mb

	print("\n==================================================")
	print(" BLOQUE 9: PERFORMANCE PROFILE")
	print("==================================================")
	print("\nCPU GENERATION (Sample: %d chunks)" % cpu_total.size())
	print("              %-10s %-10s %-10s" % ["AVG", "P95", "MAX"])
	print("Terrain       %-10s %-10s %-10s" % [_fmt_ms(s_terrain.avg), _fmt_ms(s_terrain.p95), _fmt_ms(s_terrain.max)])
	print("Hydrology     %-10s %-10s %-10s" % [_fmt_ms(s_hydro.avg), _fmt_ms(s_hydro.p95), _fmt_ms(s_hydro.max)])
	print("Ecology       %-10s %-10s %-10s" % [_fmt_ms(s_eco.avg), _fmt_ms(s_eco.p95), _fmt_ms(s_eco.max)])
	print("Navigation    %-10s %-10s %-10s" % [_fmt_ms(s_nav.avg), _fmt_ms(s_nav.p95), _fmt_ms(s_nav.max)])
	print("Vegetation    %-10s %-10s %-10s" % [_fmt_ms(s_veg.avg), _fmt_ms(s_veg.p95), _fmt_ms(s_veg.max)])
	print("TOTAL         %-10s %-10s %-10s" % [_fmt_ms(s_total_cpu.avg), _fmt_ms(s_total_cpu.p95), _fmt_ms(s_total_cpu.max)])

	print("\nMAIN THREAD INTEGRATION (Sample: %d chunks)" % int_total.size())
	print("              %-10s %-10s %-10s" % ["AVG", "P95", "MAX"])
	print("Mesh          %-10s %-10s %-10s" % [_fmt_ms(s_mesh.avg), _fmt_ms(s_mesh.p95), _fmt_ms(s_mesh.max)])
	print("Collision     %-10s %-10s %-10s" % [_fmt_ms(s_col.avg), _fmt_ms(s_col.p95), _fmt_ms(s_col.max)])
	print("Vegetation    %-10s %-10s %-10s" % [_fmt_ms(s_iveg.avg), _fmt_ms(s_iveg.p95), _fmt_ms(s_iveg.max)])
	print("TOTAL         %-10s %-10s %-10s" % [_fmt_ms(s_itotal.avg), _fmt_ms(s_itotal.p95), _fmt_ms(s_itotal.max)])

	print("\nSTREAMING (%d chunk crossings)" % total_crossings)
	print("Requested:       %d" % manager.stats_requested)
	print("Generated:       %d" % manager.stats_generated)
	print("Discarded:       %d" % manager.stats_discarded)
	print("Loaded:          %d" % manager.stats_loaded)
	print("Unloaded:        %d" % manager.stats_unloaded)
	print("Peak pending:    %d" % manager.stats_peak_pending)

	print("\nCONVERGENCE")
	print("Time:            %.2f ms" % convergence_ms)

	print("\nMEMORY")
	print("Baseline:        %.2f MB" % base_mb)
	if mem_after_10 > 0:
		print("After 10 chunks: %.2f MB" % (float(mem_after_10) * to_mb))
	if mem_after_50 > 0:
		print("After 50 chunks: %.2f MB" % (float(mem_after_50) * to_mb))
	if mem_after_100 > 0:
		print("After 100 chks:  %.2f MB" % (float(mem_after_100) * to_mb))
	print("Peak:            %.2f MB" % peak_mb)
	print("Final:           %.2f MB" % final_mb)
	print("Delta:           %+.2f MB" % delta_mb)

	print("\n==================================================")
	print(" BLOQUE 9 COMPLETE")
	print("==================================================")

	quit(0)


func _calc_stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"avg": 0.0, "p95": 0.0, "max": 0.0}
	var sorted_vals := values.duplicate()
	sorted_vals.sort()
	var total := 0.0
	for v in sorted_vals:
		total += float(v)
	var avg := total / float(sorted_vals.size())
	var max_val := float(sorted_vals.back())
	var p95_idx := clampi(int(ceil(float(sorted_vals.size()) * 0.95)) - 1, 0, sorted_vals.size() - 1)
	var p95 := float(sorted_vals[p95_idx])
	return {"avg": avg, "p95": p95, "max": max_val}


func _fmt_ms(val: float) -> String:
	return "%.2f ms" % val
