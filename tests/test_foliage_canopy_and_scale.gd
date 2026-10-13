extends SceneTree

const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _SpeciesScript = preload("res://src/world_generator/foliage/foliage_species.gd")
const _ProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _CellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("Running test_foliage_canopy_and_scale...")
	var gen := _GeneratorScript.new()
	var sp := _SpeciesScript.new(&"grass", "Grass")
	var prof := _ProfileScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	
	# Test weighted scale distribution (majority small/medium, minority large)
	var small_count := 0
	var total_rolls := 1000
	for i in range(total_rolls):
		var sc: Vector3 = gen.sample_weighted_scale(sp, rng, _ProfileScript.EcologicalZone.PLAINS)
		if sc.y <= sp.scale_max.y * 1.05:
			small_count += 1
	var small_ratio: float = float(small_count) / float(total_rolls)
	assert(small_ratio > 0.50, "Most samples must be small/medium scale, ratio: %f" % small_ratio)
	
	# Test canopy attenuation factor
	var open_cell := _CellScript.new()
	open_cell.forest_density = 0.0
	var forest_cell := _CellScript.new()
	forest_cell.forest_density = 0.9
	
	var atten_open: float = gen.compute_canopy_attenuation(open_cell, 0.0, prof)
	var atten_forest: float = gen.compute_canopy_attenuation(forest_cell, 0.9, prof)
	assert(is_equal_approx(atten_open, 1.0), "Open ground must have 1.0 canopy factor")
	assert(atten_forest < 0.60, "Forest ground must have attenuated foliage density, got: %f" % atten_forest)
	
	print("[PASS] test_foliage_canopy_and_scale")
	quit(0)
