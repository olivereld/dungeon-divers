extends SceneTree

func _init() -> void:
	print("--- TEST DE SELLADO DE COSTURA (17x17 vertices / 16x16 quads) ---")
	var profile := TaigaWorldProfile.new()
	var config := ChunkConfig.new(16, 1)
	var seed_val := 12345

	var shared_hydro := WorldPipeline.generate_regional_hydrology(seed_val, profile)

	# Contexto 0,0
	var ctx0 := ChunkGenerationContext.new(seed_val, profile, Vector2i(0, 0), config, shared_hydro)
	var stages := [
		preload("res://src/world_generator/stages/terrain_stage.gd").new(),
		preload("res://src/world_generator/stages/hydrology_stage.gd").new()
	]
	for s in stages:
		s.execute(ctx0)

	# Simular guardar seam_cells antes de trim
	var seam_cells: Dictionary = {}
	var chunk0 := ctx0.result as ChunkData
	var core_end: Vector2i = chunk0.core_bounds.end
	for pos in chunk0.cells:
		if pos.x == core_end.x or pos.y == core_end.y:
			seam_cells[pos] = ctx0.result.cells[pos]

	ctx0.result.trim_to_core()
	assert(ctx0.result.cells.size() == 256)
	print("seam_cells recolectadas: ", seam_cells.size())

	# Contexto 1,0
	var chunk1 := WorldPipeline.generate_chunk(seed_val, Vector2i(1, 0), profile, config, shared_hydro)

	# Comparar altura del vertice compartido en x = 16
	for y in range(16):
		var h_chunk0_seam: float = seam_cells[Vector2i(16, y)].height
		var h_chunk1_core: float = chunk1.cells[Vector2i(16, y)].height
		var diff := absf(h_chunk0_seam - h_chunk1_core)
		assert(diff < 0.00001, "Altura debe ser identica en el borde: %f vs %f" % [h_chunk0_seam, h_chunk1_core])

	print("PASS: Altura en la costura x=16 es 100% IDENTICA (diff = 0.000000)")
	quit(0)
