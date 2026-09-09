class_name WorldPipeline
extends RefCounted

static func generate(seed_val: int, profile: WorldProfile = null) -> WorldResult:
	if profile == null:
		profile = TaigaWorldProfile.new()

	var context := WorldGenerationContext.new(seed_val, profile)

	var stages: Array[WorldStage] = [
		TerrainStage.new(),
		NavigationStage.new(),
		EcologyStage.new(),
		VegetationStage.new(),
	]

	for stage in stages:
		stage.execute(context)

	return context.result
