extends SceneTree

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("==================================================")
	print(" RUNNING PHASE 18: MULTI-SEED CALIBRATION MATRIX  ")
	print("==================================================")

	var seeds: Array[int] = [1001, 2002, 3003, 4004, 5005]
	var seed_labels: Array[String] = ["Seed A (1001)", "Seed B (2002)", "Seed C (3003)", "Seed D (4004)", "Seed E (5005)"]

	var total_tests_passed := 0
	var total_tests_expected := seeds.size() * 6

	for idx in range(seeds.size()):
		var s: int = seeds[idx]
		var label: String = seed_labels[idx]
		print("\n--- Evaluating %s ---" % label)

		var profile = _TaigaWorldProfileScript.new()
		var result: WorldResult = _WorldPipelineScript.generate(s, profile)

		assert(result != null, "%s: World generation result must not be null" % label)
		assert(result.cells.size() == 128 * 128, "%s: Grid must contain 128x128 cells" % label)

		# 1. Metric Scale Contract & Physical Elevation
		var min_h := INF
		var max_h := -INF
		var flat_count := 0
		var gentle_count := 0
		var steep_count := 0
		var cliff_count := 0
		var forest_count := 0
		var clearing_count := 0

		for cell: WorldCell in result.cells.values():
			if cell.height < min_h: min_h = cell.height
			if cell.height > max_h: max_h = cell.height

			if cell.slope < 10.0: flat_count += 1
			elif cell.slope < 25.0: gentle_count += 1
			elif cell.slope < 35.0: steep_count += 1
			else: cliff_count += 1

			if cell.canopy_zone != WorldCell.CanopyZone.CLEARING: forest_count += 1
			if cell.canopy_zone == WorldCell.CanopyZone.CLEARING: clearing_count += 1

		var total_cells := float(result.cells.size())
		var height_range: float = max_h - min_h
		var flat_pct: float = (float(flat_count) / total_cells) * 100.0
		var cliff_pct: float = (float(cliff_count) / total_cells) * 100.0
		var forest_pct: float = (float(forest_count) / total_cells) * 100.0
		var clearing_pct: float = (float(clearing_count) / total_cells) * 100.0

		print("  [TERRAIN] Elevation Range: %.2fm (Min: %.2fm, Max: %.2fm)" % [height_range, min_h, max_h])
		print("  [SLOPES]  Flat: %.1f%% | Gentle: %.1f%% | Steep: %.1f%% | Cliff: %.1f%%" % [
			flat_pct,
			(float(gentle_count) / total_cells) * 100.0,
			(float(steep_count) / total_cells) * 100.0,
			cliff_pct
		])

		assert(height_range >= 8.0, "%s: Height range must reflect vertical relief (>= 8m)" % label)
		total_tests_passed += 1

		assert(flat_pct >= 35.0, "%s: Flat land (< 10 deg) must be sufficient for gameplay (>= 35%%)" % label)
		assert(cliff_pct <= 12.0, "%s: Cliffs (>= 35 deg) must be rare (<= 12%%)" % label)
		total_tests_passed += 1

		# 2. Ecology & Forest Clustering
		print("  [ECOLOGY] Forest: %.1f%% | Clearings: %.1f%%" % [forest_pct, clearing_pct])
		assert(forest_pct >= 30.0 and forest_pct <= 92.0, "%s: Forest coverage must be balanced (30-92%%)" % label)
		total_tests_passed += 1

		# 3. Hydrology & River Downhill Flow
		var hydro = result.hydrology
		assert(hydro != null, "%s: HydrologyResult must be present" % label)
		var lakes_count: int = hydro.lakes.size()
		var rivers_count: int = hydro.rivers.size()
		var water_coverage: float = (float(hydro.water_cells.size()) / total_cells) * 100.0

		print("  [HYDRO]   Lakes: %d | Rivers: %d | Water Coverage: %.1f%%" % [lakes_count, rivers_count, water_coverage])
		assert(lakes_count >= 1, "%s: Depression lakes must form (>= 1 lake)" % label)
		total_tests_passed += 1

		for r_data in hydro.rivers:
			var pts: Array = r_data["points"]
			for p_i in range(pts.size() - 1):
				var y_curr: float = pts[p_i].y
				var y_next: float = pts[p_i + 1].y
				assert(y_next <= y_curr + 0.001, "%s: River points must obey gravity downhill law (delta Y <= 0)" % label)
		total_tests_passed += 1

		# 4. Gameplay & Traversability
		var walkable_count := 0
		for cell: WorldCell in result.cells.values():
			if cell.is_walkable: walkable_count += 1
		var walkable_ratio: float = float(walkable_count) / total_cells

		print("  [GAMEPLAY] Walkability: %.1f%% | Spawn: %s" % [walkable_ratio * 100.0, str(result.spawn_position)])
		assert(walkable_ratio >= 0.88, "%s: Walkability ratio must be >= 88%%" % label)
		assert(not hydro.is_water(Vector2i(int(result.spawn_position.x), int(result.spawn_position.z))), "%s: Spawn must not be in water" % label)
		total_tests_passed += 1

	print("\n==================================================")
	print(" ALL %d/%d MULTI-SEED CALIBRATION CHECKS PASSED!" % [total_tests_passed, total_tests_expected])
	print("==================================================")
	quit()
