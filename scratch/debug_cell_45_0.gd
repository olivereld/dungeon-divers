extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var seed_val: int = 12345
	var context := WorldGenerationContext.new(seed_val, profile)
	context.result = WorldResult.new()
	context.result.dimensions = Vector2i(profile.width, profile.height)
	for y in range(profile.height):
		for x in range(profile.width):
			context.result.cells[Vector2i(x, y)] = WorldCell.new(Vector2i(x, y))

	var target := Vector2i(47, 0)
	var t_stage := TerrainStage.new()
	t_stage.execute(context)
	var c := context.result.get_cell(target)
	print("After TerrainStage: height=%.3f, raw=%.3f, level=%d" % [c.height, c.raw_height, c.elevation_level])

	var h_stage := HydrologyStage.new()
	var hydro = HydrologyStage.solve_global(context)
	context.result.hydrology = hydro
	c = context.result.get_cell(target)
	print("After solve_global: height=%.3f, raw=%.3f, level=%d" % [c.height, c.raw_height, c.elevation_level])

	var is_water = hydro.is_water(target)
	print("Is target water? %s" % is_water)

	HydrologyStage.apply_local(context, hydro)
	c = context.result.get_cell(target)
	print("After apply_local: height=%.3f, raw=%.3f, level=%d, inf=%.3f" % [c.height, c.raw_height, c.elevation_level, c.hydraulic_influence])
	quit()
