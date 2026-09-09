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

	# Determinism check
	var context2 := WorldGenerationContext.new(12345, profile)
	stage.execute(context2)
	var cell_00_b := context2.result.get_cell(Vector2i(0, 0))
	assert(cell_00.height == cell_00_b.height, "Heights must be strictly deterministic")
	assert(cell_00.slope == cell_00_b.slope, "Slopes must be strictly deterministic")

	print("test_terrain_stage: OK")
	quit()
