extends SceneTree

const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _HydrologyRendererScript = preload("res://src/world_renderer/hydrology_renderer.gd")
const _TerrainColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")
const _WatershedIntegrityCheckerScript = preload("res://src/world_generator/diagnostics/watershed_integrity_checker.gd")
const _OutletValidatorScript = preload("res://src/world_generator/diagnostics/outlet_validator.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Hydrology & Separation of Concerns Tests")
	print("==================================================")

	var profile := TaigaWorldProfile.new()
	profile.width = 128
	profile.height = 128
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.25
	profile.max_rivers = 3
	profile.min_river_length = 10.0

	var result := WorldPipeline.generate(4242, profile)
	assert(result != null, "Result must not be null")
	assert(result.hydrology != null, "HydrologyResult must be populated")

	var hydro = result.hydrology

	# 1. Test Separation: Zero Blue in Terrain Mesh
	print(" [CHECK] 1. Terrain Substrate Purity (No water/sand in terrain albedo)...")
	for y in range(profile.height):
		for x in range(profile.width):
			var cell := result.get_cell(Vector2i(x, y))
			var col: Color = _TerrainColorResolverScript.resolve_vertex_color(cell, profile)
			# Terrain colors must be boreal land substrates (greens, earth browns, grays, whites)
			# Dominant blue tint (b > r + 0.1 and b > g + 0.1) is strictly forbidden on land vertices
			assert(not (col.b > col.r + 0.15 and col.b > col.g + 0.15), "Terrain vertex at (%d, %d) must not be blue water!" % [x, y])

	# 2. Test Planar Horizontal Lakes
	print(" [CHECK] 2. Lake Planarity & Sinks (Flat horizontal water planes)...")
	print("   Lakes detected: %d" % hydro.lakes.size())
	for lake in hydro.lakes:
		var lake_h: float = lake.water_height
		assert(lake.cells.size() >= 4, "Lakes must have at least 4 contiguous cells")
		for c_pos in lake.cells:
			var c_data: Dictionary = hydro.get_cell_data(c_pos)
			assert(c_data["type"] == "lake", "Cell must be classified as lake")
			assert(is_equal_approx(c_data["water_height"], lake_h), "All lake cells must share planar spillway height")
			assert(c_data["water_height"] >= c_data["terrain_height"] - 0.001, "Water must be at or above depression floor")
			assert(c_data["depth"] >= 0.0, "Depth must be non-negative")

	# H11: Lake accumulation must propagate downstream of spillway
	print(" [CHECK] H11. Lake Contribution Propagates Downstream...")
	for lake in hydro.lakes:
		var spill_pos: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		if not result.cells.has(spill_pos) or hydro.is_lake(spill_pos):
			continue
		var lake_cells: Array = lake.get("cells", [])
		var lake_area: float = float(lake_cells.size())
		var spill_acc: float = hydro.get_debug_value("drainage", spill_pos, 0.0)
		assert(spill_acc >= lake_area, "H11: Spillway at %s must have accumulation >= lake area (%d), got %.1f" % [str(spill_pos), lake_cells.size(), spill_acc])

	# H12: D8 determinism — no cycles, no uphill flow
	print(" [CHECK] H12. D8 Flow Determinism (no cycles, no uphill)...")
	var flow_dir_grid: Dictionary = hydro.debug_layers.get("flow_dir", {})
	assert(not flow_dir_grid.is_empty(), "H12: flow_dir debug layer must exist")
	var sample_pos := Vector2i(64, 64)
	if hydro.is_water(sample_pos):
		sample_pos = Vector2i(32, 32)
	var visited_chain: Dictionary = {}
	var chain_pos: Vector2i = sample_pos
	for _step in range(profile.width * profile.height + 1):
		assert(not visited_chain.has(chain_pos), "H12: D8 cycle detected at %s" % str(chain_pos))
		visited_chain[chain_pos] = true
		var dir_vec: Vector2 = flow_dir_grid.get(chain_pos, Vector2.ZERO)
		if dir_vec == Vector2.ZERO:
			break
		var next_pos := chain_pos + Vector2i(int(round(dir_vec.x)), int(round(dir_vec.y)))
		if next_pos == chain_pos:
			break
		chain_pos = next_pos

	# H13: Upstream reverse graph must be consistent with flow_to
	print(" [CHECK] H13. Upstream Reverse Graph Consistency...")
	assert(hydro.has_debug_layer("flow_to"), "H13: flow_to must be exposed as debug layer")

	# H15: No duplicate edges across rendered river paths
	print(" [CHECK] H15. No Duplicate River Edges...")
	var rendered_edges: Dictionary = {}
	var duplicate_count: int = 0
	for river in hydro.rivers:
		var river_cells: Array = river.get("cells", [])
		for i in range(river_cells.size() - 1):
			var edge_key: String = "%d,%d->%d,%d" % [river_cells[i].x, river_cells[i].y, river_cells[i + 1].x, river_cells[i + 1].y]
			if rendered_edges.has(edge_key):
				duplicate_count += 1
			rendered_edges[edge_key] = true
	assert(duplicate_count == 0, "H15: Found %d duplicate edges across river paths" % duplicate_count)

	# H17: Width must correlate with network-wide accumulation
	print(" [CHECK] H17. Network-Normalized Width Correlation...")
	for river in hydro.rivers:
		var widths: Array = river.get("widths", [])
		if widths.size() < 3:
			continue
		var first_quarter: float = float(widths[widths.size() / 4])
		var last_quarter: float = float(widths[3 * widths.size() / 4])
		if widths.size() > 10:
			assert(last_quarter >= first_quarter * 0.8, "H17: River width should generally increase downstream")

	# H20: Water elevation invariant
	print(" [CHECK] H20. Water Elevation >= Terrain Elevation...")
	for pos in hydro.water_cells:
		var data: Dictionary = hydro.water_cells[pos]
		var water_h: float = float(data.get("water_height", 0.0))
		var terrain_h: float = float(data.get("terrain_height", 0.0))
		assert(water_h >= terrain_h - 0.01, "H20: Water at %s (%.3f) below terrain (%.3f)" % [str(pos), water_h, terrain_h])

	# H21: Meander displacement zero at source and outlet
	print(" [CHECK] H21. Meander Taper at Endpoints...")
	for river in hydro.rivers:
		var pts: Array = river.get("points", [])
		var river_cells: Array = river.get("cells", [])
		if pts.size() < 4 or river_cells.size() < 4:
			continue
		var first_grid := Vector2(float(river_cells[0].x), float(river_cells[0].y))
		var first_world := Vector2(pts[0].x, pts[0].z)
		var first_offset: float = first_world.distance_to(first_grid)
		assert(first_offset < 0.01, "H21: First river point must have zero meander offset, got %.4f" % first_offset)
		var last_grid := Vector2(float(river_cells[-1].x), float(river_cells[-1].y))
		var last_world := Vector2(pts[-1].x, pts[-1].z)
		var last_offset: float = last_world.distance_to(last_grid)
		assert(last_offset < 0.01, "H21: Last river point must have zero meander offset, got %.4f" % last_offset)

	# 3. Test Downhill River Flow (Topographic Gravity Law)
	print(" [CHECK] 3. River Flow Law (Rivers must strictly flow downhill)...")
	print("   Rivers generated: %d" % hydro.rivers.size())
	for river in hydro.rivers:
		var pts: Array = river.points
		var r_cells: Array = river.cells
		assert(pts.size() >= 5, "River must contain points")
		for i in range(pts.size() - 1):
			var cur_pt: Vector3 = pts[i]
			var next_pt: Vector3 = pts[i + 1]
			assert(next_pt.y <= cur_pt.y + 0.001, "River point %d (Y=%.2f) flows uphill to point %d (Y=%.2f)!" % [i, cur_pt.y, i + 1, next_pt.y])

	# H24: Navigation uses post-carving slope
	print(" [CHECK] H24. Navigation Reflects Post-Carving Terrain...")
	for river in hydro.rivers:
		for pos in river.get("cells", []):
			if hydro.is_lake(pos):
				continue
			var cell: WorldCell = result.get_cell(pos)
			if cell == null:
				continue
			if cell.slope < 10.0:
				assert(cell.slope_category == NavigationStage.SlopeCategory.FLAT, "H24: Post-carve slope category mismatch at %s" % str(pos))

	# 4. Test Vegetation Water Avoidance
	print(" [CHECK] 4. Vegetation Submersion Exclusion...")
	for item in result.vegetation:
		var cell_x: int = clampi(int(round(item.position.x / profile.cell_size)), 0, profile.width - 1)
		var cell_z: int = clampi(int(round(item.position.z / profile.cell_size)), 0, profile.height - 1)
		var grid_pos := Vector2i(cell_x, cell_z)
		if hydro.is_lake(grid_pos):
			var depth: float = hydro.get_water_depth(grid_pos)
			assert(depth < 0.1, "Vegetation item %s cannot be placed deep underwater (depth=%.2f)!" % [str(item.type), depth])

	# 5. Test Hydrology 3D Mesh Construction
	print(" [CHECK] 5. HydrologyRenderer Overlay Generation...")
	var hydro_node: Node3D = _HydrologyRendererScript.build_hydrology_node(result, profile)
	assert(hydro_node != null, "Hydrology node must be created")
	if not hydro.lakes.is_empty():
		assert(hydro_node.has_node("LakesMesh"), "LakesMesh must exist when lakes are present")
	if not hydro.rivers.is_empty():
		assert(hydro_node.has_node("RiversMesh"), "RiversMesh must exist when rivers are present")

	hydro_node.free()

	# 6. Test Debug Layers Populated in HydrologyResult
	print(" [CHECK] 6. Debug Layers Integrity (Noise, Potentials, Drainage, Flow Dir)...")
	assert(hydro.has_debug_layer("noise"), "Must contain 'noise' debug layer")
	assert(hydro.has_debug_layer("lake_potential"), "Must contain 'lake_potential' debug layer")
	assert(hydro.has_debug_layer("river_potential"), "Must contain 'river_potential' debug layer")
	assert(hydro.has_debug_layer("drainage"), "Must contain 'drainage' debug layer")
	assert(hydro.has_debug_layer("flow_dir"), "Must contain 'flow_dir' debug layer")

	var test_cell_pos := Vector2i(64, 64)
	var noise_val = hydro.get_debug_value("noise", test_cell_pos)
	assert(noise_val >= 0.0 and noise_val <= 1.0, "Hydrology noise must be normalized in [0.0, 1.0]")

	# Verify that cell_size (world scale) affects hydrology noise sampling coordinates
	var scaled_profile := TaigaWorldProfile.new()
	scaled_profile.cell_size = 2.0
	var scaled_result := WorldPipeline.generate(1234, scaled_profile)
	var scaled_noise_val = scaled_result.hydrology.get_debug_value("noise", test_cell_pos)
	assert(absf(float(scaled_noise_val) - float(noise_val)) > 0.001, "Hydrology noise must be affected by world scale (cell_size)")

	# 7. Test Parameter Configurability
	print(" [CHECK] 7. Dynamic Hydrology Configurability...")
	var dry_profile := TaigaWorldProfile.new()
	dry_profile.lake_threshold = 0.02
	dry_profile.max_rivers = 0
	var dry_result := WorldPipeline.generate(4242, dry_profile)
	var dry_hydro = dry_result.hydrology
	assert(dry_hydro.rivers.is_empty(), "When max_rivers=0, no rivers should form")
	assert(dry_hydro.lakes.size() <= hydro.lakes.size(), "Low lake_threshold must produce fewer or equal lakes")

	# 8. Phase H10 Invariants: Width Growth & Physical Channel Carving
	print(" [CHECK] 8. Phase H10 Invariants (Width Growth, Outlet Validity, Channel Carving)...")
	for river in hydro.rivers:
		var widths: Array = river.widths
		var pts: Array = river.points
		assert(widths.size() == pts.size(), "Width array must match point count")
		assert(widths[0] >= profile.river_min_width * 0.35, "Headwater width must be >= min threshold")
		assert(widths[widths.size() - 1] <= profile.river_max_width * 1.35, "Outlet width must be <= max threshold")

		# River endpoint must be at lake, confluence, or near boundary
		var last_pos: Vector2i = river.cells[river.cells.size() - 1]
		var is_near_boundary: bool = (last_pos.x <= 2 or last_pos.x >= profile.width - 3 or last_pos.y <= 2 or last_pos.y >= profile.height - 3)
		var is_at_water: bool = hydro.is_lake(last_pos) or hydro.is_river(last_pos)
		assert(is_near_boundary or is_at_water, "River %d must terminate at lake, confluence, or boundary!" % river.index)

	# H25: Comprehensive Hydrology Contract Test
	print(" [CHECK] H25. Comprehensive Hydrology Contract...")
	validate_hydrology_contract(result, profile)

	# H26: Multi-seed validation (5 representative seeds)
	print(" [CHECK] H26. Multi-Seed Invariant Validation (5 seeds)...")
	var test_seeds: Array[int] = [1001, 2002, 3003, 4004, 5005]

	var total_rivers: int = 0
	var total_lakes: int = 0
	var seeds_with_rivers: int = 0
	var seeds_with_lakes: int = 0

	for test_seed in test_seeds:
		var test_result := WorldPipeline.generate(test_seed, profile)
		validate_hydrology_contract(test_result, profile)

		var test_hydro = test_result.hydrology
		total_rivers += test_hydro.rivers.size()
		total_lakes += test_hydro.lakes.size()
		if not test_hydro.rivers.is_empty():
			seeds_with_rivers += 1
		if not test_hydro.lakes.is_empty():
			seeds_with_lakes += 1

	print("   5-seed summary:")
	print("     Rivers: %d total, %d/%d seeds" % [total_rivers, seeds_with_rivers, test_seeds.size()])
	print("     Lakes:  %d total, %d/%d seeds" % [total_lakes, seeds_with_lakes, test_seeds.size()])

	print("==================================================")
	print(" ALL HYDROLOGY & SEPARATION TESTS PASSED!")
	print("==================================================")
	quit(0)


static func validate_hydrology_contract(result: WorldResult, profile: WorldProfile) -> void:
	var hydro = result.hydrology
	assert(hydro != null, "HydrologyResult must exist")

	validate_global_flow_graph(result, profile)
	validate_inverse_graph_consistency(result)
	validate_river_network_contract(result, profile)
	validate_lakes_and_geometry(result)
	validate_watershed_integrity(result, profile)
	validate_outlet_topology(result, profile)


static func validate_global_flow_graph(result: WorldResult, profile: WorldProfile) -> void:
	var hydro = result.hydrology
	var flow_to: Dictionary = hydro.debug_layers.get("flow_to", {})
	assert(not flow_to.is_empty(), "flow_to layer must exist and not be empty")

	var drainage: Dictionary = hydro.debug_layers.get("drainage", {})
	assert(not drainage.is_empty(), "drainage layer must exist")

	var spillway_set: Dictionary = {}
	for lake in hydro.lakes:
		var sp: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		if sp != Vector2i(-1, -1):
			spillway_set[sp] = true

	# 1. Global Acyclicity & Termination Validation (3-state DFS)
	var visited_state: Dictionary = {}  # 0=unvisited, 1=visiting, 2=validated
	for pos in flow_to:
		if visited_state.get(pos, 0) == 2:
			continue

		var stack: Array[Vector2i] = []
		var curr: Vector2i = pos

		while true:
			var state: int = visited_state.get(curr, 0)
			if state == 1:
				assert(false, "Global D8 cycle detected involving %s" % str(curr))
			if state == 2:
				break

			visited_state[curr] = 1
			stack.append(curr)

			var nxt: Vector2i = flow_to.get(curr, curr)
			if nxt == curr:
				# Reached terminal sink: must be boundary, spillway, or lake body
				var is_boundary: bool = (curr.x <= 1 or curr.x >= profile.width - 2 or curr.y <= 1 or curr.y >= profile.height - 2)
				var is_spillway: bool = spillway_set.has(curr)
				var is_lake: bool = hydro.is_lake(curr)
				assert(is_boundary or is_spillway or is_lake, "Flow terminated in unclassified internal sink at %s" % str(curr))
				break

			# 2. Monotonic Accumulation: acc[B] >= acc[A] for A -> B
			var acc_here: float = float(drainage.get(curr, 1.0))
			var acc_next: float = float(drainage.get(nxt, 1.0))
			assert(acc_next >= acc_here, "Accumulation must be monotonic downstream: %s (%.1f) -> %s (%.1f)" % [str(curr), acc_here, str(nxt), acc_next])

			curr = nxt

		for p in stack:
			visited_state[p] = 2

	# 3. Lake-to-Spillway Mapping Validation
	for lake in hydro.lakes:
		var lake_cells: Array = lake.get("cells", [])
		var lake_set: Dictionary = {}
		for lc in lake_cells:
			lake_set[lc] = true

		var spill_pos: Vector2i = lake.get("spillway_pos", Vector2i(-1, -1))
		if result.cells.has(spill_pos):
			assert(not lake_set.has(spill_pos), "Spillway %s cannot be inside lake cells" % str(spill_pos))
			assert(not hydro.is_lake(spill_pos), "Spillway %s cannot be classified as lake" % str(spill_pos))

			for lc in lake_cells:
				assert(flow_to.get(lc, lc) == spill_pos, "H6: Lake cell %s must drain directly to spillway %s" % [str(lc), str(spill_pos)])

			var spill_next: Vector2i = flow_to.get(spill_pos, spill_pos)
			if spill_next != spill_pos:
				assert(not lake_set.has(spill_next), "Spillway %s flows back into its lake at %s" % [str(spill_pos), str(spill_next)])


static func validate_inverse_graph_consistency(result: WorldResult) -> void:
	var hydro = result.hydrology
	var flow_to: Dictionary = hydro.debug_layers.get("flow_to", {})
	var upstream: Dictionary = hydro.debug_layers.get("upstream", {})
	assert(not upstream.is_empty() or flow_to.is_empty(), "upstream reverse graph must exist")

	var expected_in_degree: Dictionary = {}
	for pos in flow_to:
		var down: Vector2i = flow_to[pos]
		if down != pos:
			expected_in_degree[down] = expected_in_degree.get(down, 0) + 1

	# Every flow_to edge must be present in upstream
	for pos in flow_to:
		var down: Vector2i = flow_to[pos]
		if down != pos:
			assert(upstream.has(down), "Upstream graph must have entry for downstream node %s" % str(down))
			assert(upstream[down].has(pos), "upstream[%s] must contain upstream node %s" % [str(down), str(pos)])

	# Every upstream entry must match flow_to and contain no duplicates
	for down in upstream:
		var up_list: Array = upstream[down]
		var seen: Dictionary = {}
		for up_node in up_list:
			assert(not seen.has(up_node), "Duplicate upstream node %s in upstream[%s]" % [str(up_node), str(down)])
			seen[up_node] = true
			assert(flow_to.get(up_node) == down, "Node %s in upstream[%s] has mismatching flow_to %s (expected %s)" % [str(up_node), str(down), str(flow_to.get(up_node)), str(down)])

		assert(up_list.size() == expected_in_degree.get(down, 0), "upstream[%s] size (%d) mismatch with in-degree (%d)" % [str(down), up_list.size(), expected_in_degree.get(down, 0)])


static func validate_river_network_contract(result: WorldResult, profile: WorldProfile) -> void:
	var hydro = result.hydrology
	var flow_to: Dictionary = hydro.debug_layers.get("flow_to", {})
	var drainage: Dictionary = hydro.debug_layers.get("drainage", {})

	var river_by_cell: Dictionary = {}
	for river in hydro.rivers:
		var r_idx: int = river.get("index", -1)
		var r_cells: Array = river.get("cells", [])
		for c in r_cells:
			if not river_by_cell.has(c):
				river_by_cell[c] = []
			river_by_cell[c].append(r_idx)

	var rendered_edges: Dictionary = {}

	for river in hydro.rivers:
		var cells_arr: Array = river.get("cells", [])
		var widths_arr: Array = river.get("widths", [])
		var pts_arr: Array = river.get("points", [])

		assert(cells_arr.size() >= 2, "River must contain at least 2 cells")
		assert(widths_arr.size() == pts_arr.size() and pts_arr.size() == cells_arr.size(), "Array size mismatch in river %d" % river.get("index", -1))

		for w in widths_arr:
			assert(float(w) > 0.0, "Width must be positive")

		# 1. Headwater verification
		var head_pos: Vector2i = cells_arr[0]
		assert(result.cells.has(head_pos), "Headwater %s not in world cells" % str(head_pos))
		assert(float(drainage.get(head_pos, 0.0)) >= 1.0, "Headwater %s must have positive drainage" % str(head_pos))

		# 2. Path continuity, downhill gravity, flow_to alignment, edge disjointness
		for i in range(cells_arr.size() - 1):
			var cur_c: Vector2i = cells_arr[i]
			var next_c: Vector2i = cells_arr[i + 1]

			var diff := next_c - cur_c
			assert(maxi(absi(diff.x), absi(diff.y)) <= 1, "Discontinuous river cells at index %d: %s -> %s" % [i, str(cur_c), str(next_c)])
			assert(pts_arr[i + 1].y <= pts_arr[i].y + 0.001, "River point flows uphill at index %d: %.3f -> %.3f" % [i, pts_arr[i].y, pts_arr[i + 1].y])
			assert(flow_to.get(cur_c) == next_c, "River path %s -> %s deviates from flow_to %s" % [str(cur_c), str(next_c), str(flow_to.get(cur_c))])

			var edge_key: String = "%d,%d->%d,%d" % [cur_c.x, cur_c.y, next_c.x, next_c.y]
			assert(not rendered_edges.has(edge_key), "Duplicate river edge: %s" % edge_key)
			rendered_edges[edge_key] = true

		# 3. Destination Contract: Boundary, Lake, or True Confluence
		var dest: Vector2i = cells_arr[-1]
		var is_near_boundary: bool = (dest.x <= 2 or dest.x >= profile.width - 3 or dest.y <= 2 or dest.y >= profile.height - 3)
		var is_lake_dest: bool = hydro.is_lake(dest) or hydro.is_lake(flow_to.get(dest, dest))

		if not is_near_boundary and not is_lake_dest:
			# Must be a true confluence with another river
			var sharing_rivers: Array = river_by_cell.get(dest, [])
			var found_confluence: bool = false
			for other_idx in sharing_rivers:
				if other_idx != river.get("index", -1):
					found_confluence = true
					break
			assert(found_confluence, "River %d endpoint %s is in dry land without reaching boundary, lake, or another river confluence" % [river.get("index", -1), str(dest)])

			# Trace downstream from confluence to ensure network reaches boundary or lake
			var curr_trace: Vector2i = dest
			var reaches_valid_destination: bool = false
			for _step in range(profile.width + profile.height):
				if curr_trace.x <= 2 or curr_trace.x >= profile.width - 3 or curr_trace.y <= 2 or curr_trace.y >= profile.height - 3:
					reaches_valid_destination = true
					break
				if hydro.is_lake(curr_trace):
					reaches_valid_destination = true
					break
				var next_trace: Vector2i = flow_to.get(curr_trace, curr_trace)
				if next_trace == curr_trace:
					break
				curr_trace = next_trace

			assert(reaches_valid_destination, "Confluence at %s does not eventually reach a boundary or lake" % str(dest))


static func validate_lakes_and_geometry(result: WorldResult) -> void:
	var hydro = result.hydrology

	for lake in hydro.lakes:
		var lake_h: float = float(lake.get("water_height", 0.0))
		var lake_cells: Array = lake.get("cells", [])
		for c_pos in lake_cells:
			var c_data: Dictionary = hydro.get_cell_data(c_pos)
			assert(c_data.get("type", "") == "lake", "Lake cell must be type 'lake'")
			assert(is_equal_approx(float(c_data.get("water_height", 0.0)), lake_h), "Lake cells must share water height")

	for pos in hydro.water_cells:
		var data: Dictionary = hydro.water_cells[pos]
		var water_h: float = float(data.get("water_height", 0.0))
		var terrain_h: float = float(data.get("terrain_height", 0.0))
		assert(water_h >= terrain_h - 0.01, "Water must be at or above terrain")


static func validate_watershed_integrity(result: WorldResult, profile: WorldProfile) -> void:
	var hydro = result.hydrology
	var flow_to: Dictionary = hydro.debug_layers.get("flow_to", {})
	var cell_basin_map: Dictionary = hydro.debug_layers.get("basins", {})
	var check: Dictionary = _WatershedIntegrityCheckerScript.check(
		result.cells, cell_basin_map, hydro.basins, flow_to, profile.width, profile.height
	)
	assert(check["bijection_violations"].is_empty(), "Watershed bijection violations detected: %d" % check["bijection_violations"].size())
	assert(check["cycle_violations"].is_empty(), "Watershed cycle violations detected: %d" % check["cycle_violations"].size())
	assert(check["invalid_outlet_violations"].is_empty(), "Watershed invalid outlet violations detected: %d" % check["invalid_outlet_violations"].size())
	assert(check["orphan_cells"].is_empty(), "Watershed orphan cells detected: %d" % check["orphan_cells"].size())


static func validate_outlet_topology(result: WorldResult, profile: WorldProfile) -> void:
	var hydro = result.hydrology
	var flow_to: Dictionary = hydro.debug_layers.get("flow_to", {})
	var outlets: Array = []
	for b_id in hydro.basins:
		outlets.append(hydro.basins[b_id].get("outlet", Vector2i(-1, -1)))

	var val: Dictionary = _OutletValidatorScript.validate_outlets(
		outlets, result.cells, flow_to, hydro, profile.width, profile.height, profile
	)
	assert(val["outlets_invalid"] == 0, "Topological contract violation: found %d INVALID outlets" % val["outlets_invalid"])
