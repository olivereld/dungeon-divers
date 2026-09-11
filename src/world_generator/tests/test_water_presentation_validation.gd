extends SceneTree

const _WaterPresentationValidationScript = preload("res://src/world_generator/validation/water_presentation_validation.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test WaterPresentationValidation ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	var result = _WorldPipelineScript.generate(888, profile)
	assert(result != null)

	var rep: Dictionary = _WaterPresentationValidationScript.validate(result, profile)
	assert(rep["valid"], "Water presentation must be valid: %s" % str(rep["errors"]))
	print("Test WaterPresentationValidation: PASSED (triangles: %d)" % rep["metrics"]["total_triangles"])
	quit(0)
