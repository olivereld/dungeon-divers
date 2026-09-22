extends SceneTree

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _AutumnForestWorldProfileScript = preload("res://src/world_generator/profiles/autumn_forest_world_profile.gd")
const _ChunkConfigScript = preload("res://src/world_generator/chunks/chunk_config.gd")
const _TerrainMeshBuilderScript = preload("res://src/world_renderer/terrain_mesh_builder.gd")

func _init() -> void:
	var profile := _AutumnForestWorldProfileScript.new()
	var config := _ChunkConfigScript.new(16, 2)
	var seed_val := 12345
	var shared_hydro = _WorldPipelineScript.generate_regional_hydrology(seed_val, profile)

	var chunk_0_0 = _WorldPipelineScript.generate_chunk(seed_val, Vector2i(0, 0), profile, config, shared_hydro)
	var chunk_1_0 = _WorldPipelineScript.generate_chunk(seed_val, Vector2i(1, 0), profile, config, shared_hydro)

	var mesh_0_0: ArrayMesh = _TerrainMeshBuilderScript.build_mesh(chunk_0_0, 1.0, profile)
	var mesh_1_0: ArrayMesh = _TerrainMeshBuilderScript.build_mesh(chunk_1_0, 1.0, profile)

	var arr_0_0: Array = mesh_0_0.surface_get_arrays(0)
	var arr_1_0: Array = mesh_1_0.surface_get_arrays(0)

	var verts_0: PackedVector3Array = arr_0_0[Mesh.ARRAY_VERTEX]
	var uv2_0: PackedVector2Array = arr_0_0[Mesh.ARRAY_TEX_UV2]
	var col_0: PackedColorArray = arr_0_0[Mesh.ARRAY_COLOR]
	var norm_0: PackedVector3Array = arr_0_0[Mesh.ARRAY_NORMAL]

	var verts_1: PackedVector3Array = arr_1_0[Mesh.ARRAY_VERTEX]
	var uv2_1: PackedVector2Array = arr_1_0[Mesh.ARRAY_TEX_UV2]
	var col_1: PackedColorArray = arr_1_0[Mesh.ARRAY_COLOR]
	var norm_1: PackedVector3Array = arr_1_0[Mesh.ARRAY_NORMAL]

	var c0_cell = chunk_0_0.get_cell_or_seam(Vector2i(16, 0))
	var c1_cell = chunk_1_0.get_cell_or_seam(Vector2i(16, 0))
	print("Cell in chunk(0,0) at (16,0):")
	print("  height: ", c0_cell.height if c0_cell else null)
	print("  norm_height: ", c0_cell.normalized_height if c0_cell else null)
	print("  slope: ", c0_cell.slope if c0_cell else null)
	print("  moisture: ", c0_cell.moisture if c0_cell else null)
	print("  forest_density: ", c0_cell.forest_density if c0_cell else null)
	print("  clearing_density: ", c0_cell.clearing_density if c0_cell else null)

	print("Cell in chunk(1,0) at (16,0):")
	print("  height: ", c1_cell.height if c1_cell else null)
	print("  norm_height: ", c1_cell.normalized_height if c1_cell else null)
	print("  slope: ", c1_cell.slope if c1_cell else null)
	print("  moisture: ", c1_cell.moisture if c1_cell else null)
	print("  forest_density: ", c1_cell.forest_density if c1_cell else null)
	print("  clearing_density: ", c1_cell.clearing_density if c1_cell else null)

	var grid_w := 17
	var uv2_diff_count := 0
	var col_diff_count := 0
	var norm_diff_count := 0

	for y in range(17):
		var idx_0: int = y * grid_w + 16
		var idx_1: int = y * grid_w + 0

		var u0 := uv2_0[idx_0]
		var u1 := uv2_1[idx_1]
		if absf(u0.x - u1.x) > 0.001:
			uv2_diff_count += 1
			print("  y=%d -> UV2 mismatch: chunk(0,0)=%.3f vs chunk(1,0)=%.3f" % [y, u0.x, u1.x])

		var c0 := col_0[idx_0]
		var c1 := col_1[idx_1]
		if absf(c0.r - c1.r) > 0.001 or absf(c0.a - c1.a) > 0.001:
			col_diff_count += 1
			print("  y=%d -> Color mismatch: chunk(0,0)=%s vs chunk(1,0)=%s" % [y, str(c0), str(c1)])

		var n0 := norm_0[idx_0]
		var n1 := norm_1[idx_1]
		if n0.distance_to(n1) > 0.001:
			norm_diff_count += 1
			print("  y=%d -> Normal mismatch: chunk(0,0)=%s vs chunk(1,0)=%s" % [y, str(n0), str(n1)])

	print("Summary of seam diffs: UV2(tree_mask)=%d, Color=%d, Normal=%d" % [uv2_diff_count, col_diff_count, norm_diff_count])
	quit(0)
