extends SceneTree

## BLOQUE 12 — Reprofiling Global + Scheduling Benchmark
## Mide con precisión microsegundo:
## 1. Distribución CPU por etapa post-Bloque 11 (Terrain, Hydrology, Ecology, Nav, Vegetation).
## 2. Métricas de Scheduling (tiempo en cola, tiempo de generación, latencia request->loaded, pending peak, descartes).
## 3. Integración en Main Thread (Mesh, Collision, Vegetation).
## 4. Streaming bajo movimiento continuo (>100 cruces).
## 5. Comparativa directa contra Bloque 10/11 para aislar el siguiente hotspot.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkWorldIntegrationScript = preload("res://src/world_generator/scenes/chunk_world_integration.gd")

func _init() -> void:
	print("\n==================================================")
	print(" BLOQUE 12: REPROFILING GLOBAL + SCHEDULING")
	print("==================================================")

	var seed_val := 12345
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1)

	# -------------------------------------------------------------------------
	# 1. Hidrología Regional Macro
	# -------------------------------------------------------------------------
	print("[1/5] Generando hidrología regional macro...")
	var t_macro_start := Time.get_ticks_usec()
	var shared_hydro: HydrologyResult = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	var t_macro_end := Time.get_ticks_usec()
	var macro_ms := float(t_macro_end - t_macro_start) / 1000.0
	print("      -> Hidrología macro lista en %.2f ms" % macro_ms)

	# -------------------------------------------------------------------------
	# 2. Distribución CPU por Etapa (Muestra representativa de 16 chunks, 4x4)
	# -------------------------------------------------------------------------
	print("[2/5] Profiling de CPU por etapa (16 chunks representativos)...")
	var cpu_terrain: Array[float] = []
	var cpu_hydro: Array[float] = []
	var cpu_eco: Array[float] = []
	var cpu_nav: Array[float] = []
	var cpu_veg: Array[float] = []
	var cpu_total: Array[float] = []

	for cy in range(4):
		for cx in range(4):
			var coord := Vector2i(cx, cy)
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

	# -------------------------------------------------------------------------
	# 3. Inicializar Escena de Streaming y Movimiento Continuo Real
	# -------------------------------------------------------------------------
	print("[3/5] Ejecutando simulación de streaming continuo con worker async (>100 cruces)...")
	var scene = _ChunkWorldIntegrationScript.new()
	scene.world_seed = seed_val
	root.add_child(scene)
	if scene.chunk_world == null:
		scene._ready()

	var world: ChunkWorld = scene.chunk_world
	var player: CharacterBody3D = scene.player
	var manager: WorldChunkManager = world.chunk_manager

	# Resetear métricas para medir estrictamente el recorrido continuo
	manager.reset_stats()
	world.integration_timings.clear()

	var total_crossings := 0

	# 3.1 Movimiento continuo a lo largo del eje X (50 cruces)
	for step in range(1, 55):
		player.position = Vector3(float(step) * 16.0 + 8.0, 20.0, 8.0)
		world.update_player_streaming()
		world.flush_async_queue()
		total_crossings += 1

	# 3.2 Movimiento continuo a lo largo del eje Z (55 cruces)
	for step in range(1, 56):
		player.position = Vector3(player.position.x, 20.0, float(step) * 16.0 + 8.0)
		world.update_player_streaming()
		world.flush_async_queue()
		total_crossings += 1

	print("      -> Recorrido completado con éxito: %d cruces de chunks." % total_crossings)

	# -------------------------------------------------------------------------
	# 4. Medición de Ráfagas (Turnarounds rápidos) para descartes por token
	# -------------------------------------------------------------------------
	print("[4/5] Evaluando ráfagas y descartes por cambio de trayectoria...")
	player.position = Vector3(5000.0, 20.0, 5000.0)
	world.update_player_streaming()
	player.position = Vector3(-3000.0, 20.0, -3000.0)
	world.update_player_streaming()
	player.position = Vector3(1000.0, 20.0, 1000.0)
	world.update_player_streaming()
	world.flush_async_queue()

	# -------------------------------------------------------------------------
	# 5. Cálculo y Presentación de Estadísticas
	# -------------------------------------------------------------------------
	print("[5/5] Consolidando telemetría de CPU, Main Thread y Scheduling...")

	var s_terrain := _calc_stats(cpu_terrain)
	var s_hydro := _calc_stats(cpu_hydro)
	var s_eco := _calc_stats(cpu_eco)
	var s_nav := _calc_stats(cpu_nav)
	var s_veg := _calc_stats(cpu_veg)
	var s_total_cpu := _calc_stats(cpu_total)

	var s_queue := _calc_stats(manager.stats_queue_times)
	var s_worker_gen := _calc_stats(manager.stats_gen_times)
	var s_latency := _calc_stats(manager.stats_latencies)

	# Main Thread Integration
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

	# Imprimir Reporte Completo
	print("\n==================================================")
	print(" BLOQUE 12: REPROFILING GLOBAL & SCHEDULING")
	print("==================================================")

	print("\n1. DISTRIBUCIÓN CPU POR ETAPA (Sample: 16 chunks)")
	print("STAGE            AVG        P95        MAX        % TOTAL")
	print("Terrain          %6.2f ms  %6.2f ms  %6.2f ms   %5.1f%%" % [s_terrain["avg"], s_terrain["p95"], s_terrain["max"], (s_terrain["avg"] / s_total_cpu["avg"]) * 100.0])
	print("Hydrology        %6.2f ms  %6.2f ms  %6.2f ms   %5.1f%%" % [s_hydro["avg"], s_hydro["p95"], s_hydro["max"], (s_hydro["avg"] / s_total_cpu["avg"]) * 100.0])
	print("Ecology          %6.2f ms  %6.2f ms  %6.2f ms   %5.1f%%" % [s_eco["avg"], s_eco["p95"], s_eco["max"], (s_eco["avg"] / s_total_cpu["avg"]) * 100.0])
	print("Navigation       %6.2f ms  %6.2f ms  %6.2f ms   %5.1f%%" % [s_nav["avg"], s_nav["p95"], s_nav["max"], (s_nav["avg"] / s_total_cpu["avg"]) * 100.0])
	print("Vegetation       %6.2f ms  %6.2f ms  %6.2f ms   %5.1f%%" % [s_veg["avg"], s_veg["p95"], s_veg["max"], (s_veg["avg"] / s_total_cpu["avg"]) * 100.0])
	print("--------------------------------------------------")
	print("TOTAL WORKER     %6.2f ms  %6.2f ms  %6.2f ms   100.0%%" % [s_total_cpu["avg"], s_total_cpu["p95"], s_total_cpu["max"]])

	print("\n2. SCHEDULING Y LATENCIA (Sample: %d chunks cargados)" % manager.stats_loaded)
	print("MÉTRICA                     AVG        P95        MAX")
	print("Tiempo en cola (Queue)      %6.2f ms  %6.2f ms  %6.2f ms" % [s_queue["avg"], s_queue["p95"], s_queue["max"]])
	print("Generación efectiva (Gen)   %6.2f ms  %6.2f ms  %6.2f ms" % [s_worker_gen["avg"], s_worker_gen["p95"], s_worker_gen["max"]])
	print("Latencia request -> loaded  %6.2f ms  %6.2f ms  %6.2f ms" % [s_latency["avg"], s_latency["p95"], s_latency["max"]])
	print("Pending peak:               %d chunks" % manager.stats_peak_pending)
	print("Chunks solicitados:         %d" % manager.stats_requested)
	print("Chunks completados worker:  %d" % manager.stats_generated)
	print("Chunks descartados token:   %d" % manager.stats_discarded)
	print("Chunks cargados e integr.:  %d" % manager.stats_loaded)
	print("Chunks descargados:         %d" % manager.stats_unloaded)

	print("\n3. INTEGRACIÓN MAIN THREAD (Sample: %d chunks)" % int_total.size())
	print("COMPONENTE       AVG        P95        MAX")
	print("Mesh             %6.2f ms  %6.2f ms  %6.2f ms" % [s_mesh["avg"], s_mesh["p95"], s_mesh["max"]])
	print("Collision        %6.2f ms  %6.2f ms  %6.2f ms" % [s_col["avg"], s_col["p95"], s_col["max"]])
	print("Vegetation       %6.2f ms  %6.2f ms  %6.2f ms" % [s_iveg["avg"], s_iveg["p95"], s_iveg["max"]])
	print("--------------------------------------------------")
	print("TOTAL MAIN       %6.2f ms  %6.2f ms  %6.2f ms" % [s_itotal["avg"], s_itotal["p95"], s_itotal["max"]])

	print("\n==================================================")
	print(" COMPARATIVA: EVOLUCIÓN BLOQUE 9 -> 11 -> 12")
	print("==================================================")
	print("MÉTRICA            BLOQUE 9     BLOQUE 11/12   VARIACIÓN")
	print("Hydrology AVG      32.39 ms     %6.2f ms       %+.1f%%" % [s_hydro["avg"], ((s_hydro["avg"] - 32.39) / 32.39) * 100.0])
	print("Vegetation AVG     15.65 ms     %6.2f ms       %+.1f%%" % [s_veg["avg"], ((s_veg["avg"] - 15.65) / 15.65) * 100.0])
	print("Total CPU AVG      50.99 ms     %6.2f ms       %+.1f%%" % [s_total_cpu["avg"], ((s_total_cpu["avg"] - 50.99) / 50.99) * 100.0])
	print("Main Thread AVG     2.64 ms     %6.2f ms       %+.1f%%" % [s_itotal["avg"], ((s_itotal["avg"] - 2.64) / 2.64) * 100.0])
	print("==================================================")

	scene.queue_free()
	quit(0)


func _calc_stats(arr: Array[float]) -> Dictionary:
	if arr.is_empty():
		return {"avg": 0.0, "p95": 0.0, "max": 0.0}

	var sorted: Array[float] = arr.duplicate()
	sorted.sort()

	var sum: float = 0.0
	var max_val: float = sorted[sorted.size() - 1]
	for val in sorted:
		sum += val

	var avg: float = sum / float(sorted.size())
	var p95_idx: int = int(floor(float(sorted.size() - 1) * 0.95))
	var p95_val: float = sorted[p95_idx]

	return {
		"avg": avg,
		"p95": p95_val,
		"max": max_val
	}

