extends SceneTree

const _WorldVegetationItemScript = preload("res://src/world_generator/data/world_vegetation_item.gd")

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var result := WorldPipeline.generate(42, profile)

	# 1. Ensure world has conifers generated
	var conifer_count := 0
	for item in result.vegetation:
		if item.type == _WorldVegetationItemScript.Type.CONIFER:
			conifer_count += 1
	assert(conifer_count > 0, "Pipeline must generate conifers in taiga profile")

	# 2. Build terrain mesh
	var mesh: ArrayMesh = TerrainMeshBuilder.build_mesh(result, 1.0, profile)
	assert(mesh != null)

	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert(uv2s.size() == verts.size(), "UV2 array size must match total vertex count")
	assert(verts.size() >= profile.width * profile.height * 4, "Stepped terrain must produce at least 4 vertices per cell")

	# 3. Check that under-tree vertices have tree canopy factor > 0
	var canopy_vertices := 0
	for uv2 in uv2s:
		var factor: float = uv2.x
		assert(factor >= 0.0 and factor <= 1.0, "UV2.x factor must be in range [0, 1]")
		if factor > 0.2:
			canopy_vertices += 1

	assert(canopy_vertices > 0, "Must have under-tree canopy vertices")
	print("Verified under-tree texturing: %d conifers, %d canopy vertices" % [conifer_count, canopy_vertices])

	# 4. Check TerrainMaterial configuration
	var mat = TerrainMaterial.create_material(profile, true)
	assert(mat is ShaderMaterial, "TerrainMaterial must create ShaderMaterial")
	var shader_mat := mat as ShaderMaterial
	assert(shader_mat.get_shader_parameter("forest_grass_texture") != null, "forest_grass_texture must be set")
	assert(shader_mat.get_shader_parameter("forest_dirt_texture") != null, "forest_dirt_texture must be set")
	assert(shader_mat.get_shader_parameter("grass_texture") != null, "grass_texture must be set")
	assert(shader_mat.get_shader_parameter("sand_texture") != null, "sand_texture must be set")
	assert(shader_mat.get_shader_parameter("riverbed_texture") != null, "riverbed_texture must be set")

	# Check texture resource paths
	var fg_tex: Texture2D = shader_mat.get_shader_parameter("forest_grass_texture")
	var fd_tex: Texture2D = shader_mat.get_shader_parameter("forest_dirt_texture")
	assert(fg_tex.resource_path == "res://assets/texture/world/grass/Grass_03.png", "forest_grass_texture must be Grass_03.png")
	assert(fd_tex.resource_path == "res://assets/texture/world/dirt/Dirt_04.png", "forest_dirt_texture must be Dirt_04.png")

	print("test_under_tree_textures: OK")
	quit()
