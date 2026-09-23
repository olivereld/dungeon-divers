extends SceneTree

## Contractual test suite for Bloque 7: River Water Height Hydraulic Policy.
## Verifies:
## 1. Inside a single terrace reach, H_water is strictly constant.
## 2. When changing level (Terrace A -> Terrace B), H_water drops vertically as a cascade.
##    No continuous diagonal water ramps cut across levels.
## 3. Physical invariant: H_bed < H_water and depth > 0 for all river cells.
## 4. Corridor cells on Terrace A receive H_water(A) and on Terrace B receive H_water(B).

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldCellScript = preload("res://src/world_generator/data/world_cell.gd")
const _RiverScript = preload("res://src/world_generator/hydrology/river.gd")
const _HydrologyResultScript = preload("res://src/world_generator/hydrology/hydrology_result.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Bloque 7 — River Water Height")
	print("==================================================")

	_test_synthetic_stepped_river()
	_test_full_generation_seeds([12345, 100, 300, 777, 2024])

	print("==================================================")
	print(" ALL BLOQUE 7 TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_synthetic_stepped_river() -> void:
	print("\n--- Testing Synthetic Stepped River Hydraulic Policy ---")

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 30
	profile.height = 30
	profile.elevation_step_height = 4.0
	profile.base_height = 0.0

	var ctx = _WorldGenerationContextScript.new(1234, profile)
	var stage = _HydrologyStageScript.new()

	# Create a stepped terrain:
	# Rows 0..9: Level 3 (Height 12.0)
	# Rows 10..19: Level 2 (Height 8.0)
	# Rows 20..29: Level 1 (Height 4.0)
	for y in range(30):
		var lvl: int = 3 if y < 10 else (2 if y < 20 else 1)
		for x in range(30):
			var cell = _WorldCellScript.new()
			cell.position = Vector2i(x, y)
			cell.elevation_level = lvl
			cell.height = profile.base_height + float(lvl) * profile.elevation_step_height
			cell.raw_height = cell.height + (30.0 - float(y)) * 0.05
			ctx.result.cells[cell.position] = cell

	# Construct a synthetic river path going straight down column 15:
	# Points y = 5..8 on Level 3 (Reach 0)
	# Points y = 9..18 on Level 2 (Reach 1)
	# Points y = 19..25 on Level 1 (Reach 2)
	var path: Array[Vector2i] = []
	for y in range(5, 26):
		path.append(Vector2i(15, y))

	var river_obj = _RiverScript.new()
	river_obj.id = 1
	river_obj.path = path
	river_obj.order = 1
	river_obj.is_outflow = false
	river_obj.downstream_river = -1

	var accumulation: Dictionary = {}
	for i in range(path.size()):
		accumulation[path[i]] = 10.0 + float(i) * 5.0

	var hydro = _HydrologyResultScript.new()

	# Call _build_river_geometry
	var river_dict: Dictionary = stage._build_river_geometry(
		river_obj, accumulation, ctx.result.cells, profile, hydro, null, 200.0
	)

	# Verify 1: Constant H_water within each terrace reach along path
	print("  [CHECK] 1. Constant H_water within terrace reaches...")
	var reach_0_wh: float = -1.0
	var reach_1_wh: float = -1.0
	var reach_2_wh: float = -1.0

	for pos in path:
		assert(hydro.water_cells.has(pos), "Path cell %s must be in water_cells" % str(pos))
		var w_data: Dictionary = hydro.water_cells[pos]
		var wh: float = float(w_data["water_height"])
		var bh: float = float(w_data["bed_height"])
		var d: float = float(w_data["depth"])
		var lvl: int = ctx.result.cells[pos].elevation_level

		# Hydraulic invariant
		assert(bh < wh, "Invariant H_bed < H_water violated at %s: bh=%.4f, wh=%.4f" % [str(pos), bh, wh])
		assert(d > 0.0, "Depth must be positive at %s" % str(pos))
		assert(absf(d - (wh - bh)) < 0.001, "Depth == wh - bh invariant at %s" % str(pos))

		if lvl == 3:
			if reach_0_wh < 0.0:
				reach_0_wh = wh
			else:
				assert(absf(wh - reach_0_wh) < 0.0001, "Level 3 reach water height must be strictly constant! Got %.4f vs %.4f" % [wh, reach_0_wh])
		elif lvl == 2:
			if reach_1_wh < 0.0:
				reach_1_wh = wh
			else:
				assert(absf(wh - reach_1_wh) < 0.0001, "Level 2 reach water height must be strictly constant! Got %.4f vs %.4f" % [wh, reach_1_wh])
		elif lvl == 1:
			if reach_2_wh < 0.0:
				reach_2_wh = wh
			else:
				assert(absf(wh - reach_2_wh) < 0.0001, "Level 1 reach water height must be strictly constant! Got %.4f vs %.4f" % [wh, reach_2_wh])

	print("    Reach Level 3 wh = %.4f" % reach_0_wh)
	print("    Reach Level 2 wh = %.4f" % reach_1_wh)
	print("    Reach Level 1 wh = %.4f" % reach_2_wh)

	# Verify 2: Vertical cascade drops between reaches (No ramps!)
	print("  [CHECK] 2. Vertical cascade step drops between reaches...")
	assert(reach_0_wh > reach_1_wh + 2.0, "Cascade drop from Level 3 to Level 2 must be significant (>= 2m): %.4f -> %.4f" % [reach_0_wh, reach_1_wh])
	assert(reach_1_wh > reach_2_wh + 2.0, "Cascade drop from Level 2 to Level 1 must be significant (>= 2m): %.4f -> %.4f" % [reach_1_wh, reach_2_wh])

	# Verify 3: Corridor rasterization adheres to discrete terrace heights
	print("  [CHECK] 3. Corridor cells have discrete terrace water heights (no diagonal ramp values)...")
	for c_pos in hydro.water_cells:
		var w_data: Dictionary = hydro.water_cells[c_pos]
		var wh: float = float(w_data["water_height"])
		var cell: WorldCell = ctx.result.cells[c_pos]
		var lvl: int = cell.elevation_level

		if lvl == 3:
			assert(absf(wh - reach_0_wh) < 0.001, "Corridor cell at %s (lvl 3) must match reach_0_wh: %.4f vs %.4f" % [str(c_pos), wh, reach_0_wh])
		elif lvl == 2:
			assert(absf(wh - reach_1_wh) < 0.001, "Corridor cell at %s (lvl 2) must match reach_1_wh: %.4f vs %.4f" % [str(c_pos), wh, reach_1_wh])
		elif lvl == 1:
			assert(absf(wh - reach_2_wh) < 0.001, "Corridor cell at %s (lvl 1) must match reach_2_wh: %.4f vs %.4f" % [str(c_pos), wh, reach_2_wh])

	print("   -> [PASS] Synthetic stepped river satisfies constant water height per terrace and cascade drops!")

func _test_full_generation_seeds(seeds: Array[int]) -> void:
	print("\n--- Testing Full Generation Pipeline Seeds ---")

	var terrain_stage = _TerrainStageScript.new()
	var hydro_stage = _HydrologyStageScript.new()

	for seed_val in seeds:
		print("  Seed: %d..." % seed_val)
		var profile = _TaigaWorldProfileScript.new()
		profile.width = 64
		profile.height = 64
		profile.hydrology_enabled = true
		profile.max_rivers = 3

		var ctx = _WorldGenerationContextScript.new(seed_val, profile)
		terrain_stage.execute(ctx)
		hydro_stage.execute(ctx)

		var hydro: HydrologyResult = ctx.result.hydrology
		if hydro.rivers.is_empty():
			print("    (No rivers in seed %d, skipping)" % seed_val)
			continue

		for river in hydro.rivers:
			var path: Array = river.get("path", [])
			var levels: Array = river.get("levels", [])
			if path.is_empty():
				continue

			# Group path cells by reach level into contiguous reaches
			var current_lvl: int = -1
			var current_wh: float = -1.0
			var r_id: int = river.get("id", -1)
			for i in range(path.size()):
				var pos: Vector2i = path[i]
				if hydro.is_lake(pos) or not hydro.water_cells.has(pos):
					current_lvl = -1
					current_wh = -1.0
					continue

				var w_data: Dictionary = hydro.water_cells[pos]
				var cell_r_id: int = int(w_data.get("river_index", -1))
				if cell_r_id != -1 and cell_r_id != r_id:
					# Once the river path merges into an existing downstream river,
					# that river governs the water height at the confluence.
					break

				var lvl: int = levels[i] if i < levels.size() else ctx.result.cells[pos].elevation_level
				var wh: float = float(hydro.water_cells[pos]["water_height"])
				var bh: float = float(hydro.water_cells[pos]["bed_height"])

				assert(bh < wh, "H_bed < H_water invariant violated at %s: bh=%.4f, wh=%.4f" % [str(pos), bh, wh])

				if lvl == current_lvl:
					assert(absf(wh - current_wh) < 0.001,
						"Path cells on same terrace reach (level %d) must have identical water_height: %.4f vs %.4f at %s" % [lvl, wh, current_wh, str(pos)])
				else:
					if current_lvl != -1:
						# When dropping to a lower level, water height must not rise
						assert(wh <= current_wh + 0.001,
							"Downstream river water height rose at level change! from %.4f (lvl %d) to %.4f (lvl %d) at %s" % [current_wh, current_lvl, wh, lvl, str(pos)])
					current_lvl = lvl
					current_wh = wh

		print("    -> OK: All rivers in seed %d verified with constant terrace H_water!" % seed_val)
