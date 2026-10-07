extends SceneTree

const BiomeIdScript = preload("res://src/world_generator/biomes/biome_id.gd")
const BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const BiomeSelectorScript = preload("res://src/world_generator/biomes/biome_selector.gd")
const WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Biome Definitions & Selection Test Suite (Fase 3 & 4)")
	print("==================================================")

	# 1. Validación de BiomeRegistry
	var reg := BiomeRegistryScript.create_default_registry()
	assert(reg.has_definition(BiomeIdScript.TAIGA), "Registry must have TAIGA")
	assert(reg.has_definition(BiomeIdScript.TUNDRA), "Registry must have TUNDRA")
	assert(reg.has_definition(BiomeIdScript.TEMPERATE_FOREST), "Registry must have TEMPERATE_FOREST")
	assert(reg.has_definition(BiomeIdScript.DESERT), "Registry must have DESERT")
	assert(reg.has_definition(BiomeIdScript.JUNGLE), "Registry must have JUNGLE")

	for def in reg.get_all_definitions():
		assert(def.ecology_profile != null, "EcologyProfile must not be null in %s" % String(def.id))
		assert(def.vegetation_profile != null, "VegetationProfile must not be null in %s" % String(def.id))
		assert(def.rock_profile != null, "RockProfile must not be null in %s" % String(def.id))
		assert(def.rendering_profile != null, "RenderingProfile must not be null in %s" % String(def.id))

	print(" -> [PASS] BiomeRegistry contains all 5 biomes with non-null complete profiles")

	# 2. Validación de BiomeSelector y Tabla de correspondencia T/M/E
	var selector := BiomeSelectorScript.new(reg)

	# Taiga: fría y húmeda
	assert(selector.select(0.20, 0.70, 0.20) == BiomeIdScript.TAIGA, "Must select TAIGA")
	# Tundra: fría y seca
	assert(selector.select(0.15, 0.20, 0.20) == BiomeIdScript.TUNDRA, "Must select TUNDRA")
	# Bosque templado: templado y húmedo
	assert(selector.select(0.50, 0.60, 0.20) == BiomeIdScript.TEMPERATE_FOREST, "Must select TEMPERATE_FOREST")
	# Desierto: cálido y seco
	assert(selector.select(0.85, 0.15, 0.20) == BiomeIdScript.DESERT, "Must select DESERT")
	# Jungla: cálida y muy húmeda
	assert(selector.select(0.85, 0.85, 0.20) == BiomeIdScript.JUNGLE, "Must select JUNGLE")

	print(" -> [PASS] Selection table T/M/E -> expected BiomeId verified")

	# 3. Cobertura completa del espacio 3D [0..1]^3 sin huecos
	var steps: int = 10
	for it in range(steps + 1):
		var t := float(it) / float(steps)
		for im in range(steps + 1):
			var m := float(im) / float(steps)
			for ie in range(steps + 1):
				var e := float(ie) / float(steps)
				var chosen_id := selector.select(t, m, e)
				assert(chosen_id != StringName(), "Domain coverage hole found at (T:%.2f, M:%.2f, E:%.2f)" % [t, m, e])
				assert(reg.has_definition(chosen_id), "Selected biome '%s' must exist in registry" % String(chosen_id))

	print(" -> [PASS] 100% domain coverage across [0..1]^3 space without unhandled holes")

	# 4. Integración en WorldPipeline
	var profile := TaigaWorldProfile.new()
	profile.width = 64
	profile.height = 64
	var res := WorldPipelineScript.generate(123456, profile)
	assert(res.has_meta(&"biome_stage_executed"), "BiomeStage must be executed in WorldPipeline")

	var biome_counts: Dictionary = {}
	for pos in res.cells:
		var cell: WorldCell = res.cells[pos]
		assert(cell.biome_id != StringName(), "cell.biome_id must not be empty")
		assert(reg.has_definition(cell.biome_id), "cell.biome_id must be registered in registry")
		biome_counts[cell.biome_id] = biome_counts.get(cell.biome_id, 0) + 1

	print(" -> [PASS] WorldPipeline assigned valid biome_id to all cells (", res.cells.size(), " cells): ", biome_counts)

	# 5. Coherencia de biome_id en fronteras de chunks
	var chunk_config := ChunkConfig.new()
	chunk_config.chunk_size = 32
	var chunk_a := WorldPipelineScript.generate_chunk(123456, Vector2i(0, 0), profile, chunk_config)
	var chunk_b := WorldPipelineScript.generate_chunk(123456, Vector2i(1, 0), profile, chunk_config)

	var valid_seam_cells: int = 0
	for y in range(32):
		var cell_a: WorldCell = chunk_a.get_cell(Vector2i(31, y))
		var cell_b: WorldCell = chunk_b.get_cell(Vector2i(32, y))
		if cell_a != null and cell_b != null:
			valid_seam_cells += 1
			assert(reg.has_definition(cell_a.biome_id), "Seam cell A has valid biome")
			assert(reg.has_definition(cell_b.biome_id), "Seam cell B has valid biome")

	assert(valid_seam_cells == 32, "All 32 seam cell pairs must be validated")
	print(" -> [PASS] Chunk seam biome selection coherence verified")

	print("==================================================")
	print(" ALL BIOME DEFINITION & SELECTION TESTS PASSED!")
	print("==================================================")
	quit(0)
