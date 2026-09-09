extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(54321, profile)
	TerrainStage.new().execute(context)
	EcologyStage.new().execute(context)

	var cell := context.result.get_cell(Vector2i(50, 50))
	assert(cell.forest_density >= 0.0 and cell.forest_density <= 1.0)
	assert(cell.clearing_density >= 0.0 and cell.clearing_density <= 1.0)
	assert(cell.moisture >= 0.0 and cell.moisture <= 1.0)

	print("test_ecology_stage: OK")
	quit()
