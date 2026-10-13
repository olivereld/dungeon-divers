extends SceneTree

const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _ProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")

func _init() -> void:
	print("Running test_foliage_ecology_contracts...")
	
	# Test FoliageSpecies ScaleCategory
	var sp := _SpeciesScript.new(&"grass_micro", "Micro Grass")
	assert(sp.scale_category == _SpeciesScript.ScaleCategory.MICRO, "Default category must be MICRO")
	assert(sp.scale_weights.has("small") and sp.scale_weights.has("medium") and sp.scale_weights.has("large"), "Must have weighted scale buckets")
	
	# Test FoliageProfile Ecology parameters
	var prof := _ProfileScript.new()
	assert(prof.large_noise_frequency > 0.0, "Must have large_noise_frequency")
	assert(prof.fine_noise_frequency > prof.large_noise_frequency, "Fine noise frequency must be higher than large noise")
	assert(prof.canopy_attenuation_factor >= 0.0 and prof.canopy_attenuation_factor <= 1.0, "Canopy attenuation must be in [0, 1]")
	assert(prof.zone_densities.has(_ProfileScript.EcologicalZone.PLAINS), "Must have PLAINS zone density")
	assert(prof.zone_densities.has(_ProfileScript.EcologicalZone.DENSE_FOREST), "Must have DENSE_FOREST zone density")
	
	print("[PASS] test_foliage_ecology_contracts")
	quit(0)
