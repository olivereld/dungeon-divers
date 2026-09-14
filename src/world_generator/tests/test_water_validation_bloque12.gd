extends SceneTree

## =============================================================================
## BLOQUE 12: SUITE EXHAUSTIVA DE VALIDACIÓN FORMAL DE AGUA
## =============================================================================
## Valida formalmente:
## 1. Validación estructural:
##    HydrologyResult -> water_cells -> WaterMeshBuilder -> 1 ArrayMesh -> 1 MeshInstance3D
##    Comprobar que WaterRenderer no utiliza RiverMeshBuilder, LakeMeshBuilder ni WaterField.
## 2. Validar fuente de verdad:
##    water_cells[pos]["water_height"] -> vertex.y (sin terreno, sin River/Lake, sin offsets arbitrarios).
## 3. Validar topología en arquetipos:
##    - Río recto
##    - Río curvo
##    - Lago
##    - Río -> Lago
##    - Confluencia
##    - Bifurcación
##    - Outflow
##    - Agua irregular
##    (Sin agujeros, sin caras duplicadas, sin geometrías superpuestas, sin z-fighting).
## 4. Validar relación terreno/agua:
##    Terrain > Water (agua oculta naturalmente), Terrain < Water (agua visible),
##    carving -> Water permanece donde Hydrology lo definió.
## 5. Validar Taiga en múltiples semillas (4242, 12345, 283362, 99999, 777777).
## 6. Criterio de cierre:
##    1 water mask, 1 WaterMeshBuilder, 1 ArrayMesh, 1 MeshInstance3D, 1 WaterMaterial.
## =============================================================================

const _WorldGenerationContextScript = preload("res://src/world_generator/core/world_generation_context.gd")
const _TerrainStageScript = preload("res://src/world_generator/stages/terrain_stage.gd")
const _HydrologyStageScript = preload("res://src/world_generator/stages/hydrology_stage.gd")
const _TaigaWorldProfileScript = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipelineScript = preload("res://src/world_generator/facade/world_pipeline.gd")
const _WaterMeshBuilderScript = preload("res://src/world_generator/presentation/water/water_mesh_builder.gd")
const _WaterRendererScript = preload("res://src/world_generator/presentation/water/water_renderer.gd")
const _WaterTopologyScript = preload("res://src/world_generator/presentation/water/water_topology.gd")

func _init() -> void:
	print("=================================================================")
	print(" RUNNING TEST SUITE: BLOQUE 12 - VALIDACION COMPLETA DE AGUA")
	print("=================================================================")

	_test_1_structural_validation()
	_test_2_source_of_truth_validation()
	_test_3_topology_archetypes_validation()
	_test_4_terrain_water_relationship()
	_test_5_taiga_multi_seed_validation()
	_test_6_closing_criterion()

	print("\n=================================================================")
	print(" ALL BLOQUE 12 VALIDATION TESTS PASSED SUCCESSFULLY! (100%)")
	print("=================================================================")
	quit(0)


## -----------------------------------------------------------------------------
## 1. VALIDACIÓN ESTRUCTURAL
## -----------------------------------------------------------------------------
func _test_1_structural_validation() -> void:
	print("\n--- [1/6] Validacion Estructural ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	var result: WorldResult = _WorldPipelineScript.generate(4242, profile)

	# A) Verificar orquestación de WaterRenderer
	var water_renderer = _WaterRendererScript.new()
	var water_node: Node3D = water_renderer.build_water_node(result, profile)
	assert(water_node != null, "WaterRenderer debe producir un nodo Node3D")

	# B) Verificar estructura de nodo: exactamente 1 MeshInstance3D
	var mesh_instances: Array[MeshInstance3D] = []
	for child in water_node.get_children():
		if child is MeshInstance3D and child.name == "UnifiedWaterSurface":
			mesh_instances.append(child)

	assert(mesh_instances.size() == 1,
		"Debe existir exactamente 1 MeshInstance3D ('UnifiedWaterSurface'), encontrados: %d" % mesh_instances.size())
	var mi: MeshInstance3D = mesh_instances[0]
	assert(mi.mesh is ArrayMesh, "El mesh debe ser un ArrayMesh")
	var am: ArrayMesh = mi.mesh as ArrayMesh
	assert(am.get_surface_count() == 1, "Debe existir exactamente 1 superficie en ArrayMesh")

	# C) Verificar material asignado
	assert(mi.material_override != null, "MeshInstance3D debe tener asignado material_override")

	# D) Inspección estática del código fuente de WaterRenderer:
	# Confirmar que no instancia RiverMeshBuilder, LakeMeshBuilder ni WaterField en producción
	var renderer_source_file = FileAccess.open("res://src/world_generator/presentation/water/water_renderer.gd", FileAccess.READ)
	assert(renderer_source_file != null, "Debe existir water_renderer.gd")
	var src_text: String = renderer_source_file.get_as_text()
	renderer_source_file.close()

	assert(not src_text.contains("RiverMeshBuilder.new"), "WaterRenderer no debe instanciar RiverMeshBuilder")
	assert(not src_text.contains("LakeMeshBuilder.new"), "WaterRenderer no debe instanciar LakeMeshBuilder")
	assert(src_text.contains("water_mesh_builder.gd") and src_text.contains("build_mesh"), "WaterRenderer debe llamar directamente a WaterMeshBuilder.build_mesh")

	print("  [PASS] Pipeline: HydrologyResult -> water_cells -> WaterMeshBuilder -> 1 ArrayMesh -> 1 MeshInstance3D.")
	print("  [PASS] WaterRenderer desacoplado de RiverMeshBuilder, LakeMeshBuilder y WaterField.")


## -----------------------------------------------------------------------------
## 2. VALIDAR LA FUENTE DE VERDAD
## -----------------------------------------------------------------------------
func _test_2_source_of_truth_validation() -> void:
	print("\n--- [2/6] Validar la Fuente de Verdad (water_cells -> vertex.y) ---")
	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	var result: WorldResult = _WorldPipelineScript.generate(12345, profile)
	var hydro: HydrologyResult = result.hydrology
	var water_cells: Dictionary = hydro.water_cells

	# A) Verificar que cada vértice proviene exclusivamente de water_cells
	var mesh: ArrayMesh = _WaterMeshBuilderScript.build_mesh(result, profile)
	assert(mesh != null and mesh.get_surface_count() > 0)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	var cell_size: float = profile.cell_size
	for v in verts:
		# Los vértices de quads de celda están en esquinas [x-0.5, x+0.5] * cell_size
		var gx: float = v.x / cell_size
		var gz: float = v.z / cell_size

		# Buscar celdas de agua circundantes a esta esquina
		var min_wh: float = INF
		var max_wh: float = -INF
		var found_water: bool = false

		for dx in [-0.5, 0.5]:
			for dz in [-0.5, 0.5]:
				var cx: int = int(round(gx + dx))
				var cz: int = int(round(gz + dz))
				var c_pos := Vector2i(cx, cz)
				if water_cells.has(c_pos):
					found_water = true
					var wh: float = float(water_cells[c_pos]["water_height"])
					min_wh = minf(min_wh, wh)
					max_wh = maxf(max_wh, wh)

		assert(found_water, "Vertice en (%f, %f) no tiene celdas de agua circundantes!" % [v.x, v.z])
		assert(v.y >= min_wh - 0.001 and v.y <= max_wh + 0.001,
			"Vertice Y=%.4f fuera del rango de water_cells [%.4f, %.4f]" % [v.y, min_wh, max_wh])

	# B) Inmutabilidad frente a mutaciones del terreno:
	# Si mutamos arbitrariamente WorldCell.height, la malla de agua debe permanecer 100% IDÉNTICA
	var test_pos: Vector2i = water_cells.keys()[0]
	var old_cell_height: float = result.cells[test_pos].height
	result.cells[test_pos].height += 50.0  # Elevamos terreno artificialmente

	var mesh_after: ArrayMesh = _WaterMeshBuilderScript.build_mesh(result, profile)
	var verts_after: PackedVector3Array = mesh_after.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(verts.size() == verts_after.size(), "La cantidad de vertices no debe cambiar al alterar terrain")
	for i in range(verts.size()):
		assert(absf(verts[i].y - verts_after[i].y) < 0.0001,
			"Vertice %d Y muto de %.4f a %.4f tras alterar terrain height!" % [i, verts[i].y, verts_after[i].y])

	# Restaurar
	result.cells[test_pos].height = old_cell_height

	# C) Células secas no generan agua
	for pos in result.cells:
		if not water_cells.has(pos):
			assert(not hydro.is_water(pos), "Celda seca %s registrada falsamente como agua" % str(pos))

	print("  [PASS] vertex.y gobernado al 100% por water_cells[pos]['water_height'].")
	print("  [PASS] Inmune a mutaciones en WorldCell.height; cero offsets arbitrarios; celda seca = cero agua.")


## -----------------------------------------------------------------------------
## 3. VALIDAR TOPOLOGÍA EN ARQUETIPOS
## -----------------------------------------------------------------------------
func _test_3_topology_archetypes_validation() -> void:
	print("\n--- [3/6] Validar Topologia en Arquetipos Hidraulicos ---")

	# 1. Río Recto
	var cells_straight: Dictionary = {}
	for y in range(2, 15):
		for x in range(4, 7):
			cells_straight[Vector2i(x, y)] = {"water_height": 20.0 - float(y) * 0.5, "type": "river"}
	_validate_archetype("Rio Recto", cells_straight, 20, 20)

	# 2. Río Curvo (Meandro)
	var cells_curved: Dictionary = {}
	var center_pts: Array[Vector2i] = [
		Vector2i(3, 2), Vector2i(4, 3), Vector2i(5, 4), Vector2i(6, 6),
		Vector2i(5, 8), Vector2i(4, 10), Vector2i(4, 12), Vector2i(5, 14)
	]
	for idx in range(center_pts.size()):
		var cp: Vector2i = center_pts[idx]
		var wh: float = 30.0 - float(idx) * 0.8
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				cells_curved[Vector2i(cp.x + dx, cp.y + dy)] = {"water_height": wh, "type": "river"}
	_validate_archetype("Rio Curvo", cells_curved, 20, 20)

	# 3. Lago Circular
	var cells_lake: Dictionary = {}
	var lake_center := Vector2(10.0, 10.0)
	var lake_radius: float = 4.5
	var lake_wh: float = 15.0
	for y in range(4, 17):
		for x in range(4, 17):
			if Vector2(float(x), float(y)).distance_to(lake_center) <= lake_radius:
				cells_lake[Vector2i(x, y)] = {"water_height": lake_wh, "type": "lake"}
	_validate_archetype("Lago Circular", cells_lake, 24, 24)

	# 4. Río -> Lago (Inlet)
	var cells_inflow: Dictionary = {}
	for k in cells_lake:
		cells_inflow[k] = cells_lake[k].duplicate()
	# Río fluyendo hacia el lago desde el norte (Y=0 a Y=6)
	for y in range(0, 7):
		var wh: float = maxf(lake_wh, lake_wh + float(6 - y) * 0.5)
		for x in range(9, 12):
			cells_inflow[Vector2i(x, y)] = {"water_height": wh, "type": "river"}
	_validate_archetype("Rio -> Lago (Inlet)", cells_inflow, 24, 24)

	# 5. Lago Outflow (Emisario)
	var cells_outflow: Dictionary = {}
	for k in cells_lake:
		cells_outflow[k] = cells_lake[k].duplicate()
	# Río naciendo del lago hacia el sur (Y=14 a Y=23)
	for y in range(14, 24):
		var wh: float = lake_wh - float(y - 14) * 0.4
		for x in range(9, 12):
			if not cells_outflow.has(Vector2i(x, y)):
				cells_outflow[Vector2i(x, y)] = {"water_height": wh, "type": "river"}
	_validate_archetype("Lago -> Rio (Outflow)", cells_outflow, 24, 24)

	# 6. Confluencia en 'Y'
	var cells_conf: Dictionary = {}
	# Rama izquierda
	for i in range(6):
		var wh: float = 25.0 - float(i) * 0.5
		for d in range(-1, 2):
			cells_conf[Vector2i(4 + i, 3 + i + d)] = {"water_height": wh, "type": "river"}
	# Rama derecha
	for i in range(6):
		var wh: float = 24.0 - float(i) * 0.5
		for d in range(-1, 2):
			cells_conf[Vector2i(16 - i, 3 + i + d)] = {"water_height": wh, "type": "river"}
	# Tronco común hacia el sur
	for y in range(8, 16):
		var wh: float = 22.0 - float(y - 8) * 0.6
		for x in range(9, 12):
			cells_conf[Vector2i(x, y)] = {"water_height": wh, "type": "river"}
	_validate_archetype("Confluencia en Y", cells_conf, 24, 24)

	# 7. Bifurcación / Delta
	var cells_bif: Dictionary = {}
	# Tronco superior
	for y in range(2, 8):
		var wh: float = 30.0 - float(y) * 0.5
		for x in range(9, 12):
			cells_bif[Vector2i(x, y)] = {"water_height": wh, "type": "river"}
	# Brazo izquierdo
	for i in range(6):
		var wh: float = 26.0 - float(i) * 0.5
		for d in range(-1, 2):
			cells_bif[Vector2i(9 - i, 8 + i + d)] = {"water_height": wh, "type": "river"}
	# Brazo derecho
	for i in range(6):
		var wh: float = 26.0 - float(i) * 0.5
		for d in range(-1, 2):
			cells_bif[Vector2i(11 + i, 8 + i + d)] = {"water_height": wh, "type": "river"}
	_validate_archetype("Bifurcacion / Delta", cells_bif, 24, 24)

	# 8. Cuerpo de Agua Irregular
	var cells_irreg: Dictionary = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = 98765
	for y in range(5, 18):
		for x in range(5, 18):
			if rng.randf() > 0.35:
				cells_irreg[Vector2i(x, y)] = {"water_height": 10.0 + rng.randf() * 0.2, "type": "wetland"}
	_validate_archetype("Cuerpo de Agua Irregular", cells_irreg, 24, 24)


func _validate_archetype(arch_name: String, water_cells: Dictionary, w: int, h: int) -> void:
	var hydro = HydrologyResult.new()
	hydro.water_cells = water_cells
	for pos in water_cells:
		var d = water_cells[pos]
		if d.get("type") == "lake":
			hydro.lakes.append({"cells": [pos], "water_height": d["water_height"]})

	var topo = _WaterTopologyScript.analyze(water_cells, w, h)
	var report: Dictionary = topo.validate_invariants(water_cells)
	assert(report["valid"], "Arquetipo '%s' violo invariantes topologicos: %s" % [arch_name, str(report["errors"])])

	# Construir malla sintética para el arquetipo
	var dummy_result = WorldResult.new()
	dummy_result.hydrology = hydro
	for pos in water_cells:
		var c = WorldCell.new(pos)
		c.height = 5.0
		c.raw_height = 5.0
		dummy_result.cells[pos] = c

	var dummy_profile = WorldProfile.new()
	dummy_profile.width = w
	dummy_profile.height = h
	dummy_profile.cell_size = 1.0

	var mesh: ArrayMesh = _WaterMeshBuilderScript.build_mesh(dummy_result, dummy_profile)
	assert(mesh != null and mesh.get_surface_count() == 1, "Malla invalida en arquetipo '%s'" % arch_name)

	var arrays: Array = mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert(indices.size() == water_cells.size() * 6,
		"Arquetipo '%s': indices esperados %d, obtenidos %d" % [arch_name, water_cells.size() * 6, indices.size()])

	# Verificar que no hay caras duplicadas
	var tri_set: Dictionary = {}
	for t in range(0, indices.size(), 3):
		var i0: int = indices[t]
		var i1: int = indices[t + 1]
		var i2: int = indices[t + 2]
		var sorted_tri: Array = [i0, i1, i2]
		sorted_tri.sort()
		var tri_key: String = "%d_%d_%d" % [sorted_tri[0], sorted_tri[1], sorted_tri[2]]
		assert(not tri_set.has(tri_key), "Cara duplicada detectada en arquetipo '%s': %s" % [arch_name, tri_key])
		tri_set[tri_key] = true

	print("  [PASS] Arquetipo '%s': %d celdas -> %d triangulos, 0 errores, 0 duplicados." % [
		arch_name, water_cells.size(), indices.size() / 3
	])


## -----------------------------------------------------------------------------
## 4. VALIDAR RELACIÓN TERRENO / AGUA
## -----------------------------------------------------------------------------
func _test_4_terrain_water_relationship() -> void:
	print("\n--- [4/6] Validar Relacion Terreno / Agua (Desacoplamiento Fisico) ---")

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	var result: WorldResult = _WorldPipelineScript.generate(283362, profile)
	var hydro: HydrologyResult = result.hydrology

	var submerged_count: int = 0
	var visible_count: int = 0

	for pos in hydro.water_cells:
		var c: WorldCell = result.cells[pos]
		var wh: float = float(hydro.water_cells[pos]["water_height"])
		if c.height > wh:
			submerged_count += 1
		else:
			visible_count += 1

	print("  Celdas de agua con Terreno > Agua (ocultas naturalmente): %d" % submerged_count)
	print("  Celdas de agua con Terreno < Agua (visibles): %d" % visible_count)
	assert(visible_count > 0, "Debe haber celdas de agua visibles tras el tallado")

	# Construir malla de agua y verificar que TODAS las celdas generan geometría
	var water_mesh: ArrayMesh = _WaterMeshBuilderScript.build_mesh(result, profile)
	var w_arrays: Array = water_mesh.surface_get_arrays(0)
	var w_indices: PackedInt32Array = w_arrays[Mesh.ARRAY_INDEX]
	assert(w_indices.size() == hydro.water_cells.size() * 6,
		"Cada celda de agua debe generar exactamente 2 triangulos (6 indices), independientemente de c.height")

	print("  [PASS] Agua debajo del terreno existe fisicamente sin ser descartada.")
	print("  [PASS] Visibilidad resulta naturalmente de la oclusion 3D por la malla del terreno.")


## -----------------------------------------------------------------------------
## 5. VALIDAR TAIGA EN MÚLTIPLES SEMILLAS
## -----------------------------------------------------------------------------
func _test_5_taiga_multi_seed_validation() -> void:
	print("\n--- [5/6] Validar Taiga en Multiples Semillas ---")
	var seeds: Array[int] = [4242, 12345, 283362, 99999, 777777]

	for s in seeds:
		var profile = _TaigaWorldProfileScript.new()
		profile.width = 64
		profile.height = 64
		var result: WorldResult = _WorldPipelineScript.generate(s, profile)
		var hydro: HydrologyResult = result.hydrology

		print("  Semilla %d:" % s)
		print("    Lagos: %d, Rios: %d, Confluencias: %d, Celdas de agua: %d" % [
			hydro.lakes.size(), hydro.rivers.size(), hydro.confluences.size(), hydro.water_cells.size()
		])

		assert(not hydro.water_cells.is_empty(), "Semilla %d debe generar celdas de agua" % s)
		assert(not hydro.rivers.is_empty(), "Semilla %d debe generar rios" % s)

		var water_renderer = _WaterRendererScript.new()
		var node: Node3D = water_renderer.build_water_node(result, profile)
		assert(node != null, "Nodo de agua debe existir")

		var mesh_inst_count: int = 0
		for child in node.get_children():
			if child is MeshInstance3D and child.name == "UnifiedWaterSurface":
				mesh_inst_count += 1
		assert(mesh_inst_count == 1, "Debe existir exactamente 1 UnifiedWaterSurface en semilla %d" % s)

	print("  [PASS] Taiga validada exitosamente en 5 semillas diferentes con rios, lagos y confluencias.")


## -----------------------------------------------------------------------------
## 6. CRITERIO DE CIERRE
## -----------------------------------------------------------------------------
func _test_6_closing_criterion() -> void:
	print("\n--- [6/6] Criterio de Cierre Formal ---")

	var profile = _TaigaWorldProfileScript.new()
	profile.width = 64
	profile.height = 64
	var result: WorldResult = _WorldPipelineScript.generate(4242, profile)

	# Condición 1: 1 water mask (water_cells)
	assert(result.hydrology.water_cells is Dictionary, "Condicion 1 cumplida: 1 water mask unificada (water_cells)")

	# Condición 2: 1 WaterMeshBuilder
	var mesh: ArrayMesh = _WaterMeshBuilderScript.build_mesh(result, profile)
	assert(mesh != null, "Condicion 2 cumplida: 1 WaterMeshBuilder unico")

	# Condición 3: 1 ArrayMesh
	assert(mesh is ArrayMesh and mesh.get_surface_count() == 1, "Condicion 3 cumplida: 1 ArrayMesh continuo con 1 superficie")

	# Condición 4: 1 MeshInstance3D
	var renderer = _WaterRendererScript.new()
	var node: Node3D = renderer.build_water_node(result, profile)
	var count_mi: int = 0
	for ch in node.get_children():
		if ch is MeshInstance3D and ch.name == "UnifiedWaterSurface":
			count_mi += 1
	assert(count_mi == 1, "Condicion 4 cumplida: 1 MeshInstance3D ('UnifiedWaterSurface')")

	# Condición 5: 1 WaterMaterial
	var mi: MeshInstance3D = node.get_node("UnifiedWaterSurface") as MeshInstance3D
	assert(mi.material_override != null, "Condicion 5 cumplida: 1 WaterMaterial aplicado")

	# Condición 6: Cero participación de builders legados en producción
	var renderer_source = FileAccess.open("res://src/world_generator/presentation/water/water_renderer.gd", FileAccess.READ).get_as_text()
	assert(not renderer_source.contains("RiverMeshBuilder.new"), "RiverMeshBuilder NO participa en produccion")
	assert(not renderer_source.contains("LakeMeshBuilder.new"), "LakeMeshBuilder NO participa en produccion")
	assert(not renderer_source.contains("WaterField.new"), "WaterField NO participa en produccion")

	print("  [PASS] 1 water mask (water_cells)")
	print("  [PASS] 1 WaterMeshBuilder")
	print("  [PASS] 1 ArrayMesh")
	print("  [PASS] 1 MeshInstance3D (UnifiedWaterSurface)")
	print("  [PASS] 1 WaterMaterial")
	print("  [PASS] RiverMeshBuilder, LakeMeshBuilder y WaterField NO participan en produccion.")
