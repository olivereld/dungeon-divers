extends SceneTree

## Suite de validación exhaustiva para el generador de mallas de río.
## Cubre los casos de Bloque 8 y las invariantes topológicas de Bloque 9:
## - Caso A: Río recto
## - Caso B: Curva suave
## - Caso C: Curva de 90°
## - Caso D: Meandro S-curve (anti self-intersection)
## - Caso E: Río estrecho
## - Caso F: Río ancho
## - Caso G: Pipeline procedural multi-seed

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")

func _init() -> void:
	print("==================================================")
	print("--- INICIANDO TEST COMPREHENSIVE RIVER RIBBON ---")
	print("==================================================")

	var dummy_profile = WorldProfile.new()

	# Caso A: Río recto
	print("[1/7] Test Caso A: Río recto...")
	var pts_a: Array = [
		Vector3(0, 0, 0), Vector3(0, 0, 2), Vector3(0, 0, 4), Vector3(0, 0, 6)
	]
	var river_a = {"points": pts_a, "widths": [1.0, 1.0, 1.0, 1.0], "depths": [0.2, 0.2, 0.2, 0.2]}
	var surf_a = _RiverMeshBuilder.build_river_surface(river_a, null, dummy_profile)
	assert(surf_a != null, "Caso A debe generar superficie")
	_assert_ribbon_invariants(surf_a, "Caso A")

	# Caso B: Curva suave
	print("[2/7] Test Caso B: Curva suave...")
	var pts_b: Array = [
		Vector3(0, 0, 0), Vector3(0.5, 0, 2), Vector3(1.5, 0, 4), Vector3(3.0, 0, 6)
	]
	var river_b = {"points": pts_b, "widths": [1.2, 1.2, 1.2, 1.2], "depths": [0.25, 0.25, 0.25, 0.25]}
	var surf_b = _RiverMeshBuilder.build_river_surface(river_b, null, dummy_profile)
	assert(surf_b != null, "Caso B debe generar superficie")
	_assert_ribbon_invariants(surf_b, "Caso B")

	# Caso C: Curva de 90°
	print("[3/7] Test Caso C: Curva de 90°...")
	var pts_c: Array = [
		Vector3(0, 0, 0), Vector3(0, 0, 3), Vector3(3, 0, 3), Vector3(6, 0, 3)
	]
	var river_c = {"points": pts_c, "widths": [1.5, 1.5, 1.5, 1.5], "depths": [0.3, 0.3, 0.3, 0.3]}
	var surf_c = _RiverMeshBuilder.build_river_surface(river_c, null, dummy_profile)
	assert(surf_c != null, "Caso C debe generar superficie")
	_assert_ribbon_invariants(surf_c, "Caso C")

	# Caso D: Meandro S-curve
	print("[4/7] Test Caso D: Meandro S-curve...")
	var pts_d: Array = [
		Vector3(0, 0, 0), Vector3(1.5, 0, 1.5), Vector3(0, 0, 3.0), Vector3(-1.5, 0, 4.5), Vector3(0, 0, 6.0)
	]
	var river_d = {"points": pts_d, "widths": [1.8, 1.8, 1.8, 1.8, 1.8], "depths": [0.3, 0.3, 0.3, 0.3, 0.3]}
	var surf_d = _RiverMeshBuilder.build_river_surface(river_d, null, dummy_profile)
	assert(surf_d != null, "Caso D debe generar superficie")
	_assert_ribbon_invariants(surf_d, "Caso D")

	# Caso E: Río estrecho
	print("[5/7] Test Caso E: Río estrecho (width = 0.25)...")
	var river_e = {"points": pts_a, "widths": [0.25, 0.25, 0.25, 0.25], "depths": [0.1, 0.1, 0.1, 0.1]}
	var surf_e = _RiverMeshBuilder.build_river_surface(river_e, null, dummy_profile)
	assert(surf_e != null, "Caso E debe generar superficie")
	_assert_ribbon_invariants(surf_e, "Caso E")

	# Caso F: Río ancho
	print("[6/7] Test Caso F: Río ancho (width = 3.0)...")
	var river_f = {"points": pts_b, "widths": [3.0, 3.0, 3.0, 3.0], "depths": [0.5, 0.5, 0.5, 0.5]}
	var surf_f = _RiverMeshBuilder.build_river_surface(river_f, null, dummy_profile)
	assert(surf_f != null, "Caso F debe generar superficie")
	_assert_ribbon_invariants(surf_f, "Caso F")

	# Caso G: Multi-seed en el pipeline procedural
	print("[7/7] Test Caso G: Pipeline procedural multi-seed...")
	var test_seeds: Array[int] = [101, 202, 303]
	for s in test_seeds:
		var p = _TaigaWorldProfile.new()
		p.width = 48
		p.height = 48
		p.hydrology_enabled = true
		var res = _WorldPipeline.generate(s, p)
		assert(res != null and res.hydrology != null)
		for r in res.hydrology.rivers:
			var s_r = _RiverMeshBuilder.build_river_surface(r, res, p)
			if s_r != null:
				_assert_ribbon_invariants(s_r, "Multi-seed %d river" % s)

	print("==================================================")
	print("TODOS LOS CASOS DE TEST RIVER RIBBON: PASSED!")
	print("==================================================")
	quit(0)

func _assert_ribbon_invariants(surf, case_name: String) -> void:
	var v_count: int = surf.vertices.size()
	var idx_count: int = surf.indices.size()

	# 1. Mínimo 4 vértices (2 secciones) y 6 índices (2 triángulos)
	assert(v_count >= 4, "%s: Debe tener mínimo 4 vértices" % case_name)
	assert(v_count % 2 == 0, "%s: Debe tener un número par de vértices (2 por estación)" % case_name)
	assert(idx_count >= 6, "%s: Debe tener mínimo 6 índices" % case_name)
	assert(idx_count % 6 == 0, "%s: Debe tener exactamente múltiplos de 6 índices (2 triángulos por quad)" % case_name)

	var num_quads: int = (v_count / 2) - 1
	var expected_triangles: int = num_quads * 2
	assert(idx_count / 3 == expected_triangles, "%s: Número de triángulos debe ser exactamente 2 por segmento" % case_name)

	# 2. Sanidad de coordenadas y áreas
	for v in surf.vertices:
		assert(is_finite(v.x) and is_finite(v.y) and is_finite(v.z), "%s: Vértice contiene valores no finitos" % case_name)

	for i in range(0, idx_count, 3):
		var i0: int = surf.indices[i]
		var i1: int = surf.indices[i + 1]
		var i2: int = surf.indices[i + 2]
		assert(i0 != i1 and i1 != i2 and i0 != i2, "%s: Triángulo con índices idénticos" % case_name)

		var v0: Vector3 = surf.vertices[i0]
		var v1: Vector3 = surf.vertices[i1]
		var v2: Vector3 = surf.vertices[i2]
		var area: float = (v1 - v0).cross(v2 - v0).length() * 0.5
		assert(area > 0.000001, "%s: Triángulo degenerado detectado (área: %f)" % [case_name, area])

	# 3. Comprobar que no hay aristas que se crucen entre lados L y R
	var stations: int = v_count / 2
	for i in range(stations - 1):
		var l0: Vector3 = surf.vertices[i * 2]
		var r0: Vector3 = surf.vertices[i * 2 + 1]
		var l1: Vector3 = surf.vertices[(i + 1) * 2]
		var r1: Vector3 = surf.vertices[(i + 1) * 2 + 1]

		var p_l0 := Vector2(l0.x, l0.z)
		var p_l1 := Vector2(l1.x, l1.z)
		var p_r0 := Vector2(r0.x, r0.z)
		var p_r1 := Vector2(r1.x, r1.z)

		assert(not _RiverMeshBuilder._segments_intersect_2d(p_l0, p_l1, p_r0, p_r1),
			"%s: Segmento %d tiene aristas L y R que se cruzan (self-intersection)" % [case_name, i])
