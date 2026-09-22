extends SceneTree

func _init() -> void:
	var profile := WorldProfile.new()
	profile.width = 128
	profile.height = 128
	var result := WorldPipeline.generate(12345, profile)
	assert(result != null, "WorldResult must not be null")
	assert(result.dimensions == Vector2i(128, 128), "Dimensions must match profile")
	assert(result.master_seed == 12345, "Master seed must match")
	assert(result.cells.size() == 128 * 128, "Cell count must match width * height")

	# Verificación de contrato de elevación en WorldCell
	for pos in result.cells:
		var cell: WorldCell = result.cells[pos]
		assert(typeof(cell.elevation_level) == TYPE_INT, "elevation_level must be int")
		assert(typeof(cell.raw_height) == TYPE_FLOAT, "raw_height must be float")
		assert(typeof(cell.height) == TYPE_FLOAT, "height must be float")
		assert(is_finite(cell.height), "cell.height must be finite")
		assert(is_finite(cell.raw_height), "cell.raw_height must be finite")
		assert(cell.elevation_level >= profile.elevation_min_level and cell.elevation_level <= profile.elevation_max_level,
			"elevation_level must respect profile bounds")

	print("test_world_contracts: OK (WorldCell elevation authority contract verified)")
	quit()
