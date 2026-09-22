extends SceneTree

## Contractual test suite for Bloque 1: Height and Water Data Model Standardization.
## Verifies that:
## 1. cell.raw_height is strictly immutable across hydrology.
## 2. hydro.water_cells contains water_height, bed_height, depth, shoreline_height.
## 3. depth == water_height - bed_height within numerical tolerance.
## 4. hydro.water_cells NEVER contains "terrain_height" or "raw_height".
## 5. Dry cells are never present in water_cells.
## 6. cell.height and cell.raw_height are finite everywhere.
## 7. Where terrain is carved, cell.height <= cell.raw_height + 0.0001 (carving only excavates).

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Water Height Contract (Bloque 1)")
	print("==================================================")

	var test_seeds: Array[int] = [4242, 12345, 283362, 99999]

	for seed_val in test_seeds:
		_test_seed(seed_val)

	print("==================================================")
	print(" ALL WATER HEIGHT CONTRACT TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_seed(seed_val: int) -> void:
	print("\n--- Testing Seed: %d ---" % seed_val)

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 96
	profile.height = 96
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.22
	profile.max_rivers = 4
	profile.min_river_length = 8.0

	# Step 1: Run up through TerrainStage to snapshot virgin terrain raw_height
	var ctx = _WorldGenerationContextScript.new(seed_val, profile)
	var terrain_stage = _TerrainStageScript.new()
	terrain_stage.execute(ctx)

	var raw_height_snapshot: Dictionary = {}
	for pos in ctx.result.cells:
		var cell: WorldCell = ctx.result.cells[pos]
		assert(is_finite(cell.raw_height), "Virgin raw_height at %s must be finite" % str(pos))
		raw_height_snapshot[pos] = cell.raw_height

	# Step 2: Execute HydrologyStage
	var hydro_stage = _HydrologyStageScript.new()
	hydro_stage.execute(ctx)

	var result: WorldResult = ctx.result
	var hydro: HydrologyResult = result.hydrology
	assert(hydro != null, "HydrologyResult must exist")

	print("  Lakes: %d, Rivers: %d, Water cells: %d" % [hydro.lakes.size(), hydro.rivers.size(), hydro.water_cells.size()])

	# Invariant 1: raw_height immutability
	print("  [CHECK] Invariant 1: raw_height Immutability across Hydrology...")
	for pos in result.cells:
		var cell: WorldCell = result.cells[pos]
		var original_raw: float = float(raw_height_snapshot[pos])
		assert(cell.raw_height == original_raw,
			"Invariant 1 violated: raw_height mutated at %s from %.4f to %.4f" % [str(pos), original_raw, cell.raw_height])

	# Invariant 2 & 4: Universal Terrain Finiteness and Non-Elevation Carving
	print("  [CHECK] Invariant 2 & 7: Universal Terrain Finiteness and Carving Invariant...")
	var carved_cell_count: int = 0
	for pos in result.cells:
		var cell: WorldCell = result.cells[pos]
		assert(is_finite(cell.height), "cell.height at %s must be finite" % str(pos))
		assert(is_finite(cell.raw_height), "cell.raw_height at %s must be finite" % str(pos))

		if cell.height < cell.raw_height - 0.0001:
			carved_cell_count += 1

		# Carving must only excavate (or blend), never lift terrain above virgin raw_height,
		# except where shoreline bank bevel elevates dry bank above adjacent water level.
		var max_adj_wh: float = -INF
		if not hydro.water_cells.has(pos):
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var np: Vector2i = Vector2i(pos) + Vector2i(dx, dy)
					if hydro.water_cells.has(np):
						var wh: float = float(hydro.water_cells[np].get("water_height", 0.0))
						if wh > max_adj_wh:
							max_adj_wh = wh

		if max_adj_wh != -INF:
			assert(cell.height <= maxf(cell.raw_height, max_adj_wh + profile.shoreline_bank_bevel + 0.01),
				"Shoreline bank bevel at %s exceeded allowable freeboard: height=%.4f, raw=%.4f, max_wh=%.4f" % [str(pos), cell.height, cell.raw_height, max_adj_wh])
		else:
			assert(cell.height <= cell.raw_height + 0.0001,
				"Carving raised terrain above virgin raw_height at %s: height=%.4f > raw=%.4f" % [str(pos), cell.height, cell.raw_height])

	print("    Carved cells found: %d" % carved_cell_count)
	assert(carved_cell_count > 0, "Hydrology should have carved at least some river/lake cells")

	# Invariant 3: water_cells contract verification
	print("  [CHECK] Invariant 3: water_cells Contract (water_height, bed_height, depth, no terrain_height)...")
	assert(not hydro.water_cells.is_empty(), "Hydrology must generate water cells")

	for pos in hydro.water_cells:
		var data: Dictionary = hydro.water_cells[pos]

		# Must NOT contain forbidden keys
		assert(not data.has("terrain_height"),
			"Forbidden key 'terrain_height' found in water_cells[%s]" % str(pos))
		assert(not data.has("raw_height"),
			"Forbidden key 'raw_height' found in water_cells[%s]" % str(pos))

		# Mandatory keys
		assert(data.has("water_height"), "Missing 'water_height' at %s" % str(pos))
		assert(data.has("bed_height"), "Missing 'bed_height' at %s" % str(pos))
		assert(data.has("depth"), "Missing 'depth' at %s" % str(pos))
		assert(data.has("shoreline_height"), "Missing 'shoreline_height' at %s" % str(pos))

		var w_h: float = float(data["water_height"])
		var b_h: float = float(data["bed_height"])
		var depth: float = float(data["depth"])
		var s_h: float = float(data["shoreline_height"])

		assert(is_finite(w_h), "'water_height' at %s is not finite: %s" % [str(pos), str(w_h)])
		assert(is_finite(b_h), "'bed_height' at %s is not finite: %s" % [str(pos), str(b_h)])
		assert(is_finite(depth), "'depth' at %s is not finite: %s" % [str(pos), str(depth)])
		assert(is_finite(s_h), "'shoreline_height' at %s is not finite: %s" % [str(pos), str(s_h)])

		# Contract relation: depth == water_height - bed_height
		var diff: float = absf(depth - (w_h - b_h))
		assert(diff <= 0.001,
			"Invariant depth == water_height - bed_height violated at %s: depth=%.4f, expected=%.4f (diff=%.6f)" % [str(pos), depth, w_h - b_h, diff])

		# Depth must be non-negative
		assert(depth >= -0.0001,
			"Negative depth at %s: %.4f" % [str(pos), depth])

	# Invariant 5: Dry cells check
	print("  [CHECK] Invariant 5: Dry Cells Contract...")
	var dry_count: int = 0
	for pos in result.cells:
		if not hydro.water_cells.has(pos):
			dry_count += 1
			assert(not hydro.is_water(pos), "Cell %s not in water_cells but is_water() is true" % str(pos))
			var cell_data: Dictionary = hydro.get_cell_data(pos)
			assert(cell_data.is_empty(), "Dry cell %s returned non-empty get_cell_data()" % str(pos))

	print("    Dry cells verified: %d" % dry_count)
	assert(dry_count > 0, "There must be dry cells in the world")

	# Invariant 6: TerrainMeshBuilder Consumption Verification
	print("  [CHECK] Invariant 6: TerrainMeshBuilder exclusively renders cell.height (never raw_height)...")
	var terrain_mesh: ArrayMesh = TerrainMeshBuilder.build_mesh(result, 1.0, profile)
	assert(terrain_mesh != null and terrain_mesh.get_surface_count() > 0, "TerrainMeshBuilder must produce valid mesh")
	var mesh_arrays: Array = terrain_mesh.surface_get_arrays(0)
	var mesh_vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	assert(mesh_vertices.size() >= profile.width * profile.height * 4, "Mesh vertex count must match stepped terrain dimensions")

	var carved_mesh_verified: int = 0
	var normals: PackedVector3Array = mesh_arrays[Mesh.ARRAY_NORMAL]
	var top_left_verts: Dictionary = {}
	for i in range(mesh_vertices.size()):
		var v: Vector3 = mesh_vertices[i]
		var n: Vector3 = normals[i]
		if n.dot(Vector3.UP) > 0.95:
			var cell_pos := Vector2i(int(round(v.x)), int(round(v.z)))
			top_left_verts[cell_pos] = v.y

	for y in range(profile.height):
		for x in range(profile.width):
			var pos := Vector2i(x, y)
			var c: WorldCell = result.get_cell(pos)
			if top_left_verts.has(pos):
				var vy: float = float(top_left_verts[pos])
				assert(is_equal_approx(vy, c.height),
					"Mesh vertex Y at (%d, %d) mismatch: mesh_y=%.4f != cell.height=%.4f" % [x, y, vy, c.height])

				# On meaningfully carved cells (at least 5cm carving depth), verify mesh vertex Y reflects carved height and NOT raw_height
				if c.height < c.raw_height - 0.05:
					assert(absf(vy - c.raw_height) > 0.01,
						"Mesh vertex Y at (%d, %d) incorrectly matches virgin raw_height instead of carved height! v.y=%.4f, raw=%.4f, height=%.4f" % [x, y, vy, c.raw_height, c.height])
					carved_mesh_verified += 1

	print("    Verified %d carved vertices rendered at cell.height" % carved_mesh_verified)
	assert(carved_mesh_verified > 0, "At least one carved vertex must be verified in the mesh")
