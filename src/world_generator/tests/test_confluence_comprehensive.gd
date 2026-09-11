extends SceneTree

## Suite de validación exhaustiva para confluencias continuas (Bloques C1 al C11).
## Cubre los 5 casos geométricos de Bloque C9 y prueba multi-seed con WaterRenderer.

const _RiverMeshBuilder = preload("res://src/world_generator/presentation/water/river_mesh_builder.gd")
const _River = preload("res://src/world_generator/hydrology/river.gd")
const _RiverNetwork = preload("res://src/world_generator/hydrology/river_network.gd")
const _TaigaWorldProfile = preload("res://src/world_generator/profiles/taiga_world_profile.gd")
const _WorldPipeline = preload("res://src/world_generator/facade/world_pipeline.gd")
const _WaterRenderer = preload("res://src/world_generator/presentation/water/water_renderer.gd")

func _init() -> void:
	print("==========================================================")
	print("--- INICIANDO TEST COMPREHENSIVE CONFLUENCES ---")
	print("==========================================================")

	var dummy_profile = WorldProfile.new()

	# Caso 1: 2 -> 1 suave (< 45°)
	print("[1/6] Test Caso 1: 2 -> 1 suave...")
	var net1 = _build_mock_network([
		[Vector3(0, 0, 0), Vector3(5, 0, 2)],   # up1
		[Vector3(0, 0, 4), Vector3(5, 0, 2)]    # up2
	], [Vector3(5, 0, 2), Vector3(10, 0, 2)])   # down
	var conf1 = {"position": Vector2i(5, 2), "upstream_rivers": [0, 1], "downstream_river": 2}
	var surf1 = _RiverMeshBuilder.build_confluence_surface(conf1, null, dummy_profile, net1)
	assert(surf1 != null, "Caso 1 debe generar superficie")
	_assert_confluence_invariants(surf1, "Caso 1")

	# Caso 2: 2 -> 1 con ángulo fuerte (> 75°)
	print("[2/6] Test Caso 2: 2 -> 1 con ángulo fuerte...")
	var net2 = _build_mock_network([
		[Vector3(5, 0, 0), Vector3(5, 0, 5)],   # up1 from North
		[Vector3(0, 0, 5), Vector3(5, 0, 5)]    # up2 from West (90° between them)
	], [Vector3(5, 0, 5), Vector3(10, 0, 10)])  # down South-East
	var conf2 = {"position": Vector2i(5, 5), "upstream_rivers": [0, 1], "downstream_river": 2}
	var surf2 = _RiverMeshBuilder.build_confluence_surface(conf2, null, dummy_profile, net2)
	assert(surf2 != null, "Caso 2 debe generar superficie")
	_assert_confluence_invariants(surf2, "Caso 2")

	# Caso 3: 2 -> 1 con ángulos asimétricos
	print("[3/6] Test Caso 3: 2 -> 1 asimétrico...")
	var net3 = _build_mock_network([
		[Vector3(0, 0, 2), Vector3(5, 0, 2)],   # up1 straight
		[Vector3(2, 0, 6), Vector3(5, 0, 2)]    # up2 diagonal
	], [Vector3(5, 0, 2), Vector3(12, 0, 2)])   # down
	var conf3 = {"position": Vector2i(5, 2), "upstream_rivers": [0, 1], "downstream_river": 2}
	var surf3 = _RiverMeshBuilder.build_confluence_surface(conf3, null, dummy_profile, net3)
	assert(surf3 != null, "Caso 3 debe generar superficie")
	_assert_confluence_invariants(surf3, "Caso 3")

	# Caso 4: 3 -> 1 multi-tributario
	print("[4/6] Test Caso 4: 3 -> 1 multi-tributario...")
	var net4 = _build_mock_network([
		[Vector3(0, 0, 0), Vector3(5, 0, 3)],   # up1
		[Vector3(0, 0, 3), Vector3(5, 0, 3)],   # up2
		[Vector3(0, 0, 6), Vector3(5, 0, 3)]    # up3
	], [Vector3(5, 0, 3), Vector3(10, 0, 3)])   # down
	var conf4 = {"position": Vector2i(5, 3), "upstream_rivers": [0, 1, 2], "downstream_river": 3}
	var surf4 = _RiverMeshBuilder.build_confluence_surface(conf4, null, dummy_profile, net4)
	assert(surf4 != null, "Caso 4 debe generar superficie")
	_assert_confluence_invariants(surf4, "Caso 4")

	# Caso 5: Confluencia con curva inmediata downstream
	print("[5/6] Test Caso 5: Confluencia + curva inmediata downstream...")
	var net5 = _build_mock_network([
		[Vector3(0, 0, 0), Vector3(4, 0, 2)],
		[Vector3(0, 0, 4), Vector3(4, 0, 2)]
	], [Vector3(4, 0, 2), Vector3(6, 0, 2), Vector3(8, 0, 6)]) # curve right after junction
	var conf5 = {"position": Vector2i(4, 2), "upstream_rivers": [0, 1], "downstream_river": 2}
	var surf5 = _RiverMeshBuilder.build_confluence_surface(conf5, null, dummy_profile, net5)
	assert(surf5 != null, "Caso 5 debe generar superficie")
	_assert_confluence_invariants(surf5, "Caso 5")

	# Caso 6: Integración procedural multi-seed en WaterRenderer
	print("[6/6] Test Caso 6: WaterRenderer multi-seed...")
	var seeds: Array[int] = [12345, 42, 101, 777]
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

	print("==========================================================")
	print("TODOS LOS CASOS DE CONFLUENCIA: PASSED!")
	print("==========================================================")
	quit(0)

func _assert_confluence_invariants(surf, case_name: String) -> void:
	var v_count: int = surf.vertices.size()
	var idx_count: int = surf.indices.size()

	assert(v_count >= 5, "%s: Debe tener vértices de contorno" % case_name)
	assert(idx_count >= 6, "%s: Debe tener triángulos de unión" % case_name)
	assert(idx_count % 3 == 0, "%s: Índices deben ser múltiplos de 3" % case_name)

	# 1. No NaN / Inf
	for v in surf.vertices:
		assert(is_finite(v.x) and is_finite(v.y) and is_finite(v.z), "%s: Vértice contiene coordenadas no finitas" % case_name)

	# 2. Ausencia de centro radial (ningún vértice es compartido por un abanico radial desmesurado)
	var vert_refs: Dictionary = {}
	for idx in surf.indices:
		vert_refs[idx] = vert_refs.get(idx, 0) + 1
	for idx in vert_refs.keys():
		assert(vert_refs[idx] <= 6, "%s: Vértice %d actúa como hub radial (>6 referencias)" % [case_name, idx])

	# 3. Triángulos válidos
	for i in range(0, idx_count, 3):
		var i0: int = surf.indices[i]
		var i1: int = surf.indices[i + 1]
		var i2: int = surf.indices[i + 2]
		var v0: Vector3 = surf.vertices[i0]
		var v1: Vector3 = surf.vertices[i1]
		var v2: Vector3 = surf.vertices[i2]
		var area: float = (v1 - v0).cross(v2 - v0).length() * 0.5
		assert(area > 0.000001, "%s: Triángulo degenerado (área: %f)" % [case_name, area])

func _build_mock_network(upstream_paths: Array, downstream_path: Array) -> RefCounted:
	var net = _RiverNetwork.new()
	var r_id: int = 0
	var up_ids: Array = []

	for up_pts in upstream_paths:
		var r = _River.new(r_id, Vector2i(int(up_pts[0].x), int(up_pts[0].z)), [])
		r.points = up_pts
		r.widths = [1.2, 1.4]
		r.depths = [0.25, 0.25]
		r.downstream_river = upstream_paths.size() # index of downstream
		net.add_river(r)
		up_ids.append(r_id)
		r_id += 1

	var down_r = _River.new(r_id, Vector2i(int(downstream_path[0].x), int(downstream_path[0].z)), [])
	down_r.points = downstream_path
	down_r.widths = [1.8, 2.0]
	down_r.depths = [0.35, 0.35]
	down_r.upstream_rivers = up_ids
	net.add_river(down_r)

	return net
