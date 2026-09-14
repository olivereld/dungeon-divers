extends SceneTree

const _ClassifierScript = preload("res://src/world_generator/hydrology/hydraulic_basin_classifier.gd")

func _init() -> void:
	print("--- Running test_hydraulic_basin_classifier ---")
	var classifier = _ClassifierScript.new()

	# 1. Local depression test
	var cells: Dictionary = {}
	var filled: Dictionary = {}
	# Create a 5x5 bowl centered at (2, 2)
	for x in range(5):
		for y in range(5):
			var p := Vector2i(x, y)
			var rim_dist: float = maxf(absf(x - 2), absf(y - 2))
			var raw_h: float = 10.0 + rim_dist * 2.0 # center is 10.0, rim is 14.0
			cells[p] = {"raw_height": raw_h}
			filled[p] = 14.0 # filled to rim

	assert(classifier.is_local_depression(Vector2i(2, 2), cells, filled, 0.05) == true, "Center must be local depression")
	assert(classifier.is_local_depression(Vector2i(0, 0), cells, filled, 0.05) == false, "Rim must not be depression")

	# 2. Convergence detection in flat valley
	var active_rivers: Dictionary = {
		Vector2i(2, 1): 0,
		Vector2i(1, 2): 1
	}
	assert(classifier.detect_convergence_zone(active_rivers, Vector2i(2, 2), 0.5, 3) == true, "Adjacent rivers in flat valley must trigger convergence")
	assert(classifier.detect_convergence_zone(active_rivers, Vector2i(2, 2), 15.0, 3) == false, "Steep slope must NOT trigger convergence")

	print("test_hydraulic_basin_classifier: PASSED")
	quit(0)
