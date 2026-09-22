extends SceneTree

func _init() -> void:
	var pipeline := WorldPipeline.new()
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(12345, profile)

	TerrainStage.new().execute(context)
	var stage_diffs_terrain := 0
	for pos in context.result.cells:
		var c: WorldCell = context.result.cells[pos]
		var nc: WorldCell = context.result.get_cell(pos + Vector2i(1, 0))
		if nc != null and c.elevation_level == nc.elevation_level and not is_equal_approx(c.height, nc.height):
			stage_diffs_terrain += 1
	print("After TerrainStage: same level height diffs = %d" % stage_diffs_terrain)

	# Now run HydrologyStage
	var hydro_stage := HydrologyStage.new()
	hydro_stage.execute(context)
	var stage_diffs_hydro := 0
	for pos in context.result.cells:
		var c: WorldCell = context.result.cells[pos]
		var nc: WorldCell = context.result.get_cell(pos + Vector2i(1, 0))
		if nc != null and c.elevation_level == nc.elevation_level and not is_equal_approx(c.height, nc.height):
			stage_diffs_hydro += 1
	print("After HydrologyStage: same level height diffs = %d" % stage_diffs_hydro)

	quit()
