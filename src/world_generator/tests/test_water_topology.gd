extends SceneTree

## Test formal de topología hidráulica (BLOQUE 6).
## Valida:
## 1. Clasificación de aristas: agua->agua (interior), agua->tierra (borde), agua->exterior (borde).
## 2. Reciprocidad matemática de aristas interiores.
## 3. Segmentación en componentes conexos (ríos, lagos, confluencias continuas).
## 4. Perímetro cerrado para cada cuerpo de agua.
## 5. Ausencia de caras internas entre celdas de agua.

const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterTopologyScript = preload("res://src/world_generator/presentation/water/water_topology.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Test Suite: Water Topology (Bloque 6)")
	print("==================================================")

	var test_seeds: Array[int] = [4242, 12345, 283362]

	for s in test_seeds:
		_test_seed_topology(s)

	print("==================================================")
	print(" ALL WATER TOPOLOGY TESTS PASSED!")
	print("==================================================")
	quit(0)

func _test_seed_topology(seed_val: int) -> void:
	print("\n--- Testing Topology for Seed %d ---" % seed_val)

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	profile.hydrology_enabled = true
	profile.max_rivers = 3
	profile.lake_threshold = 0.25

	var result: WorldResult = _WorldPipelineScript.generate(seed_val, profile)
	assert(result != null and result.hydrology != null)

	var hydro: HydrologyResult = result.hydrology
	var water_cells: Dictionary = hydro.water_cells
	print("  Total water cells: %d" % water_cells.size())
	assert(not water_cells.is_empty(), "Hydrology must produce water cells")

	var topo = _WaterMeshBuilderScript.build_topology(result)
	assert(topo != null, "WaterTopology must not be null")

	# 1. Validar invariantes estructurales
	print("  [CHECK] 1. Invariantes de Aristas y Reciprocidad...")
	var report: Dictionary = topo.validate_invariants(water_cells)
	assert(report["valid"], "Invariantes topológicos violados: %s" % str(report["errors"]))
	print("    Aristas interiores: %d, Aristas de borde: %d" % [report["interior_edges"], report["boundary_edges"]])

	# 2. Validar componentes conexos
	print("  [CHECK] 2. Componentes Conexos y Contornos...")
	var comp_count: int = topo.get_component_count()
	print("    Cuerpos de agua contiguos detectados: %d" % comp_count)
	assert(comp_count > 0, "Debe existir al menos 1 cuerpo de agua continuo")

	var cells_in_components: int = 0
	for comp in topo.components:
		var c_cells: Array = comp["cells"]
		var c_bounds: Array = comp["boundary_edges"]
		assert(not c_cells.is_empty(), "Componente sin celdas")
		assert(not c_bounds.is_empty(), "Componente sin aristas de borde (superficie no cerrada)")
		cells_in_components += c_cells.size()

	assert(cells_in_components == water_cells.size(),
		"Discrepancia: celdas en componentes (%d) != total water_cells (%d)" % [cells_in_components, water_cells.size()])

	# 3. Validar generación de malla topológicamente continua
	print("  [CHECK] 3. Malla Unificada sobre Topología...")
	var surf = _WaterMeshBuilderScript.build_water_surface(result, profile)
	assert(surf != null, "WaterSurfaceData must be valid")

	var triangle_count: int = surf.indices.size() / 3
	var expected_tris: int = (profile.width - 1) * (profile.height - 1) * 2
	assert(triangle_count == expected_tris,
		"La superficie global debe generar exactamente (W-1)*(H-1)*2 triangulos")

	var active_water_mask := 0
	for col in surf.colors:
		if col.a >= 0.5:
			active_water_mask += 1
	assert(active_water_mask == water_cells.size(),
		"Vertices con mascara de agua activa deben coincidir con water_cells")

	print("    Superficie global continua verificada: %d triangulos, %d vertices (%d activos en mascara)" % [
		triangle_count, surf.vertices.size(), active_water_mask
	])
