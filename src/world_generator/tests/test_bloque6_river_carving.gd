extends SceneTree

## Contractual test suite for Bloque 6: Redesigned River Carving
## Verifies that:
## 1. Dry exterior cells (dist_m > cur_w_river) are NEVER carved: cell.height remains 100% intact.
## 2. Bank influence does NOT erode or ramp down dry terraces/cliffs.
## 3. Effective channel cells (dist_m <= cur_w_river) are excavated with H_bed < H_water.
## 4. Vertical cliffs adjacent to water remain vertical cliffs unless the channel cuts through them.

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Bloque 6 — Redesigned River Carving")
	print("==================================================")

	_test_effective_channel_carving_rule()
	_test_cliff_preservation_adjacent_to_river()

	print("==================================================")
	print(" ALL BLOQUE 6 RIVER CARVING TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_effective_channel_carving_rule() -> void:
	print("\n[CHECK 1] Effective channel vs dry exterior cells...")
	var stage = _HydrologyStageScript.new()
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 16
	profile.height = 16
	profile.cell_size = 1.0

	var cells: Dictionary = {}
	# Stepped terrain: Level 2 (8.0m)
	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 2
			cell.height = 8.0
			cell.raw_height = 8.0
			cells[pos] = cell

	# Record original heights
	var original_heights: Dictionary = {}
	for pos in cells:
		original_heights[pos] = cells[pos].height

	# Define a straight river from (2, 8) to (14, 8) with water_y = 7.5, width = 2.0 (radius = 1.0)
	var river = {
		"id": 1,
		"points": [Vector3(2.0, 7.5, 8.0), Vector3(14.0, 7.5, 8.0)],
		"widths": [2.0, 2.0],
		"depths": [0.5, 0.5]
	}

	var hydro = preload("res://src/world_generator/hydrology/hydrology_result.gd").new()
	stage._carve_river_channels(cells, [river], {}, profile, hydro, false, Rect2i(0, 0, 16, 16))

	# Verify:
	# 1. Cells with y == 8 (centerline, dist_m == 0 <= 1.0): MUST be carved down
	var center_pos := Vector2i(8, 8)
	assert(cells[center_pos].height < 7.5, "Centerline cell must be carved below water level: %.4f" % cells[center_pos].height)
	assert(cells[center_pos].height >= 6.70, "Centerline cell bed must respect depth: %.4f" % cells[center_pos].height)

	# 2. Cells with |y - 8| >= 2 (e.g. y == 6, 10, dist_m >= 2.0 > 1.0): MUST be 100% INTACT
	var dry_cells_checked := 0
	for y in range(profile.height):
		for x in range(2, 15):
			var pos := Vector2i(x, y)
			if abs(y - 8) >= 2:
				assert(cells[pos].height == 8.0,
					"Dry exterior cell at %s was carved! height=%.4f != 8.0" % [str(pos), cells[pos].height])
				dry_cells_checked += 1

	assert(dry_cells_checked > 50, "Should have verified dry cells")
	print("  -> Verified: %d dry exterior cells remained 100%% intact (8.0m). Centerline carved to %.4fm." % [dry_cells_checked, cells[center_pos].height])

func _test_cliff_preservation_adjacent_to_river() -> void:
	print("\n[CHECK 2] Stepped Cliff preservation adjacent to river (Level 3 vs Level 2)...")
	var stage = _HydrologyStageScript.new()
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 16
	profile.height = 16
	profile.cell_size = 1.0

	var cells: Dictionary = {}
	# Stepped world:
	# x < 8: Level 3 (height = 12.0m)
	# x >= 8: Level 2 (height = 8.0m)
	# Vertical cliff at border between x=7 and x=8 (delta = 4.0m)
	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			if x < 8:
				cell.elevation_level = 3
				cell.height = 12.0
				cell.raw_height = 12.0
			else:
				cell.elevation_level = 2
				cell.height = 8.0
				cell.raw_height = 8.0
			cells[pos] = cell

	# River running West to East across the cliff at y=8, cutting through the step
	var river = {
		"id": 1,
		"points": [Vector3(2.0, 7.5, 8.0), Vector3(14.0, 7.5, 8.0)],
		"widths": [2.0, 2.0],
		"depths": [0.5, 0.5]
	}

	var hydro = preload("res://src/world_generator/hydrology/hydrology_result.gd").new()
	stage._carve_river_channels(cells, [river], {}, profile, hydro, false, Rect2i(0, 0, 16, 16))

	# 1. At y=4 (4m away from river): Level 3 cliff at x=7 and Level 2 at x=8 MUST BE 100% INTACT
	assert(cells[Vector2i(7, 4)].height == 12.0, "Dry cliff on Level 3 must remain 12.0m: %.4f" % cells[Vector2i(7, 4)].height)
	assert(cells[Vector2i(8, 4)].height == 8.0, "Dry cliff on Level 2 must remain 8.0m: %.4f" % cells[Vector2i(8, 4)].height)
	var step_at_y4: float = cells[Vector2i(7, 4)].height - cells[Vector2i(8, 4)].height
	assert(is_equal_approx(step_at_y4, 4.0), "Cliff step at y=4 must remain 4.0m, got %.4f" % step_at_y4)

	# 2. At y=8 (inside channel): Both sides carved down to form river channel
	var h_river_l3: float = cells[Vector2i(7, 8)].height
	var h_river_l2: float = cells[Vector2i(8, 8)].height
	assert(h_river_l3 < 7.5, "River channel cut through Level 3: %.4f" % h_river_l3)
	assert(h_river_l2 < 7.5, "River channel cut through Level 2: %.4f" % h_river_l2)

	print("  -> Verified: Cliff at y=4 remained a full 4.0m vertical step (12.0m -> 8.0m) without bank erosion.")
	print("  -> Verified: River channel at y=8 successfully excavated both terraces to %.4fm and %.4fm." % [h_river_l3, h_river_l2])
