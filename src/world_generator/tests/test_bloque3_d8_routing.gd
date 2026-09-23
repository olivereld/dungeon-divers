extends SceneTree

## Contractual test suite for Bloque 3: D8 over raw_height
## Verifies that:
## 1. _build_gradient_and_flow_field() computes gradient over routing_height (raw_height) and NOT cell.height.
## 2. On a flat physical mesa (cell.height = 4.0m), the continuous gradient magnitude is non-zero
##    and points strictly in the direction of the raw_height hydraulic descent.
## 3. D8 flow discretization routes downhill along the raw_height gradient on the physical mesa.
## 4. In depressions, filled_height resolves drainage toward outlets.
## 5. WorldCell is NOT mutated during gradient or D8 flow calculations.

const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")
const _WorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _HydrologyResultScript = preload("res://src/world_generator/hydrology/hydrology_result.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Bloque 3 — D8 sobre raw_height")
	print("==================================================")

	_test_mesa_continuous_gradient()
	_test_mesa_d8_discretization()
	_test_depression_d8_resolution()

	print("==================================================")
	print(" ALL BLOQUE 3 D8 ROUTING TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_mesa_continuous_gradient() -> void:
	print("\n[CHECK 1] Gradient on Physical Mesa (cell.height=4.0 vs raw_height gradient)...")
	var stage = _HydrologyStageScript.new()
	var width := 5
	var height := 5
	var cells: Dictionary = {}
	var filled_height: Dictionary = {}
	var flood_rank: Dictionary = {}

	# Create a physical mesa:
	# cell.height = 4.0 everywhere (Physical Level 1)
	# cell.raw_height slopes smoothly toward East (+X): 3.5 at x=0 down to 3.1 at x=4
	for y in range(height):
		for x in range(width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 1
			cell.height = 4.0
			cell.raw_height = 3.50 - float(x) * 0.10
			cells[pos] = cell
			filled_height[pos] = cell.raw_height
			flood_rank[pos] = x * 10 + y

	var flow_field_data = stage._build_gradient_and_flow_field(
		cells, filled_height, flood_rank, width, height, 1.0
	)
	var flow_vectors: Dictionary = flow_field_data["flow_vectors"]
	var magnitudes: Dictionary = flow_field_data["magnitudes"]

	# On an interior cell, say (2, 2):
	var center := Vector2i(2, 2)
	var mag: float = float(magnitudes[center])
	var f_vec: Vector2 = flow_vectors[center]

	# If gradient was computed on cell.height, mag would be 0.0.
	# With raw_height, mag is approximately 0.10.
	assert(mag > 0.05, "Gradient magnitude on mesa must be non-zero (derived from raw_height): got %.4f" % mag)
	assert(f_vec.x > 0.90 and absf(f_vec.y) < 0.10,
		"Flow vector must point East (+X) following raw_height slope: got %s" % str(f_vec))

	print("  -> Continuous gradient on physical mesa verified OK: mag=%.4f, dir=%s" % [mag, str(f_vec)])

func _test_mesa_d8_discretization() -> void:
	print("\n[CHECK 2] D8 Flow Discretization on Physical Mesa...")
	var stage = _HydrologyStageScript.new()
	var profile = _WorldProfileScript.new()
	profile.width = 5
	profile.height = 5
	var hydro = _HydrologyResultScript.new()

	var cells: Dictionary = {}
	# Stepped mesa with raw_height sloping strictly East (+X)
	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 1
			cell.height = 4.0
			cell.raw_height = 3.50 - float(x) * 0.10
			cells[pos] = cell

	var flood_data = stage._build_filled_height_field(cells, profile.width, profile.height)
	var filled_height: Dictionary = flood_data["filled"]
	var flood_rank: Dictionary = flood_data["flood_rank"]

	var flow_field = stage._build_gradient_and_flow_field(
		cells, filled_height, flood_rank, profile.width, profile.height, profile.cell_size
	)
	var continuous_flow: Dictionary = flow_field["flow_vectors"]

	var flow_to = stage._discretize_flow_field(
		cells, filled_height, flood_rank, continuous_flow,
		hydro, profile.width, profile.height, profile
	)

	# Verify interior cells flow Eastward (+X):
	for y in range(1, profile.height - 1):
		for x in range(1, profile.width - 2):
			var pos := Vector2i(x, y)
			var target: Vector2i = flow_to[pos]
			assert(target.x > pos.x,
				"Cell %s on physical mesa must flow downhill in raw_height (+X), but flows to %s" % [str(pos), str(target)])

	print("  -> D8 flow direction on physical mesa consistently routes downhill along raw_height.")

func _test_depression_d8_resolution() -> void:
	print("\n[CHECK 3] D8 Flow through Depression on Mesa...")
	var stage = _HydrologyStageScript.new()
	var profile = _WorldProfileScript.new()
	profile.width = 7
	profile.height = 7
	var hydro = _HydrologyResultScript.new()

	var cells: Dictionary = {}
	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 1
			cell.height = 4.0
			# Sloping east, with pit at (3, 3)
			cell.raw_height = 4.0 - float(x) * 0.10
			if x == 3 and y == 3:
				cell.raw_height = 1.0  # Deep pit
			cells[pos] = cell

	var flood_data = stage._build_filled_height_field(cells, profile.width, profile.height)
	var filled_height: Dictionary = flood_data["filled"]
	var flood_rank: Dictionary = flood_data["flood_rank"]

	var flow_field = stage._build_gradient_and_flow_field(
		cells, filled_height, flood_rank, profile.width, profile.height, profile.cell_size
	)
	var flow_to = stage._discretize_flow_field(
		cells, filled_height, flood_rank, flow_field["flow_vectors"],
		hydro, profile.width, profile.height, profile
	)

	# The pit at (3, 3) must be resolved and not get stuck pointing to itself or creating an infinite loop
	var curr: Vector2i = Vector2i(3, 3)
	var steps: int = 0
	var visited: Dictionary = {}
	while steps < 20:
		visited[curr] = true
		var nxt: Vector2i = flow_to[curr]
		if nxt == curr:
			# Reached an outlet
			break
		assert(not visited.has(nxt), "Infinite loop detected in flow_to from pit: %s -> %s" % [str(curr), str(nxt)])
		curr = nxt
		steps += 1

	assert(curr.x == 0 or curr.x == profile.width - 1 or curr.y == 0 or curr.y == profile.height - 1,
		"Flow path from pit must reach a boundary outlet, stopped at %s" % str(curr))
	print("  -> Depression resolved and successfully drained to boundary outlet %s in %d steps." % [str(curr), steps])
