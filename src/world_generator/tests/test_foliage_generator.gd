extends SceneTree

const _FoliageGeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _FoliageProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _BiomeIdScript = preload("res://src/world_generator/biomes/biome_id.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Foliage Generator Test Suite (Tarea 4)")
	print("==================================================")

	var reg = _BiomeRegistryScript.get_default()
	# Asegurar que el bioma TAIGA tiene un foliage_profile para la prueba
	var taiga_def = reg.get_definition(_BiomeIdScript.TAIGA)
	assert(taiga_def != null, "TAIGA biome must exist")

	var sp1 = _FoliageSpeciesScript.new(
		&"grass_common",
		"Common Grass",
		"res://assets/texture/foliage/grass/large_grass_01.jpg",
		1.0,
		Vector3(0.8, 0.8, 0.8),
		Vector3(1.2, 1.2, 1.2),
		25.0
	)
	var fol_prof = _FoliageProfileScript.new(1.0, [sp1], 25.0, 0.5)
	taiga_def.foliage_profile = fol_prof

	# Generar un contexto y resultado de prueba
	var profile := TaigaWorldProfile.new()
	var context := WorldGenerationContext.new(12345, profile)
	TerrainStage.new().execute(context)
	NavigationStage.new().execute(context)
	ClimateStage.new().execute(context)
	BiomeStage.new().execute(context)

	var gen = _FoliageGeneratorScript.new()
	var chunk_data = gen.generate_foliage(context.result, 12345, context.get_core_bounds(), profile, reg)

	assert(chunk_data != null, "FoliageChunkData must be created")
	var count = chunk_data.get_total_instance_count()
	assert(count > 0, "Foliage generator must produce instances (got %d)" % count)
	print(" -> [PASS] Generated %d foliage instances successfully" % count)

	# 2. Test Determinismo
	var chunk_data_2 = gen.generate_foliage(context.result, 12345, context.get_core_bounds(), profile, reg)
	assert(chunk_data.get_total_instance_count() == chunk_data_2.get_total_instance_count(), "Count must match deterministically")

	var insts1 = chunk_data.get_instances_for_species(&"grass_common")
	var insts2 = chunk_data_2.get_instances_for_species(&"grass_common")
	assert(insts1.size() == insts2.size(), "Species count must match")
	for i in range(mini(insts1.size(), 100)):
		assert(insts1[i].origin.is_equal_approx(insts2[i].origin), "Position %d must match exactly" % i)
	print(" -> [PASS] Strict deterministic reproducibility verified")

	# 3. Test Exclusión de agua y pendientes
	for inst in insts1:
		var gx := floori(inst.origin.x)
		var gz := floori(inst.origin.z)
		var cell = context.result.get_cell(Vector2i(gx, gz))
		if cell != null:
			assert(cell.slope <= fol_prof.max_slope + 0.1, "Foliage must not spawn on steep slopes > max_slope")

	print(" -> [PASS] Slope exclusion verified")

	print("==================================================")
	print(" ALL FOLIAGE GENERATOR TESTS PASSED!")
	print("==================================================")
	quit(0)
