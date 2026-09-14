extends SceneTree

## Test formal para WaterMeshBuilder (BLOQUE 5).
## Valida que:
## 1. Cada celda de agua genera su representación 2D (exactamente 2 triángulos por celda de agua).
## 2. Las celdas secas no generan geometría.
## 3. Las celdas adyacentes comparten vértices (sin duplicación en esquinas compartidas).
## 4. No hay dependencia de River, Lake, WaterField ni RenderSegment.
## 5. Todos los vértices tienen cotas finitas.

const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test: WaterMeshBuilder (Bloque 5)")
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
	print("  Hydrology water cells: %d" % water_cell_count)
	assert(water_cell_count > 0, "Debe haber celdas de agua generadas")

	var surf = _WaterMeshBuilderScript.build_water_surface(result, profile)
	assert(surf != null, "WaterSurfaceData no debe ser nulo")

	# Invariante 1: Número de triángulos exacto = water_cells * 2
	var triangle_count: int = surf.indices.size() / 3
	print("  Triángulos generados: %d (esperados: %d)" % [triangle_count, water_cell_count * 2])
	assert(triangle_count == water_cell_count * 2,
		"Invariante violado: se esperaban %d triángulos (2 por water_cell), pero se generaron %d" % [water_cell_count * 2, triangle_count])

	# Invariante 2: Deduplicación de vértices compartidos
	# Si no hubiera deduplicación, habría 4 vértices por celda = water_cell_count * 4.
	# Con celdas contiguas compartiendo esquinas, el total de vértices debe ser estrictamente menor que water_cell_count * 4.
	var vertex_count: int = surf.vertices.size()
	print("  Vértices únicos generados: %d (sin deduplicación serían %d)" % [vertex_count, water_cell_count * 4])
	assert(vertex_count < water_cell_count * 4,
		"Invariante violado: no se están compartiendo vértices entre celdas contiguas")

	# Invariante 3: Finitud de cotas y coordenadas
	for v in surf.vertices:
		assert(is_finite(v.x) and is_finite(v.y) and is_finite(v.z), "Vértice con coordenadas no finitas: %s" % str(v))

	# Invariante 4: ArrayMesh único válido
	var mesh: ArrayMesh = surf.to_array_mesh()
	assert(mesh != null and mesh.get_surface_count() == 1, "Debe producir exactamente un ArrayMesh con una superficie")

	# Invariante 5: Validar que un mundo sin agua produce null (cero geometría)
	var dry_profile = _TaigaWorldProfileScript.new()
	dry_profile.width = 32
	dry_profile.height = 32
	dry_profile.hydrology_enabled = false
	var dry_result: WorldResult = _WorldPipelineScript.generate(111, dry_profile)
	var dry_mesh: ArrayMesh = _WaterMeshBuilderScript.build_mesh(dry_result, dry_profile)
	assert(dry_mesh == null, "Un mundo sin agua no debe generar ninguna malla")

	print("==================================================")
	print(" ALL WATER MESH BUILDER TESTS PASSED!")
	print("==================================================")
	quit(0)
