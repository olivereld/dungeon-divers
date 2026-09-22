extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Testing Cliff Texture & Material Integration")
	print("==================================================")

	var profile := TaigaWorldProfile.new()

	# 1. Comprobar que la textura cliff_02.jpg existe y carga válidamente
	var tex_path := TerrainMaterial.CLIFF_TEXTURE_PATH
	assert(ResourceLoader.exists(tex_path), "Cliff texture file must exist: %s" % tex_path)
	var cliff_tex: Texture2D = load(tex_path)
	assert(cliff_tex != null, "Cliff texture must load properly as Texture2D")
	assert(cliff_tex.get_width() > 0 and cliff_tex.get_height() > 0, "Cliff texture must have valid dimensions")
	print(" [PASS] 1. Cliff texture resource loaded successfully (%dx%d)" % [cliff_tex.get_width(), cliff_tex.get_height()])

	# 2. Comprobar que TerrainMaterial genera un ShaderMaterial con cliff_texture
	var mat = TerrainMaterial.create_material(profile, true)
	assert(mat is ShaderMaterial, "Material must be a ShaderMaterial")
	var shader_mat := mat as ShaderMaterial
	assert(shader_mat.shader != null, "Shader must be assigned")

	var bound_cliff_tex = shader_mat.get_shader_parameter("cliff_texture")
	assert(bound_cliff_tex != null, "cliff_texture must be set on ShaderMaterial")
	assert(bound_cliff_tex == cliff_tex, "Bound cliff texture must match cliff_02.jpg")

	var bound_uv_scale = shader_mat.get_shader_parameter("cliff_uv_scale")
	assert(bound_uv_scale != null and float(bound_uv_scale) > 0.0, "cliff_uv_scale must be positive float")

	var bound_tint = shader_mat.get_shader_parameter("cliff_tint")
	assert(bound_tint is Color, "cliff_tint must be a Color")
	print(" [PASS] 2. ShaderMaterial parameters validated (cliff_texture, uv_scale=%.2f, tint=%s)" % [float(bound_uv_scale), str(bound_tint)])

	# 3. Comprobar que el WorldRenderer adjunta el material al TerrainMesh
	var result := WorldPipeline.generate(12345, profile)
	var renderer := WorldRenderer.new()
	var world_node := renderer.render_world(result, profile)
	assert(world_node != null)
	var terrain_mi: MeshInstance3D = world_node.get_node("TerrainMesh")
	assert(terrain_mi != null)
	var applied_mat = terrain_mi.get_surface_override_material(0)
	assert(applied_mat is ShaderMaterial, "TerrainMesh must have ShaderMaterial applied")
	var applied_cliff_tex = (applied_mat as ShaderMaterial).get_shader_parameter("cliff_texture")
	assert(applied_cliff_tex == cliff_tex, "Applied material must hold cliff_02.jpg")
	print(" [PASS] 3. TerrainMesh in RenderedWorld has valid ShaderMaterial with cliff_02.jpg")

	world_node.free()
	renderer.free()

	print("==================================================")
	print(" ALL CLIFF TEXTURE TESTS PASSED!")
	print("==================================================")
	quit()
