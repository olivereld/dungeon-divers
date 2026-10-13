extends SceneTree

const _GeneratorScript = preload("res://src/world_generator/foliage/foliage_generator.gd")
const _ProfileScript = preload("res://src/world_generator/foliage/foliage_profile.gd")
const _CellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("Running test_foliage_patch_sampling...")
	var gen := _GeneratorScript.new()
	var prof := _ProfileScript.new()
	
	# Test Plains Cell (low forest density, high clearing)
	var plains_cell := _CellScript.new(Vector2i(10, 10))
	plains_cell.forest_density = 0.02
	plains_cell.clearing_density = 0.8
	var zone_plains: int = gen.evaluate_ecological_zone(plains_cell, 0.5)
	assert(zone_plains == _ProfileScript.EcologicalZone.PLAINS or zone_plains == _ProfileScript.EcologicalZone.CLEARING, "Must evaluate to plains/clearing")
	
	# Test Dense Forest Cell (high forest density, low clearing)
	var forest_cell := _CellScript.new(Vector2i(20, 20))
	forest_cell.forest_density = 0.85
	forest_cell.clearing_density = 0.05
	var zone_forest: int = gen.evaluate_ecological_zone(forest_cell, 0.5)
	assert(zone_forest == _ProfileScript.EcologicalZone.DENSE_FOREST, "Must evaluate to dense forest")
	
	# Test Patch Coverage smoothly combines large and fine noise
	var cov1: float = gen.evaluate_patch_coverage_at(Vector2i(5, 5), 12345, prof)
	var cov2: float = gen.evaluate_patch_coverage_at(Vector2i(5, 5), 12345, prof)
	assert(is_equal_approx(cov1, cov2), "Patch coverage must be strictly deterministic")
	assert(cov1 >= 0.0 and cov1 <= 1.0, "Patch coverage must be normalized [0, 1]")
	
	print("[PASS] test_foliage_patch_sampling")
	quit(0)
