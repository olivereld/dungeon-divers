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

	print("==================================================")
	print(" ALL HYDROLOGY & SEPARATION TESTS PASSED!")
	print("==================================================")
	quit()
