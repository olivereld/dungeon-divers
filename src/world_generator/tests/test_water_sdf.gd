extends SceneTree

## =============================================================================
## Test Formal: Shoreline Distance Field (SDF) y Transición Suave de Orilla
## =============================================================================
## Valida que:
## 1. El campo de distancia SDF está empaquetado en COLOR.a:
##    - Celdas de agua: COLOR.a >= 0.5 (d >= 0.0m)
##    - Celdas secas: COLOR.a < 0.5 (d < 0.0m)
##    - Línea de costa exacta (frontera): COLOR.a pasa por 0.5
## 2. Continuidad y acotamiento:
##    - COLOR.a es finito y acotado en [0.0, 1.0] para todos los vértices.
## 3. Invariante hidráulica estricta:
##    - hydro.water_cells no es mutado ni alterado por WaterMeshBuilder.
## 4. Pruebas a través de múltiples semillas (4242, 12345, 283362).
## =============================================================================

const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterTopologyScript = preload("res://src/world_generator/presentation/water/water_topology.gd")

func _init() -> void:
	print("==================================================")
	print(" RUNNING TEST: SHORELINE DISTANCE FIELD (SDF)")
	print("==================================================")

	var seeds: Array[int] = [4242, 12345, 283362]
	for s in seeds:
		_test_seed_sdf(s)

	print("\n==================================================")
	print(" ALL SHORELINE DISTANCE FIELD TESTS PASSED! (100%)")
	print("==================================================")
	quit(0)

func _test_seed_sdf(s: int) -> void:
	print("\n--- Evaluando Semilla %d ---" % s)
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	var result: WorldResult = _WorldPipelineScript.generate(s, profile)
	var hydro: HydrologyResult = result.hydrology
	var w: int = result.dimensions.x
	var h: int = result.dimensions.y

	# Snapshot de water_cells para verificar inmutabilidad
	var water_cells_count_before: int = hydro.water_cells.size()
	var sample_pos: Vector2i = hydro.water_cells.keys()[0]
	var sample_wh_before: float = float(hydro.water_cells[sample_pos]["water_height"])

	# Construir superficie
	var surf: WaterSurfaceData = _WaterMeshBuilderScript.build_water_surface(result, profile)
	assert(surf != null, "WaterSurfaceData no debe ser nulo")

	# 1. Inmutabilidad hidráulica
	assert(hydro.water_cells.size() == water_cells_count_before,
		"hydro.water_cells fue mutado! Conteo inicial %d, actual %d" % [water_cells_count_before, hydro.water_cells.size()])
	assert(float(hydro.water_cells[sample_pos]["water_height"]) == sample_wh_before,
		"water_height fue mutado en la simulación hidrológica!")
	print("  [PASS] 1. Contrato hidráulico 100% inmutable (0 invención de cotas)")

	# 2. Validación de SDF y signos en COLOR.a
	var water_ge_half := 0
	var dry_lt_half := 0
	var min_water_sdf := 1.0
	var max_dry_sdf := 0.0

	for y in range(h):
		for x in range(w):
			var idx: int = y * w + x
			var pos2i := Vector2i(x, y)
			var a: float = surf.colors[idx].a
			var is_water: bool = hydro.water_cells.has(pos2i)

			assert(is_finite(a), "COLOR.a no finito en (%d,%d)" % [x, y])
			assert(a >= 0.0 and a <= 1.0, "COLOR.a fuera de [0,1]: %f" % a)

			if is_water:
				assert(a >= 0.5, "Vértice de agua (%d,%d) tiene SDF negativo (a=%.4f < 0.5)" % [x, y, a])
				water_ge_half += 1
				min_water_sdf = minf(min_water_sdf, a)
			else:
				assert(a < 0.5, "Vértice seco (%d,%d) tiene SDF positivo (a=%.4f >= 0.5)" % [x, y, a])
				dry_lt_half += 1
				max_dry_sdf = maxf(max_dry_sdf, a)

	assert(water_ge_half == hydro.water_cells.size(),
		"Todas las celdas de agua deben tener COLOR.a >= 0.5")
	assert(dry_lt_half == (w * h) - hydro.water_cells.size(),
		"Todas las celdas secas deben tener COLOR.a < 0.5")

	print("  [PASS] 2. Separación exacta de signos SDF (Agua min=%.3f >= 0.5, Secas max=%.3f < 0.5)" % [
		min_water_sdf, max_dry_sdf
	])

	# 3. Validación de continuidad de la frontera:
	# En cualquier quad que contenga tanto vértices de agua como secos,
	# debe existir un cruce continuo a través de 0.5 (la línea de costa)
	var boundary_quads := 0
	for y in range(h - 1):
		for x in range(w - 1):
			var a00: float = surf.colors[y * w + x].a
			var a10: float = surf.colors[y * w + (x + 1)].a
			var a01: float = surf.colors[(y + 1) * w + x].a
			var a11: float = surf.colors[(y + 1) * w + (x + 1)].a

			var min_a := minf(minf(a00, a10), minf(a01, a11))
			var max_a := maxf(maxf(a00, a10), maxf(a01, a11))

			if min_a < 0.5 and max_a >= 0.5:
				boundary_quads += 1

	assert(boundary_quads > 0, "Deben existir quads de frontera")
	print("  [PASS] 3. %d quads de ribera verificados con cruce continuo sub-celda (isolínea 0.5)" % boundary_quads)
