extends SceneTree

## Contractual test suite for BLOQUE 7: Water Height Policy & Single Source of Truth.
##
## Objectives:
## 1. Single physical rule: water_cells[pos]["water_height"] = H_water.
## 2. Lakes: 100% planar horizontal surface (variance == 0.0).
## 3. Rivers: Monotonically non-increasing downstream (no uphill flow).
## 4. Confluences: C0 continuity between tributary and receiving river.
## 5. Lake Mouths & Outflows: C0 continuity with lake spillway/surface.
## 6. Universal Physical Invariant: H_water >= H_bed, depth = H_water - H_bed, all finite.
## 7. WaterMeshBuilder directly consumes water_height for vertex Y coordinates.

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Water Height Policy (Bloque 7)")
	print("==================================================")

	var test_seeds: Array[int] = [4242, 12345, 283362, 99999]

	for seed_val in test_seeds:
		_test_seed(seed_val)

	print("==================================================")
	print(" ALL BLOQUE 7 WATER HEIGHT POLICY TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_seed(seed_val: int) -> void:
	print("\n--- Testing Seed: %d ---" % seed_val)

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.cell_size = 2.0
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.22
	profile.max_rivers = 4
	profile.min_river_length = 6.0

	var ctx = _WorldGenerationContextScript.new(seed_val, profile)
	var terrain_stage = _TerrainStageScript.new()
	terrain_stage.execute(ctx)

	var hydro_stage = _HydrologyStageScript.new()
	hydro_stage.execute(ctx)

	var result: WorldResult = ctx.result
	var hydro: HydrologyResult = result.hydrology

	print("  Hydrology: %d lakes, %d rivers, %d confluences, %d water cells" % [
		hydro.lakes.size(), hydro.rivers.size(), hydro.confluences.size(), hydro.water_cells.size()
	])

	# -------------------------------------------------------------------------
	# CHECK 1: Lakes are 100% Planar (H_water == spillway_height across all cells)
	# -------------------------------------------------------------------------
	print("  [CHECK 1] Lake Horizontal Planarity...")
	for lake in hydro.lakes:
		var lake_id: int = lake["id"]
		var spillway_h: float = float(lake["spillway_height"])
		var cells: Array = lake["cells"]
		for pos in cells:
			assert(hydro.water_cells.has(pos), "Lake cell %s must be in water_cells" % str(pos))
			var w_h: float = float(hydro.water_cells[pos]["water_height"])
			var diff: float = absf(w_h - spillway_h)
			assert(diff < 0.0001, "Lake %d cell %s has w_h=%.5f != spillway=%.5f (diff=%.6f)" % [
				lake_id, str(pos), w_h, spillway_h, diff
			])
	print("    All %d lakes verified 100%% planar!" % hydro.lakes.size())

	# -------------------------------------------------------------------------
	# CHECK 2: Rivers have Monotonic Non-Increasing Water Surface (no uphill flow)
	# -------------------------------------------------------------------------
	print("  [CHECK 2] River Downhill Monotonicity...")
	for river in hydro.rivers:
		var r_id: int = river["id"]
		var path: Array = river["path"]
		var prev_wh: float = INF
		for i in range(path.size()):
			var pos: Vector2i = path[i]
			if hydro.water_cells.has(pos):
				var wh: float = float(hydro.water_cells[pos]["water_height"])
				assert(wh <= prev_wh + 0.0001, "River %d idx %d pos %s: ascent detected! wh=%.4f > prev=%.4f" % [
					r_id, i, str(pos), wh, prev_wh
				])
				prev_wh = wh
	print("    All %d rivers verified monotonically non-increasing downstream!" % hydro.rivers.size())

	# -------------------------------------------------------------------------
	# CHECK 3: Confluence Elevation Continuity (C0)
	# -------------------------------------------------------------------------
	print("  [CHECK 3] Confluence C0 Elevation Continuity...")
	for conf in hydro.confluences:
		var pos: Vector2i = conf["position"]
		var down_id: int = conf["downstream_river"]
		var up_ids: Array = conf["upstream_rivers"]
		assert(hydro.water_cells.has(pos), "Confluence pos %s must be in water_cells" % str(pos))
		var conf_wh: float = float(hydro.water_cells[pos]["water_height"])
		for up_id in up_ids:
			for r in hydro.rivers:
				if r["id"] == up_id:
					var tributary_path: Array = r["path"]
					var last_pos: Vector2i = tributary_path[-1]
					var last_wh: float = float(hydro.water_cells[last_pos]["water_height"])
					var diff: float = absf(last_wh - conf_wh)
					assert(diff < 0.0001, "Confluence at %s: tributary %d wh=%.4f != conf wh=%.4f (diff=%.6f)" % [
						str(pos), up_id, last_wh, conf_wh, diff
					])
	print("    All %d confluences verified with exact C0 elevation matching!" % hydro.confluences.size())

	# -------------------------------------------------------------------------
	# CHECK 4: Lake Mouths and Spillway Outflows C0 Continuity
	# -------------------------------------------------------------------------
	print("  [CHECK 4] Lake Inflow / Outflow C0 Continuity...")
	for river in hydro.rivers:
		var path: Array = river["path"]
		# River entering lake:
		var mouth_pos: Vector2i = path[-1]
		if hydro.is_lake(mouth_pos):
			var lake_data: Dictionary = hydro.get_cell_data(mouth_pos)
			var lake_wh: float = float(lake_data.get("water_height", -999.0))
			var river_wh: float = float(hydro.water_cells[mouth_pos]["water_height"])
			assert(absf(river_wh - lake_wh) < 0.0001, "Lake mouth %s: river_wh=%.4f != lake_wh=%.4f" % [
				str(mouth_pos), river_wh, lake_wh
			])
		# River exiting lake (spillway):
		if river.get("is_outflow", false):
			var source_pos: Vector2i = path[0]
			if hydro.is_lake(source_pos):
				var lake_data: Dictionary = hydro.get_cell_data(source_pos)
				var lake_wh: float = float(lake_data.get("water_height", -999.0))
				var source_wh: float = float(hydro.water_cells[source_pos]["water_height"])
				assert(absf(source_wh - lake_wh) < 0.0001, "Lake outflow %s: source_wh=%.4f != lake_wh=%.4f" % [
					str(source_pos), source_wh, lake_wh
				])
	print("    Lake inlet and outlet C0 continuity verified!")

	# -------------------------------------------------------------------------
	# CHECK 5: Universal Physical Invariant (H_water >= H_bed, depth = H_water - H_bed, finite)
	# -------------------------------------------------------------------------
	print("  [CHECK 5] Universal Hydraulic Physical Invariant...")
	for pos in hydro.water_cells:
		var cell_data: Dictionary = hydro.water_cells[pos]
		var w_h: float = float(cell_data.get("water_height", NAN))
		var b_h: float = float(cell_data.get("bed_height", NAN))
		var depth: float = float(cell_data.get("depth", NAN))

		assert(is_finite(w_h), "Water cell %s water_height must be finite" % str(pos))
		assert(is_finite(b_h), "Water cell %s bed_height must be finite" % str(pos))
		assert(is_finite(depth), "Water cell %s depth must be finite" % str(pos))

		assert(w_h >= b_h - 0.0001, "Water cell %s: w_h=%.4f < b_h=%.4f" % [str(pos), w_h, b_h])
		var computed_depth: float = w_h - b_h
		assert(absf(computed_depth - depth) < 0.001, "Water cell %s: depth=%.4f != w_h - b_h = %.4f" % [
			str(pos), depth, computed_depth
		])
	print("    All %d water cells satisfy H_water >= H_bed and depth = H_water - H_bed!" % hydro.water_cells.size())

	# -------------------------------------------------------------------------
	# CHECK 6: WaterMeshBuilder Directly Consumes water_height
	# -------------------------------------------------------------------------
	print("  [CHECK 6] WaterMeshBuilder Direct Consumption...")
	var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(result, profile)
	assert(surf != null, "WaterSurfaceData must not be null")
	var v_count: int = surf.vertices.size()
	assert(v_count > 0, "WaterSurfaceData must contain vertices")

	# Find global min and max water_height
	var min_wh: float = INF
	var max_wh: float = -INF
	for pos in hydro.water_cells:
		var wh: float = float(hydro.water_cells[pos]["water_height"])
		if wh < min_wh:
			min_wh = wh
		if wh > max_wh:
			max_wh = wh

	for i in range(v_count):
		var v_pos: Vector3 = surf.vertices[i]
		assert(is_finite(v_pos.y), "Vertex %d Y must be finite" % i)
		assert(v_pos.y >= min_wh - 0.001 and v_pos.y <= max_wh + 0.001,
			"Vertex %d Y=%.4f outside [min_wh=%.4f, max_wh=%.4f]" % [i, v_pos.y, min_wh, max_wh]
		)
	print("    All %d vertices verified bounded by water_cells water_height!" % v_count)
