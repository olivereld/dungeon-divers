extends SceneTree

const PropFootprintScript = preload("res://src/presentation/props/prop_footprint.gd")

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("==================================================================")
	print("--- Running test_decoration_composition_rotation ---")
	print("==================================================================")

	var fp_2x1 := PropFootprintScript.new(Vector2i(2, 1))
	var origin := Vector2i(10, 10)

	# 1. Rotación 0° (Horizontal hacia +X)
	var cells_0 = fp_2x1.get_occupied_cells(origin, 0.0)
	assert(cells_0.size() == 2, "FAIL: Expected 2 cells")
	assert(cells_0.has(Vector2i(10, 10)) and cells_0.has(Vector2i(11, 10)), "FAIL: 0° footprint mismatch")
	print("  [OK] Footprint 2x1 at 0°: %s" % str(cells_0))

	# 2. Rotación 90° (Vertical hacia -Y)
	var cells_90 = fp_2x1.get_occupied_cells(origin, 90.0)
	assert(cells_90.size() == 2, "FAIL: Expected 2 cells")
	assert(cells_90.has(Vector2i(10, 10)) and cells_90.has(Vector2i(10, 9)), "FAIL: 90° footprint mismatch")
	print("  [OK] Footprint 2x1 at 90°: %s" % str(cells_90))

	# 3. Rotación 180° (Horizontal hacia -X)
	var cells_180 = fp_2x1.get_occupied_cells(origin, 180.0)
	assert(cells_180.size() == 2, "FAIL: Expected 2 cells")
	assert(cells_180.has(Vector2i(10, 10)) and cells_180.has(Vector2i(9, 10)), "FAIL: 180° footprint mismatch")
	print("  [OK] Footprint 2x1 at 180°: %s" % str(cells_180))

	# 4. Rotación 270° (Vertical hacia +Y)
	var cells_270 = fp_2x1.get_occupied_cells(origin, 270.0)
	assert(cells_270.size() == 2, "FAIL: Expected 2 cells")
	assert(cells_270.has(Vector2i(10, 10)) and cells_270.has(Vector2i(10, 11)), "FAIL: 270° footprint mismatch")
	print("  [OK] Footprint 2x1 at 270°: %s" % str(cells_270))

	print("[PASS] test_decoration_composition_rotation completed successfully!")
	quit(0)
