extends SceneTree

const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Test RiverMeshBuilder ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	var result = _WorldPipelineScript.generate(42, profile)
	assert(result != null and result.hydrology != null)

	var rivers: Array = result.hydrology.rivers
	if not rivers.is_empty():
		var r = rivers[0]
		var surf = _RiverMeshBuilderScript.build_river_surface(r, result, profile)
		assert(surf != null, "Surface must be generated")
		assert(surf.vertices.size() >= 4, "Must generate at least 4 vertices for ribbon")
		assert(surf.indices.size() >= 6, "Must generate triangles")

		# Verify UVs and flow directions
		for i in range(surf.vertices.size()):
			var uv: Vector2 = surf.uvs[i]
			assert(uv.x >= 0.0 and uv.x <= 1.001, "Transversal UV must be [0, 1]")
			var flow: Vector2 = surf.uv2_flow[i]
			assert(flow.length() > 0.1, "Flow vector must be non-zero downstream")

		# Verify water level strictly finite
		for i in range(surf.vertices.size()):
			var v: Vector3 = surf.vertices[i]
			assert(not is_nan(v.y) and not is_inf(v.y), "Water Y must be valid float")

	print("Test RiverMeshBuilder: PASSED")
	quit(0)
