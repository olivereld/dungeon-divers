extends SceneTree

const _TerrainColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")
const _PresentationWorldRendererScript = preload("res://src/world_generator/presentation/world_renderer.gd")

func _init() -> void:
	var profile := TaigaWorldProfile.new()
	var result := WorldPipeline.generate(123, profile)

	# 1. WorldRenderer with profile
	var renderer := WorldRenderer.new()
	var node := renderer.render_world(result, profile)
	assert(node != null)
	assert(node.has_node("TerrainMesh"))
	assert(node.has_node("TerrainCollision"))

	var mesh_inst: MeshInstance3D = node.get_node("TerrainMesh")
	var array_mesh: ArrayMesh = mesh_inst.mesh
	var arrays := array_mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert(colors.size() == profile.width * profile.height, "Must have 1 color per vertex")

	# Verify UV2 contains tree canopy factor
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert(uv2s.size() == profile.width * profile.height, "Must have 1 UV2 vector per vertex")
	var has_tree_canopy := false
	for uv2 in uv2s:
		assert(uv2.x >= 0.0 and uv2.x <= 1.0, "Tree factor in UV2.x must be within [0, 1]")
		if uv2.x > 0.5:
			has_tree_canopy = true
	assert(has_tree_canopy, "At least some vertices must have tree canopy influence under conifers")

	# Verify TerrainMaterial shader bindings
	var terrain_mat = mesh_inst.material_override
	if terrain_mat == null:
		terrain_mat = mesh_inst.get_surface_override_material(0)
	if terrain_mat is ShaderMaterial:
		assert(terrain_mat.get_shader_parameter("forest_grass_texture") != null, "Shader must receive forest_grass_texture")
		assert(terrain_mat.get_shader_parameter("forest_dirt_texture") != null, "Shader must receive forest_dirt_texture")
		assert(terrain_mat.get_shader_parameter("grass_texture") != null, "Shader must receive grass_texture")
		assert(terrain_mat.get_shader_parameter("sand_texture") != null, "Shader must receive sand_texture")
		assert(terrain_mat.get_shader_parameter("riverbed_texture") != null, "Shader must receive riverbed_texture")

	# Verify all colors are valid non-NaN albedo values with valid alpha
	for col in colors:
		assert(not is_nan(col.r) and not is_nan(col.g) and not is_nan(col.b))
		assert(col.a >= 0.0 and col.a <= 1.0)
		assert(col.r >= 0.0 and col.r <= 1.0)
		assert(col.g >= 0.0 and col.g <= 1.0)
		assert(col.b >= 0.0 and col.b <= 1.0)

	# Check for WaterRoot presence
	if result.hydrology != null and not result.hydrology.water_cells.is_empty():
		assert(node.has_node("WaterRoot") or node.has_node("HydrologyRoot"), "WaterRoot node must be generated when water exists")

	node.free()
	renderer.free()

	# 2. TerrainColorResolver isolated checks (Pure Land: Loam and Rock)
	var flat_cell := WorldCell.new(Vector2i(0, 0))
	flat_cell.slope = 0.0
	flat_cell.normalized_height = 0.0
	flat_cell.moisture = 0.5
	var low_col: Color = _TerrainColorResolverScript.resolve_vertex_color(flat_cell, profile)
	assert(low_col.is_equal_approx(profile.terrain_loam_color), "Low elevation ground must be organic loam, NOT water!")

	var cliff_cell := WorldCell.new(Vector2i(1, 1))
	cliff_cell.slope = 45.0
	cliff_cell.moisture = 0.5
	var cliff_col: Color = _TerrainColorResolverScript.resolve_vertex_color(cliff_cell, profile)
	assert(cliff_col.is_equal_approx(profile.terrain_rock_color), "Steep cliff faces must be exposed granite rock!")

	# 3. PresentationWorldRenderer alias check
	var pres_renderer = _PresentationWorldRendererScript.new()
	var pres_node: Node3D = pres_renderer.render_world(result, profile)
	assert(pres_node != null)
	pres_node.free()
	pres_renderer.free()

	print("test_world_renderer_headless: OK")
	quit()
