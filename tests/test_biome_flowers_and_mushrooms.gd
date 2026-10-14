extends SceneTree

const _BiomeRegistryScript = preload("res://src/world_generator/biomes/biome_registry.gd")
const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")

func _init() -> void:
	print("Running test_biome_flowers_and_mushrooms...")
	var reg = _BiomeRegistryScript.get_default()
	
	# Taiga
	var taiga = reg.get_definition(&"taiga")
	assert(taiga != null and taiga.foliage_profile != null, "Taiga foliage profile must exist")
	var has_amanita := false
	var has_flower := false
	for sp in taiga.foliage_profile.species:
		if sp.foliage_type == _SpeciesScript.FoliageType.MUSHROOM:
			has_amanita = true
		if sp.foliage_type == _SpeciesScript.FoliageType.FLOWER:
			has_flower = true
	assert(has_amanita, "Taiga must include mushroom species")
	assert(has_flower, "Taiga must include flower species")

	# Temperate Forest
	var forest = reg.get_definition(&"temperate_forest")
	var forest_mush := false
	var forest_flower := false
	for sp in forest.foliage_profile.species:
		if sp.foliage_type == _SpeciesScript.FoliageType.MUSHROOM:
			forest_mush = true
		if sp.foliage_type == _SpeciesScript.FoliageType.FLOWER:
			forest_flower = true
	assert(forest_mush and forest_flower, "Temperate forest must include both mushrooms and flowers")

	print("[PASS] test_biome_flowers_and_mushrooms")
	quit(0)
