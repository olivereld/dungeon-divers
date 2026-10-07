extends SceneTree

const WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const ClimateStageScript = preload("res://src/world_generator/climate/climate_stage.gd")

func _init() -> void:
	print("==================================================")
	print(" Running ClimateStage Validation Test Suite (Fase 2)")
	print("==================================================")

	var profile := TaigaWorldProfile.new()
	profile.width = 64
	profile.height = 64
	var master_seed := 887766

	# 1. Ejecución del pipeline completo con ClimateStage
	var result1 := WorldPipelineScript.generate(master_seed, profile)
	assert(result1 != null, "WorldResult must not be null")
	assert(result1.has_meta(&"climate_stage_executed"), "ClimateStage must be executed in pipeline")

	# 2. Validación de rangos [0.0, 1.0]
	var min_temp: float = 1.0
	var max_temp: float = 0.0
	var min_moist: float = 1.0
	var max_moist: float = 0.0

	var low_elev_temp_sum: float = 0.0
	var low_elev_temp_count: int = 0
	var high_elev_temp_sum: float = 0.0
	var high_elev_temp_count: int = 0

	for pos in result1.cells:
		var cell: WorldCell = result1.cells[pos]
		assert(cell.temperature >= 0.0 and cell.temperature <= 1.0, "Temperature out of [0..1] range: %f" % cell.temperature)
		assert(cell.moisture >= 0.0 and cell.moisture <= 1.0, "Moisture out of [0..1] range: %f" % cell.moisture)

		min_temp = minf(min_temp, cell.temperature)
		max_temp = maxf(max_temp, cell.temperature)
		min_moist = minf(min_moist, cell.moisture)
		max_moist = maxf(max_moist, cell.moisture)

		if cell.elevation_normalized < 0.25:
			low_elev_temp_sum += cell.temperature
			low_elev_temp_count += 1
		elif cell.elevation_normalized > 0.65:
			high_elev_temp_sum += cell.temperature
			high_elev_temp_count += 1

	print(" -> [PASS] Temperature range in [%.3f, %.3f]" % [min_temp, max_temp])
	print(" -> [PASS] Moisture range in [%.3f, %.3f]" % [min_moist, max_moist])

	# 3. Validación de Lapse Rate por elevación
	if low_elev_temp_count > 0 and high_elev_temp_count > 0:
		var avg_low_temp: float = low_elev_temp_sum / float(low_elev_temp_count)
		var avg_high_temp: float = high_elev_temp_sum / float(high_elev_temp_count)
		assert(avg_high_temp < avg_low_temp, "High elevation must on average be cooler than low elevation (lapse rate)")
		print(" -> [PASS] Lapse rate verified: avg low elev temp (%.3f) > avg high elev temp (%.3f)" % [avg_low_temp, avg_high_temp])

	# 4. Determinismo estricto
	var result2 := WorldPipelineScript.generate(master_seed, profile)
	for pos in result1.cells:
		var c1: WorldCell = result1.cells[pos]
		var c2: WorldCell = result2.cells[pos]
		assert(is_equal_approx(c1.temperature, c2.temperature), "Temperature must be strictly deterministic at %s" % str(pos))
		assert(is_equal_approx(c1.moisture, c2.moisture), "Moisture must be strictly deterministic at %s" % str(pos))

	print(" -> [PASS] Strict deterministic reproducibility")

	# 5. Coherencia y continuidad en fronteras de chunks
	var chunk_config := ChunkConfig.new()
	chunk_config.chunk_size = 32
	var chunk_a := WorldPipelineScript.generate_chunk(master_seed, Vector2i(0, 0), profile, chunk_config)
	var chunk_b := WorldPipelineScript.generate_chunk(master_seed, Vector2i(1, 0), profile, chunk_config)

	# Comparar la costura (borde este de chunk A: x=31 contra borde oeste de chunk B: x=32)
	# Debido a la escala macro (frecuencia 0.0012), la diferencia entre celdas adyacentes debe ser continua y suave
	var max_diff_temp: float = 0.0
	var max_diff_moist: float = 0.0
	for y in range(32):
		var pos_a := Vector2i(31, y)
		var pos_b := Vector2i(32, y)
		var cell_a: WorldCell = chunk_a.get_cell(pos_a)
		var cell_b: WorldCell = chunk_b.get_cell(pos_b)
		if cell_a != null and cell_b != null:
			var dt: float = absf(cell_a.temperature - cell_b.temperature)
			var dm: float = absf(cell_a.moisture - cell_b.moisture)
			max_diff_temp = maxf(max_diff_temp, dt)
			max_diff_moist = maxf(max_diff_moist, dm)

	# Si las celdas están en el mismo nivel de terraza, la variación entre adyacentes es < 0.05
	assert(max_diff_temp < 0.35, "Temperature across chunk seam must be continuous, max diff: %f" % max_diff_temp)
	assert(max_diff_moist < 0.35, "Moisture across chunk seam must be continuous, max diff: %f" % max_diff_moist)
	print(" -> [PASS] Chunk seam continuity: max seam delta T=%.4f, M=%.4f" % [max_diff_temp, max_diff_moist])

	print("==================================================")
	print(" ALL CLIMATE STAGE TESTS PASSED!")
	print("==================================================")
	quit(0)
