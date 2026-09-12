extends SceneTree

const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test Confluence Ribbon Continuity ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 128
	profile.height = 128
	profile.hydrology_enabled = true
	profile.max_rivers = 6
	var result = _WorldPipelineScript.generate(777, profile)
	assert(result != null and result.hydrology != null)

	var confs: Array = result.hydrology.confluences
	var network = result.hydrology.get_river_network()
	var rivers: Array = network.rivers if network != null else result.hydrology.rivers

	var checked_tributary := false
	for r in rivers:
		var downstream: int = r.downstream_river if (r is River or "downstream_river" in r) else r.get("downstream_river", -1)
		if downstream != -1:
			var surf = _RiverMeshBuilderScript.build_river_surface(r, result, profile)
			assert(surf != null, "Tributary river ribbon must be generated")
			assert(surf.vertices.size() >= 4, "Tributary must have quad strip vertices")
			assert(surf.indices.size() >= 6, "Tributary must have quad strip triangles")
			checked_tributary = true
			break

	if not confs.is_empty():
		assert(checked_tributary, "At least one tributary confluence was verified")

	print("Test Confluence Ribbon Continuity: PASSED")
	quit(0)
