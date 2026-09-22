extends SceneTree

## BLOQUE 10 — Diagnóstico Detallado y Profiling de Hotspots
## Mide y desglosa:
## 1. Hydrology: subcomponentes internos de apply_local().
## 2. Vegetation: subcomponentes internos de execute().
## 3. Main Thread: costes unitarios de integración y prueba de ráfagas (1 a 9 chunks).
## 4. Memoria y ciclo de vida de objetos: BASE -> LOAD -> UNLOAD -> SETTLED.

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkWorldScript = preload("res://src/world_generator/chunks/chunk_world.gd")
const _TerrainMeshBuilderScript = preload("res://src/world_renderer/terrain_mesh_builder.gd")
const _TerrainMaterialScript = preload("res://src/world_generator/presentation/terrain_material.gd")

func _init() -> void:
	_run_diagnostics()


func _run_diagnostics() -> void:
	print("\n==================================================")
	print(" INICIANDO DIAGNÓSTICO DETALLADO (BLOQUE 10)")
	print("==================================================")

	var seed_val := 12345
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1)

	# -------------------------------------------------------------------------
	# 1. Preparación de Hidrología Macro
	# -------------------------------------------------------------------------
	print("[1/4] Generando hidrología regional macro...")
	var shared_hydro: HydrologyResult = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	# -------------------------------------------------------------------------
	# 2. Desglose Granular de CPU: Hydrology y Vegetation (20 chunks de muestra)
	# -------------------------------------------------------------------------
	print("[2/4] Ejecutando profiling granular de Hydrology y Vegetation (20 chunks)...")
	var hydro_river: Array[float] = []
	var hydro_lake: Array[float] = []
	var hydro_banks: Array[float] = []
	var hydro_slope: Array[float] = []
	var hydro_other: Array[float] = []
	var hydro_total: Array[float] = []

	var veg_cell_iter: Array[float] = []
	var veg_sampling: Array[float] = []
	var veg_exclusion: Array[float] = []
	var veg_candidate: Array[float] = []
	var veg_poisson: Array[float] = []
	var veg_placement: Array[float] = []
	var veg_total: Array[float] = []

	var sample_chunk_data: Array[ChunkData] = []

	for i in range(20):
		var coord := Vector2i(i % 5, i / 5)
		var res: Dictionary = _WorldPipelineScript.generate_chunk_profiled(
			seed_val, coord, profile, config, shared_hydro
		)
		var c_data: ChunkData = res["chunk_data"]
		if sample_chunk_data.size() < 9:
			sample_chunk_data.append(c_data)

		var m: Dictionary = res["metrics"]
		hydro_river.append(float(m.get("hydro_river_ms", 0.0)))
		hydro_lake.append(float(m.get("hydro_lake_ms", 0.0)))
		hydro_banks.append(float(m.get("hydro_banks_ms", 0.0)))
		hydro_slope.append(float(m.get("hydro_slope_ms", 0.0)))
		hydro_other.append(float(m.get("hydro_other_ms", 0.0)))
		hydro_total.append(float(m.get("hydro_total_ms", m.get("hydrology_ms", 0.0))))

		veg_cell_iter.append(float(m.get("veg_cell_iteration_ms", 0.0)))
		veg_sampling.append(float(m.get("veg_surface_sampling_ms", 0.0)))
		veg_exclusion.append(float(m.get("veg_exclusion_queries_ms", 0.0)))
		veg_candidate.append(float(m.get("veg_candidate_collection_ms", 0.0)))
		veg_poisson.append(float(m.get("veg_poisson_thinning_ms", 0.0)))
		veg_placement.append(float(m.get("veg_final_placement_ms", 0.0)))
		veg_total.append(float(m.get("veg_total_ms", m.get("vegetation_ms", 0.0))))

	# -------------------------------------------------------------------------
	# 3. Desglose de Integración en Main Thread (Unitario + Ráfagas 1..9)
	# -------------------------------------------------------------------------
	print("[3/4] Midiendo costes unitarios en Main Thread y ráfagas (1 a 9 chunks)...")
	var mt_mesh: Array[float] = []
	var mt_collision: Array[float] = []
	var mt_materials: Array[float] = []
	var mt_vegetation: Array[float] = []
	var mt_add_child: Array[float] = []
	var mt_total: Array[float] = []

	var dummy_world: ChunkWorld = _ChunkWorldScript.new()
	root.add_child(dummy_world)
	dummy_world.initialize(seed_val, profile, config, shared_hydro)

	for c_data in sample_chunk_data:
		var origin: Vector2i = c_data.core_bounds.position
		var cell_size: float = profile.cell_size

		var chunk_view := Node3D.new()
		chunk_view.name = "DiagChunk_%d_%d" % [origin.x, origin.y]

		var t0 := Time.get_ticks_usec()
		var mesh := _TerrainMeshBuilderScript.build_mesh(c_data, cell_size, profile)
		var t1 := Time.get_ticks_usec()

		var col_shape := CollisionShape3D.new()
		col_shape.shape = mesh.create_trimesh_shape()
		var static_body := StaticBody3D.new()
		static_body.add_child(col_shape)
		chunk_view.add_child(static_body)
		var t2 := Time.get_ticks_usec()

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := _TerrainMaterialScript.create_material(profile)
		mi.set_surface_override_material(0, mat)
		chunk_view.add_child(mi)
		var t3 := Time.get_ticks_usec()

		dummy_world._spawn_chunk_vegetation(chunk_view, c_data, origin, cell_size)
		var t4 := Time.get_ticks_usec()

		dummy_world.add_child(chunk_view)
		var t5 := Time.get_ticks_usec()

		mt_mesh.append(float(t1 - t0) / 1000.0)
		mt_collision.append(float(t2 - t1) / 1000.0)
		mt_materials.append(float(t3 - t2) / 1000.0)
		mt_vegetation.append(float(t4 - t3) / 1000.0)
		mt_add_child.append(float(t5 - t4) / 1000.0)
		mt_total.append(float(t5 - t0) / 1000.0)

		chunk_view.queue_free()

	# Prueba de Ráfagas (Burst Test 1..9 chunks simultáneos en el frame)
	var burst_times: Array[float] = []
	for count in range(1, 10):
		var t_burst_start := Time.get_ticks_usec()
		var temp_views: Array[Node3D] = []

		for k in range(count):
			var c_data: ChunkData = sample_chunk_data[k]
			var origin: Vector2i = c_data.core_bounds.position
			var cell_size: float = profile.cell_size

			var cv := Node3D.new()
			var m := _TerrainMeshBuilderScript.build_mesh(c_data, cell_size, profile)
			var cs := CollisionShape3D.new()
			cs.shape = m.create_trimesh_shape()
			var sb := StaticBody3D.new()
			sb.add_child(cs)
			cv.add_child(sb)

			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.set_surface_override_material(0, _TerrainMaterialScript.create_material(profile))
			cv.add_child(mi)

			dummy_world._spawn_chunk_vegetation(cv, c_data, origin, cell_size)
			dummy_world.add_child(cv)
			temp_views.append(cv)

		var t_burst_end := Time.get_ticks_usec()
		burst_times.append(float(t_burst_end - t_burst_start) / 1000.0)

		for v in temp_views:
			v.queue_free()

	dummy_world.queue_free()

	# -------------------------------------------------------------------------
	# 4. Auditoría de Memoria y Ciclo de Vida de Objetos
	# -------------------------------------------------------------------------
	print("[4/4] Ejecutando auditoría de memoria y ciclo de vida (BASE -> LOAD -> UNLOAD -> SETTLED)...")
	_run_memory_lifetime_test(seed_val, profile, config, shared_hydro, sample_chunk_data,
		hydro_river, hydro_lake, hydro_banks, hydro_slope, hydro_other, hydro_total,
		veg_cell_iter, veg_sampling, veg_exclusion, veg_candidate, veg_poisson, veg_placement, veg_total,
		mt_mesh, mt_collision, mt_materials, mt_vegetation, mt_add_child, mt_total,
		burst_times
	)


func _run_memory_lifetime_test(
	seed_val: int,
	profile: WorldProfile,
	config: ChunkConfig,
	shared_hydro: HydrologyResult,
	sample_chunk_data: Array[ChunkData],
	hydro_river: Array[float], hydro_lake: Array[float], hydro_banks: Array[float],
	hydro_slope: Array[float], hydro_other: Array[float], hydro_total: Array[float],
	veg_cell_iter: Array[float], veg_sampling: Array[float], veg_exclusion: Array[float],
	veg_candidate: Array[float], veg_poisson: Array[float], veg_placement: Array[float], veg_total: Array[float],
	mt_mesh: Array[float], mt_collision: Array[float], mt_materials: Array[float],
	mt_vegetation: Array[float], mt_add_child: Array[float], mt_total: Array[float],
	burst_times: Array[float]
) -> void:
	# Esperar 2 frames para estabilizar el estado inicial
	await process_frame
	await process_frame

	# Punto 1: BASELINE
	var base_objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var base_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var base_res := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var base_mem := float(OS.get_static_memory_usage()) / 1048576.0

	# Punto 2: LOAD (Instanciar 9 chunks completos con ChunkWorld)
	var test_world: ChunkWorld = _ChunkWorldScript.new()
	root.add_child(test_world)
	test_world.initialize(seed_val, profile, config, shared_hydro)
	test_world.load_initial_area(Vector2i.ZERO, 1) # 9 chunks en 3x3

	await process_frame
	await process_frame

	var load_objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var load_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var load_res := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var load_mem := float(OS.get_static_memory_usage()) / 1048576.0

	# Punto 3: UNLOAD (Descargar todos los chunks)
	var empty_coords: Array[Vector2i] = []
	test_world.chunk_manager.keep_loaded(empty_coords) # descarga los 9 chunks
	var unload_objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var unload_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var unload_res := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var unload_mem := float(OS.get_static_memory_usage()) / 1048576.0

	# Punto 4: SETTLED (Esperar frames para que queue_free procese y libere)
	test_world.queue_free()
	test_world = null

	await process_frame
	await process_frame
	await process_frame

	var settled_objs := Performance.get_monitor(Performance.OBJECT_COUNT)
	var settled_nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var settled_res := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var settled_mem := float(OS.get_static_memory_usage()) / 1048576.0

	# -------------------------------------------------------------------------
	# Generar y Emitir Reporte Formateado Final
	# -------------------------------------------------------------------------
	_print_report(
		hydro_river, hydro_lake, hydro_banks, hydro_slope, hydro_other, hydro_total,
		veg_cell_iter, veg_sampling, veg_exclusion, veg_candidate, veg_poisson, veg_placement, veg_total,
		mt_mesh, mt_collision, mt_materials, mt_vegetation, mt_add_child, mt_total,
		burst_times,
		base_objs, load_objs, unload_objs, settled_objs,
		base_nodes, load_nodes, unload_nodes, settled_nodes,
		base_res, load_res, unload_res, settled_res,
		base_mem, load_mem, unload_mem, settled_mem
	)

	quit(0)


func _print_report(
	h_river: Array[float], h_lake: Array[float], h_banks: Array[float],
	h_slope: Array[float], h_other: Array[float], h_total: Array[float],
	v_iter: Array[float], v_samp: Array[float], v_excl: Array[float],
	v_cand: Array[float], v_pois: Array[float], v_plac: Array[float], v_total: Array[float],
	m_mesh: Array[float], m_col: Array[float], m_mat: Array[float],
	m_veg: Array[float], m_add: Array[float], m_total: Array[float],
	burst_times: Array[float],
	b_obj: float, l_obj: float, u_obj: float, s_obj: float,
	b_nod: float, l_nod: float, u_nod: float, s_nod: float,
	b_res: float, l_res: float, u_res: float, s_res: float,
	b_mem: float, l_mem: float, u_mem: float, s_mem: float
) -> void:
	print("\n==================================================")
	print(" BLOQUE 10 — DIAGNOSTIC PROFILE")
	print("==================================================")

	print("\nHYDROLOGY")
	print("                         AVG        P95        MAX       ")
	_print_row("River channels", h_river)
	_print_row("Lake basins", h_lake)
	_print_row("Hydraulic banks", h_banks)
	_print_row("Slope recalculation", h_slope)
	_print_row("Other", h_other)
	_print_row("TOTAL", h_total)

	print("\nVEGETATION")
	print("                         AVG        P95        MAX       ")
	_print_row("Cell iteration", v_iter)
	_print_row("Surface sampling", v_samp)
	_print_row("Exclusion queries", v_excl)
	_print_row("Candidate collection", v_cand)
	_print_row("Poisson thinning", v_pois)
	_print_row("Final placement", v_plac)
	_print_row("TOTAL", v_total)

	print("\nMAIN THREAD")
	print("                         AVG        P95        MAX       ")
	_print_row("Mesh", m_mesh)
	_print_row("Collision", m_col)
	_print_row("Materials", m_mat)
	_print_row("Vegetation scene", m_veg)
	_print_row("add_child", m_add)
	_print_row("TOTAL", m_total)

	print("\nBURST TEST")
	for i in range(burst_times.size()):
		print("%d chunk%-18s %.2f ms" % [i + 1, "s" if i > 0 else "", burst_times[i]])

	print("\nMEMORY / OBJECT LIFETIME")
	print("                         BASE      LOAD      UNLOAD    SETTLED   ")
	print("Objects                  %-9d %-9d %-9d %-9d" % [int(b_obj), int(l_obj), int(u_obj), int(s_obj)])
	print("Nodes                    %-9d %-9d %-9d %-9d" % [int(b_nod), int(l_nod), int(u_nod), int(s_nod)])
	print("Resources                %-9d %-9d %-9d %-9d" % [int(b_res), int(l_res), int(u_res), int(s_res)])
	print("Static memory            %-9.2f MB %-9.2f MB %-9.2f MB %-9.2f MB" % [b_mem, l_mem, u_mem, s_mem])

	print("==================================================\n")


func _print_row(name: String, values: Array[float]) -> void:
	if values.is_empty():
		print("%-24s 0.00 ms    0.00 ms    0.00 ms" % name)
		return

	var s: Array[float] = values.duplicate()
	s.sort()

	var sum: float = 0.0
	for v in s:
		sum += v
	var avg: float = sum / float(s.size())
	var p95_idx: int = int(ceil(float(s.size()) * 0.95)) - 1
	p95_idx = clampi(p95_idx, 0, s.size() - 1)
	var p95: float = s[p95_idx]
	var max_val: float = s[s.size() - 1]

	print("%-24s %-10s %-10s %-10s" % [
		name,
		"%.2f ms" % avg,
		"%.2f ms" % p95,
		"%.2f ms" % max_val
	])
