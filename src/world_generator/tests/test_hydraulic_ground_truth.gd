extends SceneTree

const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _RiverMeshBuilderScript = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _LakeMeshBuilderScript = preload("res://src/world_generator/presentation/water/lake_mesh_builder.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Hydraulic Ground Truth Verification Test")
	print("==================================================")

	var profile = _TaigaWorldProfileScript.new()
	# Test across 3 distinct seeds
	var test_seeds: Array[int] = [12345, 999, 42]

	for s in test_seeds:
		var result = _WorldPipelineScript.generate(s, profile)
		var hydro = result.hydrology
		assert(hydro != null, "Hydrology result must not be null")

		# 1. Verify Lakes Physical Containment on H_carved
		for lake in hydro.lakes:
			var w_h: float = float(lake.get("water_height", 0.0))
			var cells_arr: Array = lake.get("cells", [])
			var lake_set: Dictionary = {}
			for c in cells_arr:
				lake_set[c] = true

			# Check containment rim: all adjacent non-lake cells must have height >= water_height
			var min_rim_h: float = INF
			for pos in cells_arr:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var nb := Vector2i(pos.x + dx, pos.y + dy)
						if nb.x < 0 or nb.x >= profile.width or nb.y < 0 or nb.y >= profile.height:
							continue
						if not lake_set.has(nb):
							if hydro.is_river(nb):
								continue
							var nc = result.get_cell(nb)
							if nc != null:
								min_rim_h = minf(min_rim_h, nc.height)

			assert(w_h <= min_rim_h + 0.001, "Lake %d water level (%.3f) must be <= containment rim (%.3f)" % [
				lake.id, w_h, min_rim_h
			])

			# Every valid lake cell must be submerged (bed < water_h)
			for pos in cells_arr:
				var c = result.get_cell(pos)
				assert(c.height < w_h, "Lake cell %s height (%.3f) must be below water level (%.3f)" % [
					str(pos), c.height, w_h
				])

		# 2. Verify River Water Mesh Anchoring (No floating rivers in the air)
		var river_net = hydro.get_river_network()
		var river_surf = _RiverMeshBuilderScript.build_network_mesh(river_net, result, profile)
		if river_surf != null and not river_surf.vertices.is_empty():
			for v in river_surf.vertices:
				var c_pos := Vector2i(int(floor(v.x)), int(floor(v.z)))
				var c = result.get_cell(c_pos)
				if c != null and not hydro.is_lake(c_pos):
					# Water mesh must never float in the air above natural terrain (H_water <= H_raw + margin)
					# At lake inlets/outlets, water merges with lake water surface
					var max_allowed_h: float = c.raw_height + 0.05
					for dx in range(-2, 3):
						for dy in range(-2, 3):
							var n_pos := Vector2i(c_pos.x + dx, c_pos.y + dy)
							if hydro.is_lake(n_pos):
								var l_data: Dictionary = hydro.get_cell_data(n_pos)
								max_allowed_h = maxf(max_allowed_h, float(l_data.get("water_height", 0.0)) + 0.15)
					var float_diff: float = v.y - max_allowed_h
					assert(float_diff <= 0.001, "River vertex at (%.2f, %.2f) is floating +%.3fm above raw terrain (y=%.3f > allowed=%.3f)" % [
						v.x, v.z, float_diff, v.y, max_allowed_h
					])

	print(" [PASS] 1. Lake Physical Containment on H_carved (w_h <= min_rim_h)")
	print(" [PASS] 2. Submerged Lake Bed Depths (c.height < w_h)")
	print(" [PASS] 3. River Water Anchored to Channel Bed (No floating ribbons)")
	print("==================================================")
	print(" HYDRAULIC GROUND TRUTH TESTS: ALL PASSED!")
	print("==================================================")
	quit(0)
