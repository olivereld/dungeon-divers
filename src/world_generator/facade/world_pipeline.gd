class_name WorldPipeline
extends RefCounted

const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")

static func generate(seed_val: int, profile: WorldProfile = null) -> WorldResult:
	if profile == null:
		profile = TaigaWorldProfile.new()

	var context := WorldGenerationContext.new(seed_val, profile)

	var stages: Array[WorldStage] = [
		TerrainStage.new(),
		_HydrologyStageScript.new(),
		EcologyStage.new(),
		NavigationStage.new(),
		VegetationStage.new(),
	]

	for stage in stages:
		stage.execute(context)

	return context.result
