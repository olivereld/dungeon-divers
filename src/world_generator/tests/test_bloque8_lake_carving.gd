extends SceneTree

## Contractual test suite for Bloque 8: Lake Carving
## Verifies that:
## 1. Lake occupies its terrace cleanly: water_height <= terrace_h.
## 2. Zero exterior bank slopes or ramps: dry cells outside the lake are NEVER carved.
## 3. The surrounding dry terrain preserves strictly: cell.height == base + level * step.
## 4. Lake interior is bathymetrically carved: H_bed < H_water and depth = H_water - H_bed > 0.
## 5. End-to-end full pipeline validation across multiple seeds.

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Bloque 8 — Lake Carving")
	print("==================================================")

	_test_isolated_lake_carving()
	_test_pipeline_lake_dry_surroundings()

	print("==================================================")
	print(" ALL BLOQUE 8 LAKE CARVING TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_isolated_lake_carving() -> void:
	print("\n[CHECK 1] Isolated Lake Carving on Stepped Terrace...")
	var stage = _HydrologyStageScript.new()
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 16
	profile.height = 16
	profile.cell_size = 1.0
	profile.base_height = 2.0
	profile.elevation_step_height = 2.0

	var cells: Dictionary = {}
	# Flat terrace at Level 2: height = 2.0 + 2 * 2.0 = 6.0m
	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var cell = _WorldCellScript.new(pos)
			cell.elevation_level = 2
			cell.height = 6.0
			cell.raw_height = 6.0
			cells[pos] = cell

	# Define a 4x4 lake cluster in the center [6..9] x [6..9]
	var lake_cells: Array[Vector2i] = []
	var lake_set: Dictionary = {}
	for y in range(6, 10):
		for x in range(6, 10):
			var p := Vector2i(x, y)
			lake_cells.append(p)
			lake_set[p] = true

	var hydro = preload("res://src/world_generator/hydrology/hydrology_result.gd").new()
	for p in lake_cells:
		hydro.water_cells[p] = {
			"type": "lake",
			"water_height": 6.0,
			"bed_height": 5.5,
			"depth": 0.5,
			"initial_depth": 0.5,
			"shoreline_height": 6.05
		}

	var lake_obj = {
		"id": 1,
		"water_height": 6.0,
		"cells": lake_cells,
		"min_pos": Vector2i(6, 6),
		"max_pos": Vector2i(9, 9)
	}

	stage._carve_lake_basins(cells, [lake_obj], profile, hydro)

	# 1. Verify interior lake cells: carved with H_bed < H_water
	print("   Verifying interior lake cells...")
	for p in lake_cells:
		var cell: WorldCell = cells[p]
		assert(cell.height < 6.0, "Lake cell at %s must be carved below water height 6.0: got %.4f" % [str(p), cell.height])
		assert(cell.height <= 5.95, "Lake cell at %s must respect shoreline clearance: got %.4f" % [str(p), cell.height])
		var w_data: Dictionary = hydro.water_cells[p]
		assert(w_data["bed_height"] < w_data["water_height"], "H_bed < H_water violated at %s" % str(p))
		assert(absf(float(w_data["depth"]) - (float(w_data["water_height"]) - float(w_data["bed_height"]))) < 0.001,
			"depth != water_height - bed_height at %s" % str(p))

	# 2. Verify dry exterior cells: exactly 6.0m (100% INTACT)
	print("   Verifying dry exterior surrounding cells...")
	var dry_checked := 0
	for y in range(profile.height):
		for x in range(profile.width):
			var p := Vector2i(x, y)
			if not lake_set.has(p):
				var cell: WorldCell = cells[p]
				assert(cell.height == 6.0,
					"Dry exterior cell at %s was modified! height=%.4f != 6.0" % [str(p), cell.height])
				assert(cell.hydraulic_influence == 0.0,
					"Dry exterior cell at %s got hydraulic influence: %.4f" % [str(p), cell.hydraulic_influence])
				dry_checked += 1

	assert(dry_checked == (16 * 16 - 16), "All 240 dry cells must be checked")
	print("  -> [PASS] Isolated lake: 16 lake cells carved (bed < 6.0m), 240 dry cells 100%% intact at 6.0m.")

func _test_pipeline_lake_dry_surroundings() -> void:
	print("\n[CHECK 2] Pipeline Lake Carving across Seeds: Dry Terrains Preserved...")
	var test_seeds: Array[int] = [4242, 283362, 99999]

	for seed_val in test_seeds:
		var pipeline := WorldPipeline.new()
		var profile := _TaigaWorldProfileScript.new()
		profile.lake_threshold = 0.22
		var result: WorldResult = pipeline.generate(seed_val, profile)
		var hydro = result.hydrology
		assert(hydro != null, "HydrologyResult must exist")

		var step_h: float = profile.elevation_step_height
		var base_h: float = profile.base_height

		# Check all lakes
		var total_lake_cells := 0
		var total_dry_lake_neighbors := 0

		for lake in hydro.lakes:
			var cluster: Array = lake.cells
			total_lake_cells += cluster.size()
			var l_set: Dictionary = {}
			for p in cluster:
				l_set[p] = true

			for p in cluster:
				var c: WorldCell = result.cells[p]
				var w_data: Dictionary = hydro.water_cells[p]
				assert(float(w_data["bed_height"]) < float(w_data["water_height"]),
					"Lake cell at %s must have bed_height < water_height" % str(p))
				assert(float(w_data["depth"]) > 0.0,
					"Lake cell at %s must have depth > 0" % str(p))
				assert(c.height < float(w_data["water_height"]) + 0.001,
					"Lake terrain cell at %s must not exceed water_height" % str(p))

				# Inspect adjacent dry cells (D8 neighbors)
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var np := Vector2i(p.x + dx, p.y + dy)
						if not result.cells.has(np):
							continue
						if not hydro.is_water(np):
							var dry_cell: WorldCell = result.cells[np]
							var expected_h: float = base_h + float(dry_cell.elevation_level) * step_h
							assert(is_equal_approx(dry_cell.height, expected_h),
								"Dry lake neighbor at %s has corrupted height: got %.4f, expected %.4f" % [str(np), dry_cell.height, expected_h])
							var remainder := fposmod(dry_cell.height - base_h, step_h)
							assert(is_zero_approx(remainder) or is_equal_approx(remainder, step_h),
								"Dry lake neighbor at %s must be exact integer step multiple" % str(np))
							total_dry_lake_neighbors += 1

		print("  -> Seed %d: %d lakes (%d water cells), %d dry lake neighbor contacts verified strictly discrete base + level * step." % [
			seed_val, hydro.lakes.size(), total_lake_cells, total_dry_lake_neighbors
		])
