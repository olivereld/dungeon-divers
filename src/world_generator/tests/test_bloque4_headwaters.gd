extends SceneTree

## Contractual test suite for Bloque 4: Headwaters over raw_height / filled_height
## Verifies that:
## 1. _select_headwaters() evaluates hydraulic slope from raw_height / filled_height, NOT cell.slope.
## 2. On a flat physical mesa (terrain slope = 0°), hydraulic slope is > 0 and contributes to headwater score.
## 3. Cliff edge (terrain slope = 90°) is not artificially boosted by cliff angle.
## 4. Headwater selection is 100% strictly deterministic.

const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")
const _WorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _HydrologyResultScript = preload("res://src/world_generator/hydrology/hydrology_result.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Bloque 4 — Headwaters")
	print("==================================================")

	_test_mesa_headwaters_hydraulic_slope()
	_test_cliff_slope_immunity()
	_test_headwaters_determinism()

	print("==================================================")
	print(" ALL BLOQUE 4 HEADWATERS TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_mesa_headwaters_hydraulic_slope() -> void:
	print("\n[CHECK 1] Headwater scoring on physical mesa (terrain slope = 0° vs hydraulic slope > 0)...")
	var stage = _HydrologyStageScript.new()
	var profile = _WorldProfileScript.new()
	profile.width = 16
	profile.height = 16
	profile.max_rivers = 2
	profile.river_source_min_height = 0.20
	var hydro = _HydrologyResultScript.new()

	var cells: Dictionary = {}
	# Plateau where cell.slope = 0.0 everywhere, but raw_height slopes down to the East
	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 2
			cell.height = 8.0
			cell.slope = 0.0  # Terreno perfectamente plano físicamente
			cell.normalized_height = 0.80
			# Hydraulic slope = 0.06 per cell (approx 3.4 degrees)
			cell.raw_height = 6.00 - float(x) * 0.06
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

	var basins_res = stage._delimit_basins(flow_to, cells, hydro, profile.width, profile.height)
	hydro.basins = basins_res["basins"]
	var cell_basin_map: Dictionary = basins_res["cell_basin_map"]

	var acc_data = stage._compute_flow_accumulation(
		flow_to, cells, hydro, profile.width, profile.height, profile.cell_size
	)
	var accumulation: Dictionary = acc_data["accumulation"]
	var upstream: Dictionary = acc_data["upstream"]

	var headwaters: Array[Vector2i] = stage._select_headwaters(
		cells, flow_to, accumulation, upstream, cell_basin_map,
		hydro.basins, hydro, profile.width, profile.height, profile,
		flow_field["magnitudes"], filled_height
	)

	assert(headwaters.size() > 0, "Mesa must be able to spawn headwaters despite cell.slope == 0.0")
	print("  -> Successfully selected %d headwaters on 0° terrain mesa." % headwaters.size())
	assert(headwaters[0].x <= 3, "Primary headwater must spawn on upstream high ground (west side): got %s" % str(headwaters[0]))

func _test_cliff_slope_immunity() -> void:
	print("\n[CHECK 2] Cliff slope (90°) does not bias headwaters...")
	var stage = _HydrologyStageScript.new()
	var profile = _WorldProfileScript.new()
	profile.width = 16
	profile.height = 16
	var hydro = _HydrologyResultScript.new()

	var cells: Dictionary = {}
	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 1
			cell.height = 4.0
			cell.normalized_height = 0.50
			cell.raw_height = 3.0 - float(x) * 0.02
			# Artificially set cell.slope = 90.0 at some cells to test that it is ignored
			if x == 8:
				cell.slope = 90.0
			else:
				cell.slope = 0.0
			cells[pos] = cell

	var flood_data = stage._build_filled_height_field(cells, profile.width, profile.height)
	var flow_field = stage._build_gradient_and_flow_field(
		cells, flood_data["filled"], flood_data["flood_rank"], profile.width, profile.height, profile.cell_size
	)
	var flow_to = stage._discretize_flow_field(
		cells, flood_data["filled"], flood_data["flood_rank"], flow_field["flow_vectors"],
		hydro, profile.width, profile.height, profile
	)
	var basins_res = stage._delimit_basins(flow_to, cells, hydro, profile.width, profile.height)
	var acc_data = stage._compute_flow_accumulation(
		flow_to, cells, hydro, profile.width, profile.height, profile.cell_size
	)

	var headwaters = stage._select_headwaters(
		cells, flow_to, acc_data["accumulation"], acc_data["upstream"], basins_res["cell_basin_map"],
		basins_res["basins"], hydro, profile.width, profile.height, profile,
		flow_field["magnitudes"], flood_data["filled"]
	)

	# Verify no headwater was selected at x=8 just because of slope=90.0
	for hw in headwaters:
		assert(hw.x != 8, "Cliff edge (slope=90) must not attract headwaters artificially: got %s" % str(hw))
	print("  -> Verified: cliff slope (90°) does not distort headwaters selection.")

func _test_headwaters_determinism() -> void:
	print("\n[CHECK 3] Deterministic headwaters selection...")
	var stage = _HydrologyStageScript.new()
	var profile = _WorldProfileScript.new()
	profile.width = 12
	profile.height = 12
	var hydro = _HydrologyResultScript.new()

	var cells: Dictionary = {}
	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 2
			cell.height = 8.0
			cell.normalized_height = 0.70
			cell.raw_height = 5.0 - float(x) * 0.05 - float(y) * 0.01
			cells[pos] = cell

	var flood_data = stage._build_filled_height_field(cells, profile.width, profile.height)
	var flow_field = stage._build_gradient_and_flow_field(
		cells, flood_data["filled"], flood_data["flood_rank"], profile.width, profile.height, profile.cell_size
	)
	var flow_to = stage._discretize_flow_field(
		cells, flood_data["filled"], flood_data["flood_rank"], flow_field["flow_vectors"],
		hydro, profile.width, profile.height, profile
	)
	var basins_res = stage._delimit_basins(flow_to, cells, hydro, profile.width, profile.height)
	var acc_data = stage._compute_flow_accumulation(
		flow_to, cells, hydro, profile.width, profile.height, profile.cell_size
	)

	var run1 = stage._select_headwaters(
		cells, flow_to, acc_data["accumulation"], acc_data["upstream"], basins_res["cell_basin_map"],
		basins_res["basins"], hydro, profile.width, profile.height, profile,
		flow_field["magnitudes"], flood_data["filled"]
	)
	var run2 = stage._select_headwaters(
		cells, flow_to, acc_data["accumulation"], acc_data["upstream"], basins_res["cell_basin_map"],
		basins_res["basins"], hydro, profile.width, profile.height, profile,
		flow_field["magnitudes"], flood_data["filled"]
	)

	assert(run1.size() == run2.size(), "Headwater counts must match")
	for i in range(run1.size()):
		assert(run1[i] == run2[i], "Headwater %d must match: %s vs %s" % [i, str(run1[i]), str(run2[i])])
	print("  -> Determinism verified: identical headwaters across runs (%s)" % str(run1))
