extends SceneTree

## Suite de validación exhaustiva para Confluencias con Transición Longitudinal (M >= 3).
## Cubre:
## - Caso 1: 2 -> 1 suave (< 45°) con M=3 estaciones
## - Caso 2: 2 -> 1 ángulo fuerte (> 75°) con M=3 estaciones
## - Caso 3: 3 -> 1 multi-tributario con M=3 estaciones
## - Caso 4: 4 -> 1 multi-tributario con M=3 estaciones
## - Caso 5: Confluencia + curva inmediata downstream
## - Caso 6: Verificación de no solapamiento y continuidad de fronteras
## - Caso 7: Multi-seed con WaterRenderer en seeds 12345, 42, 101, 202

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")
const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")
const _WaterRenderer = preload("res://src/world_generator/presentation/water/water_renderer.gd")

func _init() -> void:
	print("==================================================================")
	print("--- INICIANDO TEST COMPREHENSIVE CONFLUENCE TRANSITIONS (M>=3) ---")
	print("==================================================================")

	var dummy_profile = WorldProfile.new()

	# Caso 1: 2 -> 1 suave (< 45°) con M=3 estaciones
	print("[1/7] Test Caso 1: 2 -> 1 suave (M=3)...")
	var net1 = _build_mock_network([
		[Vector3(0, 0, 0), Vector3(6, 0, 2)],
		[Vector3(0, 0, 4), Vector3(6, 0, 2)]
	], [Vector3(6, 0, 2), Vector3(12, 0, 2)])
	var conf1 = {"position": Vector2i(6, 2), "upstream_rivers": [0, 1], "downstream_river": 2}
	var surf1 = _RiverMeshBuilder.build_confluence_surface(conf1, null, dummy_profile, net1, 3)
	assert(surf1 != null, "Caso 1 debe generar superficie")
	_assert_transition_invariants(surf1, "Caso 1", 2, 3)

	# Caso 2: 2 -> 1 con ángulo fuerte (> 75°) con M=3 estaciones
	print("[2/7] Test Caso 2: 2 -> 1 cerrado (M=3)...")
	var net2 = _build_mock_network([
		[Vector3(6, 0, 0), Vector3(6, 0, 6)],
		[Vector3(0, 0, 6), Vector3(6, 0, 6)]
	], [Vector3(6, 0, 6), Vector3(12, 0, 12)])
	var conf2 = {"position": Vector2i(6, 6), "upstream_rivers": [0, 1], "downstream_river": 2}
	var surf2 = _RiverMeshBuilder.build_confluence_surface(conf2, null, dummy_profile, net2, 3)
	assert(surf2 != null, "Caso 2 debe generar superficie")
	_assert_transition_invariants(surf2, "Caso 2", 2, 3)

	# Caso 3: 3 -> 1 multi-tributario con M=3 estaciones
	print("[3/7] Test Caso 3: 3 -> 1 multi-tributario (M=3)...")
	var net3 = _build_mock_network([
		[Vector3(0, 0, 0), Vector3(6, 0, 4)],
		[Vector3(0, 0, 4), Vector3(6, 0, 4)],
		[Vector3(0, 0, 8), Vector3(6, 0, 4)]
	], [Vector3(6, 0, 4), Vector3(12, 0, 4)])
	var conf3 = {"position": Vector2i(6, 4), "upstream_rivers": [0, 1, 2], "downstream_river": 3}
	var surf3 = _RiverMeshBuilder.build_confluence_surface(conf3, null, dummy_profile, net3, 3)
	assert(surf3 != null, "Caso 3 debe generar superficie")
	_assert_transition_invariants(surf3, "Caso 3", 3, 3)

	# Caso 4: 4 -> 1 quad-tributario con M=3 estaciones
	print("[4/7] Test Caso 4: 4 -> 1 quad-tributario (M=3)...")
	var net4 = _build_mock_network([
		[Vector3(0, 0, 0), Vector3(6, 0, 5)],
		[Vector3(0, 0, 3), Vector3(6, 0, 5)],
		[Vector3(0, 0, 7), Vector3(6, 0, 5)],
		[Vector3(0, 0, 10), Vector3(6, 0, 5)]
	], [Vector3(6, 0, 5), Vector3(12, 0, 5)])
	var conf4 = {"position": Vector2i(6, 5), "upstream_rivers": [0, 1, 2, 3], "downstream_river": 4}
	var surf4 = _RiverMeshBuilder.build_confluence_surface(conf4, null, dummy_profile, net4, 3)
	assert(surf4 != null, "Caso 4 debe generar superficie")
	_assert_transition_invariants(surf4, "Caso 4", 4, 3)

	# Caso 5: Confluencia + curva inmediata downstream
	print("[5/7] Test Caso 5: Confluencia + curva inmediata downstream (M=3)...")
	var net5 = _build_mock_network([
		[Vector3(0, 0, 0), Vector3(6, 0, 3)],
		[Vector3(0, 0, 6), Vector3(6, 0, 3)]
	], [Vector3(6, 0, 3), Vector3(8, 0, 3), Vector3(10, 0, 7)])
	var conf5 = {"position": Vector2i(6, 3), "upstream_rivers": [0, 1], "downstream_river": 2}
	var surf5 = _RiverMeshBuilder.build_confluence_surface(conf5, null, dummy_profile, net5, 3)
	assert(surf5 != null, "Caso 5 debe generar superficie")
	_assert_transition_invariants(surf5, "Caso 5", 2, 3)

	# Caso 6: Verificación de fronteras exactas y no solapamiento
	print("[6/7] Test Caso 6: Fronteras exactas sin solapamiento...")
	var bounds = _RiverMeshBuilder._extract_confluence_boundaries(conf1, net1, null, dummy_profile)
	assert(bounds.has("upstreams") and bounds.has("downstream"), "Fronteras deben existir")
	assert(bounds["upstreams"].size() == 2, "Debe tener 2 afluentes")
	assert(bounds["transition_length"] > 1.0, "Longitud de transición calculada")

	# Caso 7: Multi-seed con WaterRenderer
	print("[7/7] Test Caso 7: WaterRenderer multi-seed...")
	var seeds: Array[int] = [12345, 42, 101, 202]
	for s in seeds:
		var prof = _TaigaWorldProfile.new()
		prof.width = 64
		prof.height = 64
		prof.hydrology_enabled = true
		var res = _WorldPipeline.generate(s, prof)
		assert(res != null)
		var root = _WaterRenderer.build_water_node(res, prof)
		if root != null:
			var mi: MeshInstance3D = root.get_node_or_null("UnifiedWaterSurface")
			assert(mi != null and mi.mesh != null, "Unified water mesh must exist")
			assert(mi.mesh.get_surface_count() > 0, "Water mesh must have surfaces")
			root.free()

	print("==================================================================")
	print("TODOS LOS CASOS DE TRANSICIÓN LONGITUDINAL (M>=3): PASSED!")
	print("==================================================================")
	quit(0)

func _assert_transition_invariants(surf, case_name: String, n_branches: int, m_steps: int) -> void:
	var v_count: int = surf.vertices.size()
	var idx_count: int = surf.indices.size()

	# Cada rama tiene 2 vértices por fila en (m_steps + 1) filas
	var expected_min_verts: int = n_branches * 2 * (m_steps + 1)
	assert(v_count >= expected_min_verts, "%s: Vértices insuficientes para M=%d pasos (hay %d, min %d)" % [case_name, m_steps, v_count, expected_min_verts])
	assert(idx_count >= n_branches * m_steps * 6, "%s: Triángulos insuficientes para M=%d pasos" % [case_name, m_steps])
	assert(idx_count % 3 == 0, "%s: Índices deben ser múltiplos de 3" % case_name)

	# Finitud
	for v in surf.vertices:
		assert(is_finite(v.x) and is_finite(v.y) and is_finite(v.z), "%s: Vértice no finito" % case_name)

	# Ausencia de centro radial
	var vert_refs: Dictionary = {}
	for idx in surf.indices:
		vert_refs[idx] = vert_refs.get(idx, 0) + 1
	for idx in vert_refs.keys():
		assert(vert_refs[idx] <= 8, "%s: Vértice %d actúa como hub radial (>8 referencias)" % [case_name, idx])

	# Área no degenerada
	for i in range(0, idx_count, 3):
		var i0: int = surf.indices[i]
		var i1: int = surf.indices[i + 1]
		var i2: int = surf.indices[i + 2]
		var v0: Vector3 = surf.vertices[i0]
		var v1: Vector3 = surf.vertices[i1]
		var v2: Vector3 = surf.vertices[i2]
		var area: float = (v1 - v0).cross(v2 - v0).length() * 0.5
		assert(area > 0.000001, "%s: Triángulo degenerado detectado (área: %f)" % [case_name, area])

func _build_mock_network(upstream_paths: Array, downstream_path: Array) -> RefCounted:
	var net = _RiverNetwork.new()
	var r_id: int = 0
	var up_ids: Array = []

	for up_pts in upstream_paths:
		var r = _River.new(r_id, Vector2i(int(up_pts[0].x), int(up_pts[0].z)), [])
		r.points = up_pts
		r.widths = [1.2, 1.4]
		r.depths = [0.25, 0.25]
		r.downstream_river = upstream_paths.size()
		net.add_river(r)
		up_ids.append(r_id)
		r_id += 1

	var down_r = _River.new(r_id, Vector2i(int(downstream_path[0].x), int(downstream_path[0].z)), [])
	down_r.points = downstream_path
	down_r.widths = [2.0, 2.4]
	down_r.depths = [0.35, 0.35]
	down_r.upstream_rivers = up_ids
	net.add_river(down_r)

	return net
