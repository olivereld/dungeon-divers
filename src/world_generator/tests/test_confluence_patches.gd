extends SceneTree

const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test Confluence Patches ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 128
	profile.height = 128
	profile.hydrology_enabled = true
	profile.max_rivers = 6
	var result = _WorldPipelineScript.generate(777, profile)
	assert(result != null and result.hydrology != null)

	var confs: Array = result.hydrology.confluences
	if not confs.is_empty():
		var conf = confs[0]
		var patch = _RiverMeshBuilderScript.build_confluence_patch(conf, result, profile)
		assert(patch != null, "Confluence patch must be built")
		assert(patch.vertices.size() >= 3, "Patch must have geometry")
		assert(patch.indices.size() >= 3, "Patch must have triangles")
	print("Test Confluence Patches: PASSED")
	quit(0)
