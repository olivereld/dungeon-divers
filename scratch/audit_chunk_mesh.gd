extends SceneTree

func _init() -> void:
	print("--- AUDITORIA: CHUNKDATA -> TERRAINMESHBUILDER ---")
	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new(16, 1)
	var seed_val := 12345

	# 1. Generar contexto de chunk (0,0) antes de trim
	var context := ChunkGenerationContext.new(seed_val, profile, Vector2i(0, 0), config)
	var stages := [
		preload("res://src/world_generator/stages/terrain_stage.gd").new(),
		preload("res://src/world_generator/stages/hydrology_stage.gd").new()
	]
	for s in stages:
		s.execute(context)

	print("1. Antes de trim_to_core():")
	print("   Total celdas en context.cells: ", context.result.cells.size())
	print("   ¿Existe celda (16, 0) en halo?: ", context.result.get_cell(Vector2i(16, 0)) != null)
	print("   ¿Existe celda (0, 16) en halo?: ", context.result.get_cell(Vector2i(0, 16)) != null)
	print("   ¿Existe celda (16, 16) en halo?: ", context.result.get_cell(Vector2i(16, 16)) != null)
	if context.result.get_cell(Vector2i(16, 0)) != null:
		print("   Altura en (16,0) en halo: ", context.result.get_cell(Vector2i(16, 0)).height)

	# 2. Después de trim_to_core()
	context.result.trim_to_core()
	print("\n2. Después de trim_to_core():")
	print("   Total celdas en chunk_data.cells: ", context.result.cells.size())
	print("   ¿Existe celda (16, 0) en core?: ", context.result.get_cell(Vector2i(16, 0)) != null)

	# 3. Construir malla con TerrainMeshBuilder
	var chunk_data := context.result as ChunkData
	var mesh := TerrainMeshBuilder.build_mesh(chunk_data, 1.0, profile)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	print("\n3. Malla generada por TerrainMeshBuilder:")
	print("   Total vertices generados: ", verts.size())
	print("   Total indices (triangulos * 3): ", indices.size())
	print("   Total quads: ", indices.size() / 6)

	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	for v in verts:
		min_x = minf(min_x, v.x)
		max_x = maxf(max_x, v.x)
		min_z = minf(min_z, v.z)
		max_z = maxf(max_z, v.z)

	print("   Coordenadas locales X en vertices: [", min_x, ", ", max_x, "]")
	print("   Coordenadas locales Z en vertices: [", min_z, ", ", max_z, "]")

	# 4. Comparar con Chunk (1, 0)
	var chunk_1_0 := WorldPipeline.generate_chunk(seed_val, Vector2i(1, 0), profile, config)
	var mesh_1_0 := TerrainMeshBuilder.build_mesh(chunk_1_0, 1.0, profile)
	var arrays_1_0: Array = mesh_1_0.surface_get_arrays(0)
	var verts_1_0: PackedVector3Array = arrays_1_0[Mesh.ARRAY_VERTEX]

	var chunk_0_global_end_x := 0.0 + max_x
	var chunk_1_global_start_x := 16.0 + verts_1_0[0].x

	print("\n4. Costura entre Chunk (0,0) y Chunk (1,0):")
	print("   Chunk (0,0) extremo global X: ", chunk_0_global_end_x)
	print("   Chunk (1,0) inicio global X:  ", chunk_1_global_start_x)
	print("   Brecha (Gap) entre mallas:    ", chunk_1_global_start_x - chunk_0_global_end_x, " metros")

	quit(0)
