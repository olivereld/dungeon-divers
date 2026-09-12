extends SceneTree

const _LakeMeshBuilderScript = preload("res://src/world_generator/presentation/water/lake_mesh_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test LakeMeshBuilder ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.35
	var result = _WorldPipelineScript.generate(12345, profile)
	assert(result != null and result.hydrology != null)

	var lakes: Array = result.hydrology.lakes
	if not lakes.is_empty():
		var lake: Dictionary = lakes[0]
		var surf = _LakeMeshBuilderScript.build_lake_surface(lake, result, profile)
		assert(surf != null, "Lake surface must be generated")
		assert(surf.vertices.size() >= 3, "Must have vertices")
		for v in surf.vertices:
			assert(is_equal_approx(v.y, float(lake["water_height"])), "All lake vertices must be planar at lake water_height")
	print("Test LakeMeshBuilder: PASSED")
	quit(0)
