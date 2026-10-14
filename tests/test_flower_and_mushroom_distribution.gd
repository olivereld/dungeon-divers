extends SceneTree

const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _ProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")

func _init() -> void:
	print("Running test_flower_and_mushroom_distribution...")
	var prof := _ProfileScript.new()
	assert(prof.zone_densities[_ProfileScript.EcologicalZone.DENSE_FOREST].has("mushroom"), "DENSE_FOREST must have mushroom weight")
	assert(prof.zone_densities[_ProfileScript.EcologicalZone.CLEARING].has("flower"), "CLEARING must have flower weight")
	assert(prof.zone_densities[_ProfileScript.EcologicalZone.DENSE_FOREST]["mushroom"] > prof.zone_densities[_ProfileScript.EcologicalZone.PLAINS]["mushroom"], "Mushrooms must have higher density in forest than plains")
	assert(prof.zone_densities[_ProfileScript.EcologicalZone.CLEARING]["flower"] > prof.zone_densities[_ProfileScript.EcologicalZone.DENSE_FOREST]["flower"], "Flowers must have higher density in clearings than dense forest")

	# Test ecological species weighting helper
	var gen := _GeneratorScript.new()
	var sp_grass := _SpeciesScript.new(&"grass", "Grass")
	sp_grass.foliage_type = _SpeciesScript.FoliageType.GRASS

	var sp_flower := _SpeciesScript.new(&"flower", "Flower")
	sp_flower.foliage_type = _SpeciesScript.FoliageType.FLOWER
	sp_flower.canopy_preference = -1.0

	var sp_mush := _SpeciesScript.new(&"mushroom", "Mushroom")
	sp_mush.foliage_type = _SpeciesScript.FoliageType.MUSHROOM
	sp_mush.canopy_preference = 1.0

	# In clearing (sunny), flower effective weight should be high, mushroom low
	var w_flower_clearing = gen.compute_species_effective_weight(sp_flower, prof, _ProfileScript.EcologicalZone.CLEARING, 0.05)
	var w_mush_clearing = gen.compute_species_effective_weight(sp_mush, prof, _ProfileScript.EcologicalZone.CLEARING, 0.05)
	assert(w_flower_clearing > w_mush_clearing, "Flowers must dominate clearings over mushrooms")

	# In dense forest (shady), mushroom effective weight should be high, flower low
	var w_flower_dense = gen.compute_species_effective_weight(sp_flower, prof, _ProfileScript.EcologicalZone.DENSE_FOREST, 0.85)
	var w_mush_dense = gen.compute_species_effective_weight(sp_mush, prof, _ProfileScript.EcologicalZone.DENSE_FOREST, 0.85)
	assert(w_mush_dense > w_flower_dense, "Mushrooms must dominate dense forest over flowers")

	print("[PASS] test_flower_and_mushroom_distribution")
	quit(0)
