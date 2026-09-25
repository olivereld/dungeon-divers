extends SceneTree

## Suite de Test: Validación del Fondo Marino Renderizado (Bloque 2)
## Para cada water_cell generada en el mundo:
## 1. cell.height == bed_height
## 2. bed_height <= water_height
## 3. TerrainMesh Y == bed_height (el fondo renderizado es exactamente el fondo hidráulico)

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Seabed Render Validation (Bloque 2)")
	print("==================================================")

	var test_seeds: Array[int] = [4242, 12345, 283362, 99999]

	for s in test_seeds:
		_test_seabed_render(s)

	print("==================================================")
	print(" ALL SEABED RENDER VALIDATION TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_seabed_render(seed_val: int) -> void:
	print("\n--- Testing Seed: %d ---" % seed_val)

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 96
	profile.height = 96
	profile.hydrology_enabled = true
	profile.lake_threshold = 0.22
	profile.max_rivers = 4
	profile.min_river_length = 8.0

	var ctx = _WorldGenerationContextScript.new(seed_val, profile)
	var terrain_stage = _TerrainStageScript.new()
	terrain_stage.execute(ctx)

	var hydro_stage = _HydrologyStageScript.new()
	hydro_stage.execute(ctx)

	var result: WorldResult = ctx.result
	var hydro: HydrologyResult = result.hydrology
	assert(hydro != null and not hydro.water_cells.is_empty(), "Hydrology must produce water cells")

	# Construir la malla de terreno
	var terrain_mesh: ArrayMesh = TerrainMeshBuilder.build_mesh(result, profile.cell_size, profile)
	assert(terrain_mesh != null and terrain_mesh.get_surface_count() > 0, "TerrainMeshBuilder must produce valid mesh")

	var mesh_arrays: Array = terrain_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = mesh_arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = mesh_arrays[Mesh.ARRAY_NORMAL]

	# Indexar alturas de vértices planos superiores (normal ~ UP) por coordenada de celda
	var cell_top_y: Dictionary = {}
	for i in range(vertices.size()):
		var v: Vector3 = vertices[i]
		var n: Vector3 = normals[i]
		if n.dot(Vector3.UP) > 0.90:
			var cx := int(round(v.x / profile.cell_size))
			var cz := int(round(v.z / profile.cell_size))
			var cpos := Vector2i(cx, cz)
			cell_top_y[cpos] = v.y

	var water_cells_verified: int = 0
	for pos in hydro.water_cells:
		var data: Dictionary = hydro.water_cells[pos]
		var cell: WorldCell = result.get_cell(pos)
		assert(cell != null, "Water cell must exist in WorldResult at %s" % str(pos))

		var w_h: float = float(data["water_height"])
		var b_h: float = float(data["bed_height"])
		var depth: float = float(data["depth"])

		# 1. cell.height == bed_height
		assert(is_equal_approx(cell.height, b_h),
			"Contrato hidráulico violado en %s: cell.height (%.4f) != bed_height (%.4f)" % [str(pos), cell.height, b_h])

		# 2. bed_height <= water_height
		assert(b_h <= w_h + 0.001,
			"Contrato de lecho violado en %s: bed_height (%.4f) > water_height (%.4f)" % [str(pos), b_h, w_h])

		# 3. TerrainMesh Y == bed_height
		if cell_top_y.has(pos):
			var mesh_y: float = float(cell_top_y[pos])
			var diff: float = absf(mesh_y - b_h)
			assert(diff < 0.005,
				"Fondo marino renderizado mismatch en %s: TerrainMesh Y (%.4f) != bed_height (%.4f), diff=%.6f" % [str(pos), mesh_y, b_h, diff])
			water_cells_verified += 1

	print("  Water cells verified against TerrainMesh Y: %d" % water_cells_verified)
	assert(water_cells_verified > 0, "Debe verificarse al menos una celda de agua contra el mesh de terreno")
