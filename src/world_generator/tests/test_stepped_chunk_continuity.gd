extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Testing Spatial Continuity Between Chunks (Paso 10)")
	print("==================================================")

	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new()
	var seed_val := 777

	# -------------------------------------------------------------------------
	# 1. Continuidad en costura horizontal (Chunk 0,0 vs Chunk 1,0 en X = 16)
	# -------------------------------------------------------------------------
	print("1. Validando frontera Este/Oeste (Chunk 0,0 ↔ Chunk 1,0)...")
	var chunk_0_0: ChunkData = WorldPipeline.generate_chunk(seed_val, Vector2i(0, 0), profile, config)
	var chunk_1_0: ChunkData = WorldPipeline.generate_chunk(seed_val, Vector2i(1, 0), profile, config)

	var seam_tested_x := 0
	for y in range(16):
		var pos := Vector2i(16, y)
		var cell_a: WorldCell = chunk_0_0.get_cell_or_seam(pos)
		var cell_b: WorldCell = chunk_1_0.get_cell_or_seam(pos)

		assert(cell_a != null, "Chunk 0,0 debe conservar la celda de costura en %s" % str(pos))
		assert(cell_b != null, "Chunk 1,0 debe poseer la celda en %s" % str(pos))

		assert(cell_a.elevation_level == cell_b.elevation_level,
			"VIOLACIÓN DE CONTINUIDAD: elevation_level difiere en costura %s: Chunk(0,0)=%d vs Chunk(1,0)=%d" % [
				str(pos), cell_a.elevation_level, cell_b.elevation_level
			])
		assert(is_equal_approx(cell_a.raw_height, cell_b.raw_height),
			"VIOLACIÓN DE DETERMINISMO: raw_height difiere en costura %s: %.4f vs %.4f" % [
				str(pos), cell_a.raw_height, cell_b.raw_height
			])
		assert(is_equal_approx(cell_a.height, cell_b.height),
			"VIOLACIÓN DE ALTURA: height difiere en costura %s: %.4f vs %.4f" % [
				str(pos), cell_a.height, cell_b.height
			])
		seam_tested_x += 1

	print("   -> OK: %d celdas de costura X verificadas con 100%% igualdad en elevation_level, raw_height y height." % seam_tested_x)

	# -------------------------------------------------------------------------
	# 2. Continuidad en costura vertical (Chunk 0,0 vs Chunk 0,1 en Y = 16)
	# -------------------------------------------------------------------------
	print("2. Validando frontera Norte/Sur (Chunk 0,0 ↔ Chunk 0,1)...")
	var chunk_0_1: ChunkData = WorldPipeline.generate_chunk(seed_val, Vector2i(0, 1), profile, config)

	var seam_tested_y := 0
	for x in range(16):
		var pos := Vector2i(x, 16)
		var cell_a: WorldCell = chunk_0_0.get_cell_or_seam(pos)
		var cell_b: WorldCell = chunk_0_1.get_cell_or_seam(pos)

		assert(cell_a != null, "Chunk 0,0 debe conservar la celda de costura en %s" % str(pos))
		assert(cell_b != null, "Chunk 0,1 debe poseer la celda en %s" % str(pos))

		assert(cell_a.elevation_level == cell_b.elevation_level,
			"VIOLACIÓN DE CONTINUIDAD: elevation_level difiere en costura %s: Chunk(0,0)=%d vs Chunk(0,1)=%d" % [
				str(pos), cell_a.elevation_level, cell_b.elevation_level
			])
		assert(is_equal_approx(cell_a.raw_height, cell_b.raw_height),
			"VIOLACIÓN DE DETERMINISMO: raw_height difiere en costura %s: %.4f vs %.4f" % [
				str(pos), cell_a.raw_height, cell_b.raw_height
			])
		assert(is_equal_approx(cell_a.height, cell_b.height),
			"VIOLACIÓN DE ALTURA: height difiere en costura %s: %.4f vs %.4f" % [
				str(pos), cell_a.height, cell_b.height
			])
		seam_tested_y += 1

	print("   -> OK: %d celdas de costura Y verificadas con 100%% igualdad en elevation_level, raw_height y height." % seam_tested_y)

	# -------------------------------------------------------------------------
	# 3. Independencia de extremos locales: Chunk aislado vs Macro World
	# -------------------------------------------------------------------------
	print("3. Validando que elevation_level no depende de min/max locales del chunk vs macro mundo...")
	var macro_result := WorldPipeline.generate(seed_val, profile)

	var match_count := 0
	for y in range(16):
		for x in range(16):
			var pos := Vector2i(x, y)
			var c_chunk: WorldCell = chunk_0_0.get_cell(pos)
			var c_macro: WorldCell = macro_result.get_cell(pos)
			assert(c_chunk != null and c_macro != null)
			assert(c_chunk.elevation_level == c_macro.elevation_level,
				"elevation_level debe ser idéntico en chunk vs macro: pos %s: chunk=%d, macro=%d" % [
					str(pos), c_chunk.elevation_level, c_macro.elevation_level
				])
			assert(is_equal_approx(c_chunk.raw_height, c_macro.raw_height),
				"raw_height debe ser idéntico en chunk vs macro: pos %s" % str(pos))
			match_count += 1

	print("   -> OK: %d celdas de Chunk(0,0) coinciden 100%% con Macro World." % match_count)

	print("==================================================")
	print(" ALL SPATIAL CONTINUITY TESTS PASSED!")
	print("==================================================")
	quit()
