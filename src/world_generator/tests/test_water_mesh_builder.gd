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

	# Invariante 1: Contrato espacial 1:1 de vértices y resolución
	var expected_vertices: int = w * h
	assert(water_surf.vertices.size() == expected_vertices,
		"Invariante 1 violado: se esperaban %d vertices pero hay %d" % [expected_vertices, water_surf.vertices.size()])
	print("  [PASS] Invariante 1: Resolucion 1:1 (%d vertices de agua == %d vertices del terreno)" % [water_surf.vertices.size(), expected_vertices])

	# Invariante 2: Contrato espacial 1:1 de triangulación
	var expected_triangles: int = (w - 1) * (h - 1) * 2
	var actual_triangles: int = water_surf.indices.size() / 3
	assert(actual_triangles == expected_triangles,
		"Invariante 2 violado: se esperaban %d triangulos pero hay %d" % [expected_triangles, actual_triangles])
	print("  [PASS] Invariante 2: Triangulacion 1:1 (%d triangulos globales de agua == terreno)" % actual_triangles)

	# Invariante 3: Alineación X/Z idéntica con el terreno
	var terrain_faces := terrain_mesh.get_faces()
	var water_mesh: ArrayMesh = water_surf.to_array_mesh()
	assert(water_mesh != null)
	var water_faces := water_mesh.get_faces()
	assert(terrain_faces.size() == water_faces.size(), "El conteo de caras de agua debe coincidir con el terreno")

	for i in range(water_surf.vertices.size()):
		var wv := water_surf.vertices[i]
		var expected_x := float(i % w)
		var expected_z := float(i / w)
		assert(is_equal_approx(wv.x, expected_x) and is_equal_approx(wv.z, expected_z),
			"Alineacion X/Z rota en vertice %d: (%f, %f) vs esperada (%f, %f)" % [i, wv.x, wv.z, expected_x, expected_z])
	print("  [PASS] Invariante 3: Alineacion horizontal X/Z exacta con la grilla del mundo")

	# Invariante 4: Máscara y resolución de alturas
	var water_verified := 0
	var dry_verified := 0
	for y in range(h):
		for x in range(w):
			var pos2i := Vector2i(x, y)
			var idx := y * w + x
			var wv := water_surf.vertices[idx]
			var col := water_surf.colors[idx]

			if hydro.water_cells.has(pos2i):
				var expected_h := float(hydro.water_cells[pos2i]["water_height"])
				var c_type: String = str(hydro.water_cells[pos2i].get("type", "river"))
				if c_type == "lake":
					assert(is_equal_approx(wv.y, expected_h), "Cota de agua en (%d, %d) debe ser %f, es %f" % [x, y, expected_h, wv.y])
				else:
					var min_local: float = INF
					var max_local: float = -INF
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							var np := Vector2i(x + dx, y + dy)
							if hydro.water_cells.has(np):
								var nwh := float(hydro.water_cells[np]["water_height"])
								min_local = minf(min_local, nwh)
								max_local = maxf(max_local, nwh)
					assert(wv.y >= min_local - 0.01 and wv.y <= max_local + 0.01,
						"Interpolacion de rio en (%d, %d) fuera de rango [%f, %f]: %f" % [x, y, min_local, max_local, wv.y])
				assert(col.a == 1.0, "Mascara de agua debe ser 1.0 en water cell")
				water_verified += 1
			else:
				assert(col.a == 0.0, "Mascara de agua debe ser 0.0 en dry cell")
				assert(is_finite(wv.y), "Cota de celda seca debe ser finita")
				dry_verified += 1

	assert(water_verified == water_cell_count, "Todas las water_cells deben ser verificadas")
	assert(dry_verified == (w * h) - water_cell_count, "Todas las dry_cells deben ser verificadas")
	print("  [PASS] Invariante 4: Mascara y cotas verificadas (%d agua @ 1.0, %d secas @ 0.0)" % [water_verified, dry_verified])

	# Invariante 5: Aislamiento hidráulico (cero invención de celdas en hydro.water_cells)
	assert(hydro.water_cells.size() == water_cell_count,
		"WaterMeshBuilder NO debe anadir ni modificar entradas en hydro.water_cells")
	print("  [PASS] Invariante 5: Cero invencion hidraulica en celdas secas")

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
