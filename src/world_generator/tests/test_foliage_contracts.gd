extends SceneTree

const _FoliageSpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _FoliageProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _FoliageChunkDataScript = preload("res://src/world_generator/foliage/foliage_chunk_data.gd")
const _BiomeDefinitionScript = preload("res://src/world_generator/biomes/biome_definition.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Foliage Contracts Test Suite (Tarea 1)")
	print("==================================================")

	# 1. Test FoliageSpecies
	var species = _FoliageSpeciesScript.new()
	assert(species.id != &"", "Species id must have a default value")
	assert(species.density_weight > 0.0, "Species density weight must be positive")
	assert(species.scale_min.length() > 0.0, "Scale min must be valid")
	assert(species.scale_max.length() > 0.0, "Scale max must be valid")
	assert(species.quad_cross_count >= 2, "Crossed quads count must be at least 2")

	var custom_species = _FoliageSpeciesScript.new(
		&"grass_large",
		"Large Grass",
		"res://assets/texture/foliage/grass/large_grass_01.jpg",
		1.5,
		Vector3(0.9, 0.9, 0.9),
		Vector3(1.3, 1.4, 1.3),
		22.0,
		Color(0.2, 0.3, 0.15),
		Color(0.5, 0.7, 0.3),
		3
	)
	assert(custom_species.id == &"grass_large", "Custom species id must match")
	assert(custom_species.texture_path == "res://assets/texture/foliage/grass/large_grass_01.jpg", "Texture path must match")
	assert(custom_species.quad_cross_count == 3, "Cross count must be 3")
	print(" -> [PASS] FoliageSpecies data contract verified")

	# 2. Test FoliageProfile
	var profile = _FoliageProfileScript.new()
	assert(profile.base_density >= 0.0, "Base density must be >= 0")
	profile.species.append(custom_species)
	assert(profile.species.size() == 1, "Profile must store species")
	assert(profile.get_species(&"grass_large") == custom_species, "get_species must return matching species")
	assert(profile.get_species(&"non_existent") == null, "get_species must return null for missing id")
	print(" -> [PASS] FoliageProfile data contract verified")

	# 3. Test FoliageChunkData
	var chunk_data = _FoliageChunkDataScript.new(Vector2i(3, 4))
	assert(chunk_data.chunk_coord == Vector2i(3, 4), "Chunk coord must match")
	assert(chunk_data.get_total_instance_count() == 0, "Initial count must be 0")

	var t1 := Transform3D(Basis(), Vector3(1.0, 2.0, 3.0))
	var c1 := Color(0.4, 0.6, 0.2)
	chunk_data.add_instance(&"grass_large", t1, c1)

	assert(chunk_data.get_total_instance_count() == 1, "Total count must be 1")
	assert(chunk_data.instances_by_species.has(&"grass_large"), "Must have species entry")
	var instances: Array = chunk_data.get_instances_for_species(&"grass_large")
	var colors: PackedColorArray = chunk_data.get_colors_for_species(&"grass_large")
	assert(instances.size() == 1, "Species instances size must be 1")
	assert(colors.size() == 1, "Species colors size must be 1")
	assert(instances[0].origin == Vector3(1.0, 2.0, 3.0), "Transform origin must match")
	assert(colors[0] == c1, "Color must match")
	print(" -> [PASS] FoliageChunkData storage and querying verified")

	# 4. Test BiomeDefinition integration
	var biome_def = _BiomeDefinitionScript.new(
		&"taiga",
		"Taiga",
		null, # ecology
		null, # vegetation
		null, # rocks
		null, # rendering
		profile # foliage
	)
	assert(biome_def.foliage_profile == profile, "BiomeDefinition must hold foliage_profile")
	print(" -> [PASS] BiomeDefinition integration verified")

	print("==================================================")
	print(" ALL FOLIAGE CONTRACTS TESTS PASSED!")
	print("==================================================")
	quit(0)
