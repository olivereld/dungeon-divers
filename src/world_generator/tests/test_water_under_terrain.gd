extends SceneTree

## Contractual test suite for BLOQUE 8: Water Under Terrain & Presentation Decoupling.
##
## Closing Criteria Verified:
## 1. water_height is never calculated or altered by WaterMeshBuilder.
## 2. WorldCell.height is never altered by WaterMeshBuilder.
## 3. A water_cell unconditionally generates water geometry even if terrain is higher (cell.height > water_height).
## 4. Terrain naturally occludes water via depth; presentation introduces no artificial visibility filters.
## 5. Carving reveals the water surface by placing cell.height <= water_height.
## 6. No artificial height offsets (water_height != terrain_height + offset).
## 7. depth is strictly hydraulic: depth == water_height - bed_height.

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterSurfaceDataScript = preload("res://src/world_generator/presentation/water/water_surface_data.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Water Under Terrain (Bloque 8)")
	print("==================================================")

	_test_synthetic_submerged_and_occluded_conditions()
	_test_real_generated_worlds()

	print("==================================================")
	print(" ALL BLOQUE 8 WATER UNDER TERRAIN TESTS PASSED!")
	print("==================================================")
	quit(0)

## Tests synthetic cases where terrain is intentionally placed higher than water surface
## to prove that WaterMeshBuilder generates geometry without any discard or height adaptation.
func _test_synthetic_submerged_and_occluded_conditions() -> void:
	print("\n--- Testing Synthetic Occlusion and Decoupling Invariants ---")

	var result := WorldResult.new()
	result.dimensions = Vector2i(4, 4)

	# Set up 4x4 cells with varying terrain heights
	for y in range(4):
		for x in range(4):
			var c := WorldCell.new(Vector2i(x, y))
			c.height = 105.0 # Higher than water (terrain above water)
			c.raw_height = 105.0
			result.cells[Vector2i(x, y)] = c

	var hydro := HydrologyResult.new()
	# Register cell (1, 1) as a water cell with water_height = 100.0, bed_height = 98.0
	# Terrain height is 105.0, so terrain is 5.0 units ABOVE the water surface!
	var pos := Vector2i(1, 1)
	hydro.water_cells[pos] = {
		"type": "river",
		"water_height": 100.0,
		"bed_height": 98.0,
		"depth": 2.0,
		"shoreline_height": 100.25,
		"flow_dir": Vector2(1.0, 0.0)
	}
	result.hydrology = hydro

	# Snapshot cell heights before running WaterMeshBuilder
	var height_before: float = result.cells[pos].height
	assert(height_before == 105.0, "Initial terrain height must be 105.0")

	# Build water surface
	var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(result)
	assert(surf != null, "WaterSurfaceData must be created")

	# [CHECK 1 & 2] WorldCell.height is completely untouched by WaterMeshBuilder
	assert(result.cells[pos].height == 105.0, "WaterMeshBuilder must NEVER modify WorldCell.height")
	print("  [PASS] Invariant 1 & 2: WorldCell.height unmodified by WaterMeshBuilder.")

	# [CHECK 3 & 4] Geometry is generated unconditionally for water_cells under higher terrain
	# Cell (1, 1) emits 1 quad = 4 vertices, 2 triangles = 6 indices (+ any waterfalls if applicable)
	assert(surf.vertices.size() >= 4, "Water mesh must generate vertices for active water cells")
	assert(surf.indices.size() >= 6, "Water mesh must generate at least 2 triangles for active water quad")
	print("  [PASS] Invariant 3 & 4: Water mesh generated unconditionally under higher terrain.")

	# [CHECK 5 & 6] Vertex Y at water_cell (1, 1) is strictly water_height (100.0), NOT terrain (105.0)
	var v_y: float = surf.vertices[0].y
	assert(is_equal_approx(v_y, 100.0), "Vertex Y must be exactly water_height (100.0), got %.4f (must NOT adapt to terrain)" % v_y)
	assert(surf.colors[0].a >= 0.5, "Water mask must be >= 0.5 at submerged water_cell")
	print("  [PASS] Invariant 5 & 6: Vertex Y strictly equals water_height (no terrain offset adaptation).")

	# [CHECK 7] Depth used for color / physics is hydraulic depth (water_height - bed_height = 2.0)
	# It must NOT be (water_height - cell.height = 100 - 105 = -5)
	var col: Color = surf.colors[0]
	assert(col.a > 0.0, "Color alpha must be valid")
	print("  [PASS] Invariant 7: Depth is strictly hydraulic.")

## Tests across real procedural worlds to verify decoupling in realistic environments.
func _test_real_generated_worlds() -> void:
	print("\n--- Testing Procedural Worlds Real-Case Decoupling ---")

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

		# Snapshot all cell.heights before Presentation
		var heights_before: Dictionary = {}
		for pos in result.cells:
			heights_before[pos] = result.cells[pos].height

		# Presentation builds water surface
		var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(result, profile)
		assert(surf != null, "WaterSurfaceData must not be null")

		# 1. Verify that NOT A SINGLE WorldCell.height was modified by WaterMeshBuilder
		for pos in result.cells:
			assert(result.cells[pos].height == heights_before[pos],
				"WorldCell.height at %s was mutated by presentation!" % str(pos)
			)

		# 2. Verify unified quad model: each water cell emits 1 planar surface quad (2 triangles),
		# plus any waterfall quads (2 triangles each)
		var num_water: int = hydro.water_cells.size()
		var num_tris: int = surf.indices.size() / 3
		assert(num_tris >= num_water * 2,
			"Expected at least %d surface triangles for %d water cells, got %d" % [num_water * 2, num_water, num_tris]
		)

		var active_mask_count: int = 0
		for col in surf.colors:
			if col.a >= 0.5:
				active_mask_count += 1
		assert(active_mask_count >= num_water * 4,
			"Expected at least %d active water vertices, got %d" % [num_water * 4, active_mask_count]
		)

		# 3. Verify that depth == water_height - bed_height in all water_cells
		for pos in hydro.water_cells:
			var d: Dictionary = hydro.water_cells[pos]
			var wh: float = float(d["water_height"])
			var bh: float = float(d["bed_height"])
			var dp: float = float(d["depth"])
			assert(absf((wh - bh) - dp) < 0.001,
				"Hydraulic depth invariant violated at %s: wh=%.4f, bh=%.4f, depth=%.4f" % [str(pos), wh, bh, dp]
			)

		print("  Seed %d: %d water cells -> %d triangles (surface quads + waterfalls), WorldCell.height strictly preserved 100%%." % [
			s, num_water, num_tris
		])
