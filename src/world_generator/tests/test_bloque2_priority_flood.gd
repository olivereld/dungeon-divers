extends SceneTree

## Contractual test suite for Bloque 2: Priority Flood (Barnes et al. 2014)
## Verifies that:
## 1. PriorityQueue enforces strict deterministic tie-breaking (primary=height, secondary=spatial_key).
## 2. _build_filled_height_field() orders and propagates on raw_height.
## 3. filled_height is a virtual field and does NOT mutate WorldCell.
## 4. Physical mesa (height=4.0) maintains continuous internal hydraulic routing (raw_height ~ 3.xx).
## 5. Priority Flood is 100% deterministic and reproducible across multiple runs.

const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Bloque 2 — Priority Flood")
	print("==================================================")

	_test_priority_queue_tie_breaking()
	_test_priority_flood_mesa_and_immutability()
	_test_priority_flood_depression_filling()
	_test_priority_flood_determinism()

	print("==================================================")
	print(" ALL BLOQUE 2 PRIORITY FLOOD TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_priority_queue_tie_breaking() -> void:
	print("\n[CHECK 1] PriorityQueue Deterministic Tie-Breaking...")
	var pq = _HydrologyStageScript.PriorityQueue.new()

	# Insert multiple items with the same height, in arbitrary order
	pq.push(Vector2i(5, 5), 3.0, 55)
	pq.push(Vector2i(2, 2), 3.0, 22)
	pq.push(Vector2i(9, 9), 3.0, 99)
	pq.push(Vector2i(1, 1), 3.0, 11)
	pq.push(Vector2i(0, 5), 1.5, 5)   # Lower height
	pq.push(Vector2i(8, 8), 4.0, 88)   # Higher height
	pq.push(Vector2i(3, 3), 3.0, 33)

	# 1. First popped must be height 1.5
	var item1 = pq.pop()
	assert(is_equal_approx(item1["height"], 1.5), "Lowest height must pop first")
	assert(item1["spatial_key"] == 5, "Spatial key should match")

	# 2. Next popped must be the height 3.0 items in STRICT order of spatial_key: 11, 22, 33, 55, 99
	var expected_keys: Array[int] = [11, 22, 33, 55, 99]
	for exp_key in expected_keys:
		var it = pq.pop()
		assert(is_equal_approx(it["height"], 3.0), "Height must be 3.0")
		assert(it["spatial_key"] == exp_key, "Ties must be broken deterministically by spatial_key: got %d, expected %d" % [it["spatial_key"], exp_key])

	# 3. Last popped must be height 4.0
	var item_last = pq.pop()
	assert(is_equal_approx(item_last["height"], 4.0), "Highest height must pop last")
	assert(item_last["spatial_key"] == 88)
	assert(pq.is_empty(), "Queue must be empty")
	print("  -> PriorityQueue tie-breaking verified OK.")

func _test_priority_flood_mesa_and_immutability() -> void:
	print("\n[CHECK 2] Priority Flood on Stepped Mesa (raw_height != cell.height)...")
	var stage = _HydrologyStageScript.new()
	var width := 5
	var height := 5
	var cells: Dictionary = {}

	# Create a 5x5 grid representing a physical mesa:
	# cell.height = 4.0 everywhere (Physical Level 1)
	# cell.raw_height has a continuous hydraulic gradient from left to right (3.20 down to 2.80)
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 1
			cell.height = 4.0  # Physical mesa
			cell.raw_height = 3.20 - float(x) * 0.10 - float(y) * 0.02
			cells[pos] = cell

	# Record original cell properties to verify immutability
	var original_heights: Dictionary = {}
	var original_raw_heights: Dictionary = {}
	for pos in cells:
		original_heights[pos] = cells[pos].height
		original_raw_heights[pos] = cells[pos].raw_height

	var flood_data: Dictionary = stage._build_filled_height_field(cells, width, height)
	var filled_height: Dictionary = flood_data["filled"]
	var flood_rank: Dictionary = flood_data["flood_rank"]

	# 1. Verify WorldCell is NEVER mutated
	for pos in cells:
		assert(cells[pos].height == original_heights[pos],
			"WorldCell.height was mutated at %s: %.4f != %.4f" % [str(pos), cells[pos].height, original_heights[pos]])
		assert(cells[pos].raw_height == original_raw_heights[pos],
			"WorldCell.raw_height was mutated at %s: %.4f != %.4f" % [str(pos), cells[pos].raw_height, original_raw_heights[pos]])

	# 2. Verify filled_height is in raw_height space, NOT physical cell.height space
	for pos in cells:
		var fh: float = float(filled_height[pos])
		assert(fh < 3.5, "filled_height must be in raw_height continuous space (~3.xx), not physical height (4.0): pos %s fh=%.4f" % [str(pos), fh])
		assert(fh >= cells[pos].raw_height - 0.0001, "filled_height must be >= raw_height everywhere")

	print("  -> WorldCell immutability and continuous mesa routing verified OK.")

func _test_priority_flood_depression_filling() -> void:
	print("\n[CHECK 3] Priority Flood Depression Filling on raw_height...")
	var stage = _HydrologyStageScript.new()
	var width := 5
	var height := 5
	var cells: Dictionary = {}

	# Create a depression at center (2, 2)
	# Rim at 3.0, center depressed to 1.5 in raw_height
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 1
			cell.height = 4.0
			if x == 2 and y == 2:
				cell.raw_height = 1.5  # Pit / depression
			else:
				cell.raw_height = 3.0  # Rim
			cells[pos] = cell

	var flood_data: Dictionary = stage._build_filled_height_field(cells, width, height)
	var filled: Dictionary = flood_data["filled"]

	# Pit at (2, 2) should be filled to 3.0
	assert(is_equal_approx(float(filled[Vector2i(2, 2)]), 3.0),
		"Pit at (2, 2) must be filled to rim level (3.0), got %.4f" % float(filled[Vector2i(2, 2)]))

	# WorldCell.height at pit must STILL be 4.0, raw_height must STILL be 1.5
	assert(cells[Vector2i(2, 2)].height == 4.0, "Pit cell.height must remain 4.0")
	assert(cells[Vector2i(2, 2)].raw_height == 1.5, "Pit cell.raw_height must remain 1.5")
	print("  -> Depression filling correctly fills virtual field without modifying WorldCell.")

func _test_priority_flood_determinism() -> void:
	print("\n[CHECK 4] Priority Flood 100% Determinism across runs...")
	var stage = _HydrologyStageScript.new()
	var width := 8
	var height := 8
	var cells: Dictionary = {}

	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 2
			cell.height = 8.0
			# Some flat patches with identical raw_height to test tie breaking
			cell.raw_height = 5.0 + float((x + y) % 3) * 0.5
			cells[pos] = cell

	var run1 = stage._build_filled_height_field(cells, width, height)
	var run2 = stage._build_filled_height_field(cells, width, height)

	for pos in cells:
		assert(run1["filled"][pos] == run2["filled"][pos], "filled_height must be strictly identical at %s" % str(pos))
		assert(run1["flood_rank"][pos] == run2["flood_rank"][pos], "flood_rank must be strictly identical at %s" % str(pos))

	print("  -> Determinism verified: 100% identical across independent runs.")
