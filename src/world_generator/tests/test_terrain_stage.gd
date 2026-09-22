extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(12345, profile)
	var stage := TerrainStage.new()
	stage.execute(context)

	var cell_00 := context.result.get_cell(Vector2i(0, 0))
	assert(cell_00 != null)
	assert(not is_nan(cell_00.height))
	assert(cell_00.slope >= 0.0 and cell_00.slope <= 90.0)

	# Verificación de contrato de elevación escalonada en todas las celdas
	var levels_found := {}
	for pos in context.result.cells:
		var cell: WorldCell = context.result.cells[pos]
		assert(cell.elevation_level >= profile.min_elevation_level and cell.elevation_level <= profile.max_elevation_level,
			"elevation_level must be within [min, max] limits at %s" % str(pos))
		levels_found[cell.elevation_level] = true

		var expected_height: float = profile.base_height + float(cell.elevation_level) * profile.elevation_step_height
		assert(is_equal_approx(cell.height, expected_height),
			"cell.height must strictly equal base_height + level * step_height at %s" % str(pos))
		assert(cell.height <= cell.raw_height + 0.0001,
			"cell.height must be <= raw_height (quantized downward via floor) at %s" % str(pos))
		assert(cell.raw_height >= profile.base_height - 0.0001,
			"raw_height should be >= base_height at %s" % str(pos))
		assert(cell.normalized_height >= 0.0 and cell.normalized_height <= 1.0,
			"normalized_height must be within [0.0, 1.0] at %s" % str(pos))

		# Slope escalonado: únicamente 0.0 (plano) o 90.0 (cliff)
		assert(is_equal_approx(cell.slope, 0.0) or is_equal_approx(cell.slope, 90.0),
			"Slope must be either 0.0 (plateau) or 90.0 (cliff), got %f at %s" % [cell.slope, str(pos)])

	assert(levels_found.size() > 1, "Terrain must contain multiple elevation levels across map")

	# Verificación de coherencia de terrazas (Macro+Medium sin ruido de detalle celda a celda)
	var same_level_edges := 0
	var total_edges := 0
	for pos in context.result.cells:
		var cell: WorldCell = context.result.cells[pos]
		var right_cell: WorldCell = context.result.get_cell(pos + Vector2i(1, 0))
		if right_cell != null:
			total_edges += 1
			if cell.elevation_level == right_cell.elevation_level:
				same_level_edges += 1
		var down_cell: WorldCell = context.result.get_cell(pos + Vector2i(0, 1))
		if down_cell != null:
			total_edges += 1
			if cell.elevation_level == down_cell.elevation_level:
				same_level_edges += 1

	var plateau_coherence: float = float(same_level_edges) / float(max(total_edges, 1))
	assert(plateau_coherence >= 0.75, "Plateau coherence must be high (>= 75%% same-level edges): got %.2f%%" % [plateau_coherence * 100.0])

	# Determinism check
	var context2 := WorldGenerationContext.new(12345, profile)
	stage.execute(context2)
	var cell_00_b := context2.result.get_cell(Vector2i(0, 0))
	assert(cell_00.height == cell_00_b.height, "Heights must be strictly deterministic")
	assert(cell_00.raw_height == cell_00_b.raw_height, "Raw heights must be strictly deterministic")
	assert(cell_00.elevation_level == cell_00_b.elevation_level, "Elevation levels must be strictly deterministic")
	assert(cell_00.slope == cell_00_b.slope, "Slopes must be strictly deterministic")

	# Verificación de calibración rápida desde el perfil (sin tocar TerrainStage)
	var custom_profile := TaigaWorldProfile.new()
	custom_profile.elevation_step_height = 4.0
	custom_profile.elevation_level_count = 3
	custom_profile.elevation_min_level = 0
	custom_profile.elevation_max_level = 2
	var custom_context := WorldGenerationContext.new(99999, custom_profile)
	stage.execute(custom_context)

	for pos in custom_context.result.cells:
		var c: WorldCell = custom_context.result.cells[pos]
		assert(c.elevation_level >= 0 and c.elevation_level <= 2,
			"Custom level must be within [0, 2]")
		var expected: float = custom_profile.base_height + float(c.elevation_level) * 4.0
		assert(is_equal_approx(c.height, expected), "Custom height must adapt to step_height=4.0")

	print("test_terrain_stage: OK (stepped elevation contract verified, %d levels found, plateau coherence: %.1f%%, custom profile calibration verified)" % [levels_found.size(), plateau_coherence * 100.0])
	quit()

