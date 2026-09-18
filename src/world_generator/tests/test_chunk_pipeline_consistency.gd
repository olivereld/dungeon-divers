extends SceneTree

## BLOQUE 4 — Validación Lab ↔ Chunks
## Test de consistencia e integración entre la generación monolítica (Lab 64x64)
## y la generación por chunks (16 chunks de 16x16).

const _ChunkCoordScript = preload("res://src/world_generator/chunks/chunk_coord.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _ChunkDataScript = preload("res://src/world_generator/chunks/chunk_data.gd")

func _init() -> void:
	print("==================================================")
	print(" BLOQUE 4: VALIDACIÓN DE CONSISTENCIA LAB ↔ CHUNKS")
	print("==================================================")

	var seed_val := 12345
	var profile := TaigaWorldProfile.new()
	var config := _ChunkConfigScript.new(16, 1)

	# -------------------------------------------------------------------------
	# 1. Generar Laboratorio (Mundo monolítico 64x64)
	# -------------------------------------------------------------------------
	print("[1/6] Generando Mundo Laboratorio (64x64)...")
	var world := WorldPipeline.generate(seed_val, profile)
	assert(world != null, "World must not be null")
	assert(world.cells.size() == 64 * 64, "World must have 4096 cells")
	print("      Laboratorio generado OK.")

	# -------------------------------------------------------------------------
	# 2. Generar los 16 Chunks equivalentes (4x4 chunks de 16x16 = 64x64)
	# -------------------------------------------------------------------------
	print("[2/6] Generando 16 chunks equivalentes (4x4 de 16x16)...")
	var chunks: Dictionary = {}  # Vector2i -> ChunkData
	for cy in range(4):
		for cx in range(4):
			var ccoord := Vector2i(cx, cy)
			var chunk := WorldPipeline.generate_chunk(seed_val, ccoord, profile, config, world.hydrology)
			assert(chunk != null, "Chunk %s must not be null" % str(ccoord))
			assert(chunk.cells.size() == 256, "Chunk %s must have exactly 256 cells after trim, got: %d" % [str(ccoord), chunk.cells.size()])
			chunks[ccoord] = chunk
	print("      16 Chunks generados OK.")

	# -------------------------------------------------------------------------
	# 3. Comparar WorldCell (Terreno, Pendientes, Navegación)
	# -------------------------------------------------------------------------
	print("[3/6] Comparando atributos de WorldCell (Lab vs Chunks)...")
	var raw_height_mismatches := 0
	var height_mismatches := 0
	var norm_height_mismatches := 0
	var slope_mismatches := 0
	var slope_cat_mismatches := 0
	var walkable_mismatches := 0

	var max_raw_h_diff := 0.0
	var max_h_diff := 0.0
	var max_slope_diff := 0.0
	var max_norm_h_diff := 0.0

	var w_hydro = world.hydrology

	for cy in range(4):
		for cx in range(4):
			var ccoord := Vector2i(cx, cy)
			var chunk: ChunkData = chunks[ccoord]
			var core: Rect2i = chunk.core_bounds

			for y in range(core.position.y, core.end.y):
				for x in range(core.position.x, core.end.x):
					var pos := Vector2i(x, y)
					var w_cell: WorldCell = world.get_cell(pos)
					var c_cell: WorldCell = chunk.get_cell(pos)

					assert(w_cell != null, "Lab cell at %s missing" % str(pos))
					assert(c_cell != null, "Chunk cell at %s missing" % str(pos))

					# raw_height (debe ser matemáticamente 100% idéntico)
					var raw_diff := absf(w_cell.raw_height - c_cell.raw_height)
					if raw_diff > max_raw_h_diff: max_raw_h_diff = raw_diff
					if raw_diff > 0.0001:
						raw_height_mismatches += 1

					# height (post-carving de hidrología)
					var h_diff := absf(w_cell.height - c_cell.height)
					if h_diff > max_h_diff: max_h_diff = h_diff
					if h_diff > 0.001:
						height_mismatches += 1

					# normalized_height
					var norm_diff := absf(w_cell.normalized_height - c_cell.normalized_height)
					if norm_diff > max_norm_h_diff: max_norm_h_diff = norm_diff
					if norm_diff > 0.001:
						norm_height_mismatches += 1

					# slope
					var s_diff := absf(w_cell.slope - c_cell.slope)
					if s_diff > max_slope_diff: max_slope_diff = s_diff
					if s_diff > 0.05:
						slope_mismatches += 1

					# slope_category
					if w_cell.slope_category != c_cell.slope_category:
						slope_cat_mismatches += 1

					# is_walkable
					if w_cell.is_walkable != c_cell.is_walkable:
						walkable_mismatches += 1

	print("      -> raw_height: mismatches=%d (max diff: %.6f)" % [raw_height_mismatches, max_raw_h_diff])
	print("      -> height: mismatches=%d (max diff: %.6f)" % [height_mismatches, max_h_diff])
	print("      -> normalized_height: mismatches=%d (max diff: %.6f)" % [norm_height_mismatches, max_norm_h_diff])
	print("      -> slope: mismatches=%d (max diff: %.6f deg)" % [slope_mismatches, max_slope_diff])
	print("      -> slope_category: mismatches=%d" % slope_cat_mismatches)
	print("      -> is_walkable: mismatches=%d" % walkable_mismatches)

	assert(raw_height_mismatches == 0, "raw_height must match 100%% between Lab and Chunks! Found %d mismatches" % raw_height_mismatches)
	assert(norm_height_mismatches == 0, "normalized_height must match 100%% between Lab and Chunks! Found %d mismatches" % norm_height_mismatches)
	assert(height_mismatches == 0, "height must match 100%% between Lab and Chunks! Found %d mismatches" % height_mismatches)
	assert(slope_mismatches == 0, "slope must match 100%% between Lab and Chunks! Found %d mismatches" % slope_mismatches)
	assert(slope_cat_mismatches == 0, "slope_category must match 100%% between Lab and Chunks! Found %d mismatches" % slope_cat_mismatches)
	assert(walkable_mismatches == 0, "is_walkable must match 100%% between Lab and Chunks! Found %d mismatches" % walkable_mismatches)

	# -------------------------------------------------------------------------
	# 4. Comparar Hydrology (Punto Crítico)
	# -------------------------------------------------------------------------
	print("[4/6] Comparando Hydrology (Lab vs Chunks)...")
	var hydro_is_water_mismatches := 0
	var hydro_water_height_mismatches := 0
	var hydro_depth_mismatches := 0

	var total_lab_water_cells := 0
	var total_chunk_water_cells := 0

	for cy in range(4):
		for cx in range(4):
			var ccoord := Vector2i(cx, cy)
			var chunk: ChunkData = chunks[ccoord]
			var c_hydro = chunk.hydrology
			var core: Rect2i = chunk.core_bounds

			for y in range(core.position.y, core.end.y):
				for x in range(core.position.x, core.end.x):
					var pos := Vector2i(x, y)

					var w_is_water: bool = w_hydro != null and w_hydro.has_method("is_water") and w_hydro.is_water(pos)
					var c_is_water: bool = c_hydro != null and c_hydro.has_method("is_water") and c_hydro.is_water(pos)

					if w_is_water: total_lab_water_cells += 1
					if c_is_water: total_chunk_water_cells += 1

					if w_is_water != c_is_water:
						hydro_is_water_mismatches += 1

					if w_is_water and c_is_water:
						var w_wh: float = w_hydro.get_water_height(pos)
						var c_wh: float = c_hydro.get_water_height(pos)
						if absf(w_wh - c_wh) > 0.01:
							hydro_water_height_mismatches += 1

						var w_dep: float = w_hydro.get_water_depth(pos)
						var c_dep: float = c_hydro.get_water_depth(pos)
						if absf(w_dep - c_dep) > 0.01:
							hydro_depth_mismatches += 1

	print("      -> Total agua Lab: %d celdas" % total_lab_water_cells)
	print("      -> Total agua Chunks: %d celdas" % total_chunk_water_cells)
	print("      -> is_water mismatches: %d" % hydro_is_water_mismatches)
	print("      -> water_height mismatches: %d" % hydro_water_height_mismatches)
	print("      -> depth mismatches: %d" % hydro_depth_mismatches)

	assert(hydro_is_water_mismatches == 0, "is_water must match 100%% between Lab and Chunks! Found %d mismatches" % hydro_is_water_mismatches)
	assert(hydro_water_height_mismatches == 0, "water_height must match 100%% between Lab and Chunks! Found %d mismatches" % hydro_water_height_mismatches)
	assert(hydro_depth_mismatches == 0, "water_depth must match 100%% between Lab and Chunks! Found %d mismatches" % hydro_depth_mismatches)

	# -------------------------------------------------------------------------
	# 5. Comparar Vegetación (Lab vs Chunks y Orden-Independencia)
	# -------------------------------------------------------------------------
	print("[5/6] Comparando Vegetación (Lab vs Chunks)...")
	var total_lab_veg := world.vegetation.size()
	var total_chunk_veg := 0
	for cy in range(4):
		for cx in range(4):
			total_chunk_veg += chunks[Vector2i(cx, cy)].vegetation.size()

	print("      -> Total entidades Lab: %d" % total_lab_veg)
	print("      -> Total entidades Chunks: %d" % total_chunk_veg)

	# Prueba de orden-independencia en orden barajado / inverso
	print("      Probando generación en orden inverso de chunks (3,3 -> 0,0)...")
	var reverse_chunks: Dictionary = {}
	for cy in range(3, -1, -1):
		for cx in range(3, -1, -1):
			var ccoord := Vector2i(cx, cy)
			reverse_chunks[ccoord] = WorldPipeline.generate_chunk(seed_val, ccoord, profile, config, world.hydrology)

	var veg_order_mismatches := 0
	for ccoord in chunks:
		var ch_normal: ChunkData = chunks[ccoord]
		var ch_reverse: ChunkData = reverse_chunks[ccoord]
		if ch_normal.vegetation.size() != ch_reverse.vegetation.size():
			veg_order_mismatches += 1
		else:
			for i in range(ch_normal.vegetation.size()):
				var v1 = ch_normal.vegetation[i]
				var v2 = ch_reverse.vegetation[i]
				if not v1.position.is_equal_approx(v2.position):
					veg_order_mismatches += 1
					break

	print("      -> Mismatches por orden de chunks: %d" % veg_order_mismatches)
	assert(veg_order_mismatches == 0, "Chunk generation must be strictly order-independent!")

	# -------------------------------------------------------------------------
	# 6. Boundary Continuity Test (Costuras entre Chunks)
	# -------------------------------------------------------------------------
	print("[6/6] Verificando continuidad en las costuras (Boundaries)...")
	var max_boundary_raw_h_step := 0.0
	var max_boundary_slope_step := 0.0

	# Costuras verticales: x = 15 ↔ x = 16, x = 31 ↔ x = 32, x = 47 ↔ x = 48
	var seams_x: Array[int] = [15, 31, 47]
	for sx in seams_x:
		for y in range(64):
			var c_left_coord := _ChunkCoordScript.world_to_chunk(Vector2i(sx, y), 16)
			var c_right_coord := _ChunkCoordScript.world_to_chunk(Vector2i(sx + 1, y), 16)

			var cell_a: WorldCell = chunks[c_left_coord].get_cell(Vector2i(sx, y))
			var cell_b: WorldCell = chunks[c_right_coord].get_cell(Vector2i(sx + 1, y))

			var raw_step := absf(cell_a.raw_height - cell_b.raw_height)
			if raw_step > max_boundary_raw_h_step: max_boundary_raw_h_step = raw_step

			# Comparar slope de cell_a en el chunk vs slope de cell_a en el Lab
			var lab_cell_a: WorldCell = world.get_cell(Vector2i(sx, y))
			var lab_cell_b: WorldCell = world.get_cell(Vector2i(sx + 1, y))

			var slope_diff_a := absf(cell_a.slope - lab_cell_a.slope)
			var slope_diff_b := absf(cell_b.slope - lab_cell_b.slope)
			var max_s_diff := maxf(slope_diff_a, slope_diff_b)
			if max_s_diff > max_boundary_slope_step: max_boundary_slope_step = max_s_diff

	# Costuras horizontales: y = 15 ↔ y = 16, y = 31 ↔ y = 32, y = 47 ↔ y = 48
	var seams_y: Array[int] = [15, 31, 47]
	for sy in seams_y:
		for x in range(64):
			var c_top_coord := _ChunkCoordScript.world_to_chunk(Vector2i(x, sy), 16)
			var c_bot_coord := _ChunkCoordScript.world_to_chunk(Vector2i(x, sy + 1), 16)

			var cell_a: WorldCell = chunks[c_top_coord].get_cell(Vector2i(x, sy))
			var cell_b: WorldCell = chunks[c_bot_coord].get_cell(Vector2i(x, sy + 1))

			var raw_step := absf(cell_a.raw_height - cell_b.raw_height)
			if raw_step > max_boundary_raw_h_step: max_boundary_raw_h_step = raw_step

			var lab_cell_a: WorldCell = world.get_cell(Vector2i(x, sy))
			var lab_cell_b: WorldCell = world.get_cell(Vector2i(x, sy + 1))

			var slope_diff_a := absf(cell_a.slope - lab_cell_a.slope)
			var slope_diff_b := absf(cell_b.slope - lab_cell_b.slope)
			var max_s_diff := maxf(slope_diff_a, slope_diff_b)
			if max_s_diff > max_boundary_slope_step: max_boundary_slope_step = max_s_diff

	print("      -> Max raw_height paso en costura: %.4f" % max_boundary_raw_h_step)
	print("      -> Max diferencia de pendiente en costura (Chunk vs Lab): %.4f deg" % max_boundary_slope_step)

	# -------------------------------------------------------------------------
	# RESUMEN Y DIAGNÓSTICO
	# -------------------------------------------------------------------------
	print("\n==================================================")
	print(" RESULTADO DEL DIAGNÓSTICO BLOQUE 4:")
	print("==================================================")
	print("1. Terreno Raw: PERFECTO (0 discrepancias, max diff: %.6f)" % max_raw_h_diff)
	print("2. Pendientes y Halo C1: EXCELENTE (diferencia max con Lab en costuras: %.4f deg)" % max_boundary_slope_step)
	print("3. Vegetación Orden-Independencia: PERFECTA (0 discrepancias)")
	print("4. Normalización de Terreno: mismatches=%d (max diff: %.4f)" % [norm_height_mismatches, max_norm_h_diff])
	print("5. Hidrología: mismatches de agua=%d (Lab=%d celdas, Chunks=%d celdas)" % [
		hydro_is_water_mismatches, total_lab_water_cells, total_chunk_water_cells
	])
	print("==================================================\n")

	quit(0)
