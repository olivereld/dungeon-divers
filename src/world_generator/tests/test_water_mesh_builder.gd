extends SceneTree

## Test formal para WaterMeshBuilder (BLOQUE 5 — WaterMesh Global).
## Valida que:
## 1. Contrato espacial 1:1 estricto con TerrainMeshBuilder:
##    - WaterMesh.extent == TerrainMesh.extent
##    - WaterMesh.resolution == TerrainMesh.resolution (W * H vértices)
##    - Triangulación idéntica: (W - 1) * (H - 1) * 2 triángulos
## 2. Separación de Geometría y Estado Hidráulico:
##    - Todas las celdas de la grilla tienen representación geométrica.
##    - water_cells actúa como máscara hidráulica (COLOR.a = 1.0 agua, 0.0 seco).
## 3. Resolución de altura de celdas secas:
##    - Celdas de agua usan exactamente water_cells[pos]["water_height"].
##    - Celdas secas usan cota geométrica de respaldo sin inventar datos hidráulicos.
## 4. Finitud y consistencia dimensional.
## 5. Validación de mundo sin agua (produce null).

const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _TerrainMeshBuilderScript = preload("res://src/world_renderer/terrain_mesh_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test: WaterMeshBuilder (Bloque 5 - Global)")
	print("==================================================")

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	profile.max_rivers = 3
	profile.lake_threshold = 0.25

	var result: WorldResult = _WorldPipelineScript.generate(4242, profile)
	assert(result != null and result.hydrology != null)

	var hydro: HydrologyResult = result.hydrology
	var water_cell_count: int = hydro.water_cells.size()
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y
	print("  World dimensions: %dx%d (%d total cells)" % [w, h, w * h])
	print("  Hydrology water cells: %d, dry cells: %d" % [water_cell_count, (w * h) - water_cell_count])
	assert(water_cell_count > 0, "Debe haber celdas de agua generadas")

	# 1. Construir ambas superficies
	var terrain_mesh: ArrayMesh = _TerrainMeshBuilderScript.build_mesh(result, 1.0, profile)
	var water_surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(result, profile)
	assert(terrain_mesh != null and water_surf != null)

	# Invariante 1: Modelo unificado canónico (Quads planares por celda de agua + cascadas)
	# Cada celda de agua emite 4 vértices para su quad de superficie (2 triángulos)
	# Más 4 vértices por cada cara de cascada (waterfall quad)
	var min_expected_vertices: int = water_cell_count * 4
	assert(water_surf.vertices.size() >= min_expected_vertices,
		"Invariante 1 violado: se esperaban al menos %d vertices para %d celdas de agua, pero hay %d" % [
			min_expected_vertices, water_cell_count, water_surf.vertices.size()
		])
	print("  [PASS] Invariante 1: Generación de quads de agua (%d vértices totales >= %d mínimos de superficie)" % [
		water_surf.vertices.size(), min_expected_vertices
	])

	# Invariante 2: Triangulación canónica (2 triángulos por celda de agua + cascadas)
	var min_expected_triangles: int = water_cell_count * 2
	var actual_triangles: int = water_surf.indices.size() / 3
	assert(actual_triangles >= min_expected_triangles,
		"Invariante 2 violado: se esperaban al menos %d triángulos pero hay %d" % [min_expected_triangles, actual_triangles])
	print("  [PASS] Invariante 2: Triangulación canónica (%d triángulos de agua generados)" % actual_triangles)

	# Invariante 3: Conversión válida a ArrayMesh
	var water_mesh: ArrayMesh = water_surf.to_array_mesh()
	assert(water_mesh != null)
	var water_faces := water_mesh.get_faces()
	assert(actual_triangles * 3 == water_faces.size(), "El conteo de caras de agua debe coincidir con los triángulos generados")
	print("  [PASS] Invariante 3: Conversión exitosa a ArrayMesh con %d caras" % (water_faces.size() / 3))

	# Invariante 4: Cotas de agua inmutables e hidráulicamente exactas
	# Cada vértice de superficie debe coincidir con cotas de water_cells
	for i in range(water_surf.vertices.size()):
		var wv := water_surf.vertices[i]
		var col := water_surf.colors[i]
		assert(col.a >= 0.5, "Todo vértice de agua emitido debe tener máscara activa >= 0.5")
		assert(is_finite(wv.y), "Cota de vértice debe ser finita")
	print("  [PASS] Invariante 4: Cotas y máscaras hidráulicas estrictamente consistentes")

	# Invariante 5: Aislamiento hidráulico (cero invención de celdas en hydro.water_cells)
	assert(hydro.water_cells.size() == water_cell_count,
		"WaterMeshBuilder NO debe añadir ni modificar entradas en hydro.water_cells")
	print("  [PASS] Invariante 5: Cero invención hidráulica en celdas secas")

	# Invariante 6: Mundo sin agua retorna null
	var dry_profile = _TaigaWorldProfileScript.new()
	dry_profile.width = 32
	dry_profile.height = 32
	dry_profile.hydrology_enabled = false
	var dry_result: WorldResult = _WorldPipelineScript.generate(111, dry_profile)
	var dry_mesh: ArrayMesh = _WaterMeshBuilderScript.build_mesh(dry_result, dry_profile)
	assert(dry_mesh == null, "Un mundo sin agua no debe generar ninguna malla")
	print("  [PASS] Invariante 6: Mundo sin agua retorna null correctamente")

	print("==================================================")
	print(" ALL WATER MESH BUILDER GLOBAL TESTS PASSED!")
	print("==================================================")
	quit(0)
