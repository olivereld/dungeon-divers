extends SceneTree

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(777, profile)
	TerrainStage.new().execute(context)
	NavigationStage.new().execute(context)
	EcologyStage.new().execute(context)
	VegetationStage.new().execute(context)

	assert(context.result.vegetation.size() > 0, "Vegetation items must be generated")
	var item: WorldVegetationItem = context.result.vegetation[0]
	assert(item.type in [WorldVegetationItem.Type.CONIFER, WorldVegetationItem.Type.SHRUB, WorldVegetationItem.Type.ROCK])
	assert(item.scale > 0.0)

	# Test determinism
	var context2 := WorldGenerationContext.new(777, profile)
	TerrainStage.new().execute(context2)
	NavigationStage.new().execute(context2)
	EcologyStage.new().execute(context2)
	VegetationStage.new().execute(context2)
	assert(context.result.vegetation.size() == context2.result.vegetation.size(), "Vegetation count must match")
	var item2: WorldVegetationItem = context2.result.vegetation[0]
	assert(item.position == item2.position, "Positions must match exactly")
	assert(item.rotation_y == item2.rotation_y, "Rotations must match")

	print("test_vegetation_stage: OK")
	quit()
