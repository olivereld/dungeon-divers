extends SceneTree

const _WaterTopologyBuilderScript = preload("res://src/world_generator/presentation/water/water_topology_builder.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("--- Running test_unified_water_mesh_builder ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.35
	var result = _WorldPipelineScript.generate(12345, profile)
	assert(result != null and result.hydrology != null)

	var regions: Array = _WaterTopologyBuilderScript.build_regions(result, profile)
	assert(not regions.is_empty(), "Must find water regions in generated world")

	for r in regions:
		var reg_surf = _WaterMeshBuilderScript.build_region_surface(r, result, profile)
		assert(reg_surf != null)
		if reg_surf.vertices.is_empty():
			continue

		print("  Region %d: %d cells -> %d verts, %d tris" % [r.id, r.cell_count(), reg_surf.vertices.size(), reg_surf.indices.size() / 3])

		# 1. Chequeo de finitud y sanidad
		for v in reg_surf.vertices:
			assert(is_finite(v.x) and is_finite(v.y) and is_finite(v.z), "Vertices must be finite")
		for n in reg_surf.normals:
			assert(is_finite(n.x) and is_finite(n.y) and is_finite(n.z), "Normals must be finite")
		for uv in reg_surf.uvs:
			assert(is_finite(uv.x) and is_finite(uv.y), "UVs must be finite")
		for f in reg_surf.uv2_flow:
			assert(is_finite(f.x) and is_finite(f.y), "Flow must be finite")

		# 2. Chequeo de triángulos degenerados
		for i in range(0, reg_surf.indices.size(), 3):
			var i0 = reg_surf.indices[i]
			var i1 = reg_surf.indices[i + 1]
			var i2 = reg_surf.indices[i + 2]
			assert(i0 != i1 and i1 != i2 and i0 != i2, "Indices must be distinct")
			var v0: Vector3 = reg_surf.vertices[i0]
			var v1: Vector3 = reg_surf.vertices[i1]
			var v2: Vector3 = reg_surf.vertices[i2]
			var area: float = (v1 - v0).cross(v2 - v0).length() * 0.5
			assert(area >= 0.00005, "Triangle area must be positive and non-degenerate")

	# 3. Test de nodo completo
	var node = _WaterMeshBuilderScript.build_water_mesh_node(regions, result, profile)
	assert(node != null)
	assert(node.has_node("UnifiedWaterSurface"))
	var mi: MeshInstance3D = node.get_node("UnifiedWaterSurface")
	assert(mi.mesh != null)
	node.free()

	print("test_unified_water_mesh_builder: PASSED")
	quit(0)
