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
	assert(colors.size() == 128 * 128, "Must have 1 color per vertex")

	# Verify all colors are valid non-NaN albedo values with alpha = 1.0
	for col in colors:
		assert(not is_nan(col.r) and not is_nan(col.g) and not is_nan(col.b))
		assert(col.a == 1.0)
		assert(col.r >= 0.0 and col.r <= 1.0)
		assert(col.g >= 0.0 and col.g <= 1.0)
		assert(col.b >= 0.0 and col.b <= 1.0)

	node.free()
	renderer.free()

	# 2. TerrainColorResolver isolated checks
	var flat_cell := WorldCell.new(Vector2i(0, 0))
	flat_cell.slope = 0.0
	flat_cell.normalized_height = 0.0
	flat_cell.moisture = 0.5
	var low_col: Color = _TerrainColorResolverScript.resolve_vertex_color(flat_cell, profile)
	assert(low_col.is_equal_approx(profile.color_deep_water))

	var cliff_cell := WorldCell.new(Vector2i(1, 1))
	cliff_cell.slope = 45.0
	cliff_cell.moisture = 0.5
	var cliff_col: Color = _TerrainColorResolverScript.resolve_vertex_color(cliff_cell, profile)
	assert(cliff_col.is_equal_approx(profile.color_rock))

	# 3. PresentationWorldRenderer alias check
	var pres_renderer = _PresentationWorldRendererScript.new()
	var pres_node: Node3D = pres_renderer.render_world(result, profile)
	assert(pres_node != null)
	pres_node.free()
	pres_renderer.free()

	print("test_world_renderer_headless: OK")
	quit()
