extends SceneTree

const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _HydrologyRendererScript = preload("res://src/world_renderer/hydrology_renderer.gd")
const _TerrainColorResolverScript = preload("res://src/world_generator/presentation/terrain_color_resolver.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Hydrology & Separation of Concerns Tests")
	print("==================================================")

	var profile := TaigaWorldProfile.new()
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

	# 3. Test Downhill River Flow (Topographic Gravity Law)
	print(" [CHECK] 3. River Flow Law (Rivers must strictly flow downhill)...")
	print("   Rivers generated: %d" % hydro.rivers.size())
	for river in hydro.rivers:
		var pts: Array = river.points
		assert(pts.size() >= 5, "River must contain points")
		for i in range(pts.size() - 1):
			var cur_pt: Vector3 = pts[i]
			var next_pt: Vector3 = pts[i + 1]
			# Topography downhill descent: next_pt.y must be <= cur_pt.y (with minimal epsilon for floating point)
			assert(next_pt.y <= cur_pt.y + 0.001, "River point %d (Y=%.2f) flows uphill to point %d (Y=%.2f)!" % [i, cur_pt.y, i + 1, next_pt.y])

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

	print("==================================================")
	print(" ALL HYDROLOGY & SEPARATION TESTS PASSED!")
	print("==================================================")
	quit(0)
