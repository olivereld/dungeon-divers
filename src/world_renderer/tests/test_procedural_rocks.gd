extends SceneTree

const _ProceduralRockGeneratorScript = preload("res://src/world_renderer/procedural_rock_generator.gd")

func _init() -> void:
	# 1. Test ProceduralRockGenerator
	var variants: Array[Mesh] = _ProceduralRockGeneratorScript.get_rock_variants(true)
	assert(variants.size() == 6, "Must generate exactly 6 rock archetypes")

	for i in range(variants.size()):
		var mesh: Mesh = variants[i]
		assert(mesh is ArrayMesh, "Rock variant %d must be an ArrayMesh" % i)
		assert(mesh.get_surface_count() == 1, "Rock variant %d must have 1 surface" % i)

		var arrays: Array = (mesh as ArrayMesh).surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

		assert(verts.size() == 240, "Subdivided icosphere flat-shaded must have 240 vertices (80 triangles * 3)")
		assert(normals.size() == 240, "Normals must match vertex count")
		assert(uvs.size() == 240, "UVs must match vertex count")
		assert(colors.size() == 240, "Colors must match vertex count")
		assert(indices.size() == 240, "Indices must match vertex count")

		# Verify that 100% of triangles have outward-facing front faces (no inverted/see-through faces)
		for tri_idx in range(0, verts.size(), 3):
			var v0: Vector3 = verts[tri_idx]
			var v1: Vector3 = verts[tri_idx + 1]
			var v2: Vector3 = verts[tri_idx + 2]
			var fn: Vector3 = (v2 - v0).cross(v1 - v0)
			var mid: Vector3 = (v0 + v1 + v2) / 3.0
			assert(fn.dot(mid) > 0.0, "Rock variant %d triangle %d must have outward front face!" % [i, tri_idx / 3])

		# Check material
		var mat: Material = mesh.surface_get_material(0)
		assert(mat is StandardMaterial3D, "Rock material must be StandardMaterial3D")
		var std_mat := mat as StandardMaterial3D
		assert(std_mat.albedo_texture != null, "Rock must have hand-painted stone texture")
		assert(std_mat.uv1_triplanar, "Rock material must use triplanar mapping")
		assert(not std_mat.uv1_world_triplanar, "Rock triplanar must be local to preserve rotation")
		assert(std_mat.cull_mode == BaseMaterial3D.CULL_BACK, "Rock must use CULL_BACK with solid outer faces")

	print("ProceduralRockGenerator: all 6 archetypes verified with 100% outward front faces")

	# 2. Test WorldRenderer Integration
	var profile := TaigaWorldProfile.new()
	var result := WorldPipeline.generate(42, profile)
	var renderer := WorldRenderer.new()
	var world_node := renderer.render_world(result, profile)
	assert(world_node != null)

	var rocks_node: Node3D = world_node.find_child("Rocks", true, false)
	assert(rocks_node != null, "World must contain a 'Rocks' container node")

	var rock_variants_found := 0
	var total_instances := 0
	for child in rocks_node.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("RockVariant_"):
			rock_variants_found += 1
			var mm: MultiMesh = child.multimesh
			assert(mm != null)
			total_instances += mm.instance_count

			for inst_idx in range(mm.instance_count):
				var xform: Transform3D = mm.get_instance_transform(inst_idx)
				assert(not is_nan(xform.origin.x) and not is_nan(xform.origin.y) and not is_nan(xform.origin.z))
				assert(xform.basis.determinant() != 0.0, "Instance transform must have non-zero scale")

	assert(rock_variants_found > 0, "Must spawn at least 1 rock variant MultiMesh")
	assert(total_instances > 0, "Must have rock instances rendered")
	print("WorldRenderer Rocks Integration: found %d rock variants, %d total rock instances" % [rock_variants_found, total_instances])

	world_node.free()
	renderer.free()
	print("test_procedural_rocks: OK")
	quit()
