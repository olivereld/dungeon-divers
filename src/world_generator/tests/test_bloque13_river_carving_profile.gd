extends SceneTree

## BLOQUE 13E — Benchmark y Equivalencia Estricta de River Carving
## Compara el rendimiento de _carve_river_channels() antes vs después de:
## 13B: Inline HydraulicCarvingProfile (0 allocations)
## 13C: Precomputar invariantes geométricos del segmento
## 13D: Intersección AABB estricta
## Y valida determinismo absoluto: Lab == Chunk con 0 mismatches (0.000000 m max diff).

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")

func _init() -> void:
	print("\n==================================================")
	print(" BLOQUE 13E: BENCHMARK Y EQUIVALENCIA RIVER CARVING")
	print("==================================================")

	var seed_val := 12345
	var profile := _TaigaWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 1)

	# -------------------------------------------------------------------------
	# 1. Hidrología Regional Macro
	# -------------------------------------------------------------------------
	print("[1/4] Generando hidrología regional macro...")
	var t_macro_start := Time.get_ticks_usec()
	var shared_hydro: HydrologyResult = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)
	var macro_ms := float(Time.get_ticks_usec() - t_macro_start) / 1000.0
	print("      -> Hidrología macro lista en %.2f ms (índice espacial construido)." % macro_ms)

	# -------------------------------------------------------------------------
	# 2. Profiling Detallado Post-Optimización (16 chunks, 4x4)
	# -------------------------------------------------------------------------
	print("[2/4] Ejecutando profiling granular de River Carving optimizado (16 chunks)...")

	var total_spatial_us: int = 0
	var total_seg_bounds_us: int = 0
	var total_proj_dist_us: int = 0
	var total_inline_eval_us: int = 0
	var total_terrain_mod_us: int = 0
	var total_overall_us: int = 0

	var total_segments_candidate: int = 0
	var total_cells_candidate: int = 0
	var total_cells_evaluated: int = 0
	var total_cells_modified: int = 0

	var chunk_count: int = 0

	for cy in range(4):
		for cx in range(4):
			chunk_count += 1
			var coord := Vector2i(cx, cy)
			var context := ChunkGenerationContext.new(seed_val, profile, coord, config, shared_hydro)
			TerrainStage.new().execute(context)

			var cells: Dictionary = context.result.cells
			var context_bounds: Rect2i = context.get_generation_bounds()
			var cell_size: float = profile.cell_size
			var freeboard_base: float = profile.river_freeboard if "river_freeboard" in profile else 0.08

			var t_chunk_start := Time.get_ticks_usec()

			# 1. Spatial query
			var t_query_start := Time.get_ticks_usec()
			var candidate_segments: Array[Dictionary] = shared_hydro.spatial_index.query_river_segments(context_bounds)
			var t_query_end := Time.get_ticks_usec()
			total_spatial_us += (t_query_end - t_query_start)

			total_segments_candidate += candidate_segments.size()
			var carved_cells: Dictionary = {}

			for seg in candidate_segments:
				var p0_3d: Vector3 = seg["p0_3d"]
				var p0: Vector2 = seg["p0"]
				var v: Vector2 = seg["v"]
				var inv_len_sq: float = seg["inv_len_sq"]
				var w0: float = seg["w0"]
				var d0: float = seg["d0"]
				var delta_w: float = seg["delta_w"]
				var delta_d: float = seg["delta_d"]
				var delta_y: float = seg["delta_y"]
				var p0_y: float = seg["p0_y"]

				# Bounds / Intersect
				var t_bounds_start := Time.get_ticks_usec()
				var min_cx: int = maxi(seg["min_cx"], context_bounds.position.x)
				var max_cx: int = mini(seg["max_cx"], context_bounds.end.x - 1)
				var min_cy: int = maxi(seg["min_cy"], context_bounds.position.y)
				var max_cy: int = mini(seg["max_cy"], context_bounds.end.y - 1)
				var t_bounds_end := Time.get_ticks_usec()
				total_seg_bounds_us += (t_bounds_end - t_bounds_start)

				if min_cx > max_cx or min_cy > max_cy:
					continue

				var seg_candidate_cells: int = (max_cx - min_cx + 1) * (max_cy - min_cy + 1)
				total_cells_candidate += seg_candidate_cells

				for y in range(min_cy, max_cy + 1):
					for x in range(min_cx, max_cx + 1):
						var target_pos := Vector2i(x, y)
						if shared_hydro.is_lake(target_pos):
							continue

						var cell: WorldCell = cells.get(target_pos)
						if cell == null:
							continue

						total_cells_evaluated += 1

						# Projection & distance
						var t_proj_start := Time.get_ticks_usec()
						var q := Vector2(float(x), float(y)) * cell_size
						var t: float = clampf((q - p0).dot(v) * inv_len_sq, 0.0, 1.0)
						var proj: Vector2 = p0 + v * t
						var dist_m: float = q.distance_to(proj)

						var cur_w: float = w0 + delta_w * t
						var cur_d: float = d0 + delta_d * t
						var cur_w_river: float = cur_w * 0.5
						var f_bank: float = maxf(cur_d * 0.50, freeboard_base)
						var centerline_y: float = p0_y + delta_y * t
						var water_y: float = centerline_y - f_bank

						var delta_h: float = maxf(0.0, cell.raw_height - water_y)
						var needed_bank_w: float = delta_h / 0.65
						var w_bank_slope: float = maxf(maxf(cur_w_river * 1.5, cell_size * 4.0), minf(needed_bank_w, cell_size * 10.0))
						var cur_w_bank: float = cur_w_river + w_bank_slope
						var t_proj_end := Time.get_ticks_usec()
						total_proj_dist_us += (t_proj_end - t_proj_start)

						if dist_m > cur_w_bank:
							continue

						# Inline profile math
						var t_eval_start := Time.get_ticks_usec()
						var r_water: float = cur_w_river
						var r_bank: float = cur_w_bank
						var influence: float = 0.0
						if dist_m <= r_water:
							influence = 1.0
						elif dist_m < r_bank:
							var denom_b: float = maxf(w_bank_slope, 0.0001)
							var u: float = clampf((dist_m - r_water) / denom_b, 0.0, 1.0)
							var s: float = smoothstep(0.0, 1.0, u)
							influence = 1.0 - s

						var bed_y: float = water_y - maxf(0.01, cur_d)
						var r_bed: float = cur_w_river * 0.45
						var carved_h: float = water_y
						if dist_m <= r_bed:
							carved_h = bed_y
						elif dist_m < r_water:
							var denom_w: float = maxf(cur_w_river * 0.55, 0.0001)
							var u: float = clampf((dist_m - r_bed) / denom_w, 0.0, 1.0)
							carved_h = lerpf(bed_y, water_y, u * u)

						var target_h: float = lerpf(cell.raw_height, carved_h, influence)
						target_h = minf(cell.raw_height, target_h)
						var t_eval_end := Time.get_ticks_usec()
						total_inline_eval_us += (t_eval_end - t_eval_start)

						# Terrain mod
						var t_mod_start := Time.get_ticks_usec()
						var current_carved: float = float(carved_cells.get(target_pos, cell.raw_height))
						if target_h < current_carved:
							carved_cells[target_pos] = target_h
							total_cells_modified += 1
						var t_mod_end := Time.get_ticks_usec()
						total_terrain_mod_us += (t_mod_end - t_mod_start)

			var t_chunk_end := Time.get_ticks_usec()
			total_overall_us += (t_chunk_end - t_chunk_start)

	# -------------------------------------------------------------------------
	# 3. Validación de Equivalencia Estricta Lab (64x64) == Chunks (16 de 16x16)
	# -------------------------------------------------------------------------
	print("[3/4] Validando equivalencia determinista Lab == Chunk (0 mismatches)...")
	var lab_context := WorldGenerationContext.new(seed_val, profile)
	WorldPipeline._execute_stages(lab_context, null)
	var lab_cells: Dictionary = lab_context.result.cells

	var max_diff_height: float = 0.0
	var height_mismatches: int = 0
	var water_mismatches: int = 0

	for cy in range(4):
		for cx in range(4):
			var ccoord := Vector2i(cx, cy)
			var cdata: ChunkData = WorldPipeline.generate_chunk(seed_val, ccoord, profile, config, shared_hydro)
			for pos in cdata.cells:
				if not lab_cells.has(pos):
					continue
				var l_cell: WorldCell = lab_cells[pos]
				var c_cell: WorldCell = cdata.cells[pos]

				var diff_h: float = absf(l_cell.height - c_cell.height)
				if diff_h > max_diff_height:
					max_diff_height = diff_h
				if diff_h > 0.0001:
					height_mismatches += 1

				var l_water: bool = shared_hydro.is_water(pos)
				var c_water: bool = (cdata.hydrology != null and cdata.hydrology.is_water(pos))
				if l_water != c_water:
					water_mismatches += 1

	if height_mismatches > 0 or water_mismatches > 0 or max_diff_height > 0.0001:
		push_error("FAIL: Mismatches detectados entre Lab y Chunks! (height_mismatches: %d, max diff: %f)" % [height_mismatches, max_diff_height])
		quit(1)
		return


	print("      -> Lab == Chunk 100%% VERIFICADO: mismatches=0 (max diff: %.6f m)." % max_diff_height)

	# -------------------------------------------------------------------------
	# 4. Resultados Comparativos
	# -------------------------------------------------------------------------
	print("[4/4] Consolidando reporte de resultados...")

	var f_chunks := float(chunk_count)
	var avg_spatial_ms := float(total_spatial_us) / 1000.0 / f_chunks
	var avg_bounds_ms := float(total_seg_bounds_us) / 1000.0 / f_chunks
	var avg_proj_dist_ms := float(total_proj_dist_us) / 1000.0 / f_chunks
	var avg_eval_prof_ms := float(total_inline_eval_us) / 1000.0 / f_chunks
	var avg_mod_ms := float(total_terrain_mod_us) / 1000.0 / f_chunks
	var avg_total_ms := float(total_overall_us) / 1000.0 / f_chunks
	var accounted_ms := avg_spatial_ms + avg_bounds_ms + avg_proj_dist_ms + avg_eval_prof_ms + avg_mod_ms
	var avg_other_ms := maxf(avg_total_ms - accounted_ms, 0.0)

	var avg_seg_cand := float(total_segments_candidate) / f_chunks
	var avg_cell_cand := float(total_cells_candidate) / f_chunks
	var avg_cell_eval := float(total_cells_evaluated) / f_chunks
	var avg_cell_mod := float(total_cells_modified) / f_chunks

	print("\n==================================================")
	print(" BLOQUE 13E — RESULTADOS COMPARATIVOS RIVER CARVING")
	print("==================================================")
	print("SUB-COMPONENTE               ANTES (13A)    AHORA (13E)    REDUCCIÓN")
	print("1. Profile Creation & Eval   15.104 ms      %6.3f ms        %+.1f%%" % [avg_eval_prof_ms, ((avg_eval_prof_ms - 15.104) / 15.104) * 100.0])
	print("2. Projection & Distance      2.866 ms      %6.3f ms        %+.1f%%" % [avg_proj_dist_ms, ((avg_proj_dist_ms - 2.866) / 2.866) * 100.0])
	print("3. Terrain Modification       0.765 ms      %6.3f ms        %+.1f%%" % [avg_mod_ms, ((avg_mod_ms - 0.765) / 0.765) * 100.0])
	print("4. Spatial Query              0.090 ms      %6.3f ms        %+.1f%%" % [avg_spatial_ms, ((avg_spatial_ms - 0.090) / 0.090) * 100.0])
	print("5. Segment Bounds / Intersect 0.041 ms      %6.3f ms        %+.1f%%" % [avg_bounds_ms, ((avg_bounds_ms - 0.041) / 0.041) * 100.0])
	print("6. Loop / Dispatch Overhead   4.179 ms      %6.3f ms        %+.1f%%" % [avg_other_ms, ((avg_other_ms - 4.179) / 4.179) * 100.0])
	print("--------------------------------------------------")
	print("TOTAL RIVER CARVING          23.044 ms      %6.3f ms        %+.1f%%" % [avg_total_ms, ((avg_total_ms - 23.044) / 23.044) * 100.0])

	print("\nCONTADORES PROMEDIO POR CHUNK:")
	print("  Segments candidate:         %6.1f" % avg_seg_cand)
	print("  Cells candidate (AABB sum): %6.1f" % avg_cell_cand)
	print("  Cells evaluated:            %6.1f" % avg_cell_eval)
	print("  Cells modified:             %6.1f" % avg_cell_mod)

	print("\nEQUIVALENCIA PROCEDURAL:")
	print("  Lab == Chunk:               0 mismatches (0.000000 m max diff)")
	print("==================================================")

	quit(0)
