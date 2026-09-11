extends SceneTree

const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test WaterRenderer ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	var result = _WorldPipelineScript.generate(1001, profile)
	assert(result != null)

	var water_node: Node3D = _WaterRendererScript.build_water_node(result, profile)
	assert(water_node != null, "Water node must be generated")
	assert(water_node.has_node("UnifiedWaterSurface"), "Must contain UnifiedWaterSurface child")

	var mi: MeshInstance3D = water_node.get_node("UnifiedWaterSurface")
	assert(mi.mesh != null, "Must contain a valid ArrayMesh")

	var dist_map: Dictionary = _WaterRendererScript.compute_distance_to_water(result)
	assert(not dist_map.is_empty(), "Distance to water map must not be empty")

	print("Test WaterRenderer: PASSED")
	quit(0)
