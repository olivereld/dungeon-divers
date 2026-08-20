extends SceneTree

## Test suite de endurecimiento geométrico y topología de miters (Fase M1 & M2 Hardening).
## Verifica rigurosamente casos ortogonales y poligonales complejos:
## Rectángulos, salas en L, salas en U, salas en T, segmentos colineales (180°),
## ausencia absoluta de NaNs, INFs, triángulos degenerados y normales nulas.

const WallComponent = preload("res://src/geometry_generator/data/wall_component.gd")
const WallGeometryConfig = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const WallGeometryBuilder = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const GeneratedMesh = preload("res://src/geometry_generator/data/generated_mesh.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_geometry_hardening (Miters & Topology) ---")
	print("==================================================================")

	var builder := WallGeometryBuilder.new()
	var cfg := WallGeometryConfig.new()
	cfg.cube_size = 2.0
	cfg.cubes_high = 2

	# 1. Caso A: Rectángulo estándar (4 esquinas convexas de 90°)
	var comp_rect := WallComponent.new(1)
	comp_rect.add_loop([
		Vector2i(0, 0), Vector2i(6, 0), Vector2i(6, 4), Vector2i(0, 4)
	])
	var g_rect: GeneratedMesh = builder.build_component_mesh(comp_rect, cfg)
	_assert_mesh_valid(g_rect.mesh, "A: Rectángulo estándar (4 esquinas 90°)")

	# 2. Caso B: Sala en forma de L (5 esquinas convexas, 1 esquina cóncava de 270°)
	var comp_l := WallComponent.new(2)
	comp_l.add_loop([
		Vector2i(0, 0), Vector2i(6, 0), Vector2i(6, 3),
		Vector2i(3, 3), Vector2i(3, 6), Vector2i(0, 6)
	])
	var g_l: GeneratedMesh = builder.build_component_mesh(comp_l, cfg)
	_assert_mesh_valid(g_l.mesh, "B: Sala en L (esquina cóncava 270°)")

	# 3. Caso C: Sala en forma de U (6 esquinas convexas, 2 esquinas cóncavas internas)
	var comp_u := WallComponent.new(3)
	comp_u.add_loop([
		Vector2i(0, 0), Vector2i(8, 0), Vector2i(8, 6),
		Vector2i(6, 6), Vector2i(6, 2), Vector2i(2, 2),
		Vector2i(2, 6), Vector2i(0, 6)
	])
	var g_u: GeneratedMesh = builder.build_component_mesh(comp_u, cfg)
	_assert_mesh_valid(g_u.mesh, "C: Sala en U (dos concavidades)")

	# 4. Caso D: Sala en forma de T (cruces con 8 vértices)
	var comp_t := WallComponent.new(4)
	comp_t.add_loop([
		Vector2i(2, 0), Vector2i(6, 0), Vector2i(6, 3),
		Vector2i(8, 3), Vector2i(8, 6), Vector2i(0, 6),
		Vector2i(0, 3), Vector2i(2, 3)
	])
	var g_t: GeneratedMesh = builder.build_component_mesh(comp_t, cfg)
	_assert_mesh_valid(g_t.mesh, "D: Sala en T (cruces y esquinas)")

	# 5. Caso E: Segmentos colineales consecutivos (ángulo de 180°, miters paralelos)
	var comp_col := WallComponent.new(5)
	comp_col.add_loop([
		Vector2i(0, 0), Vector2i(2, 0), Vector2i(4, 0), Vector2i(6, 0),
		Vector2i(6, 4), Vector2i(0, 4)
	])
	var g_col: GeneratedMesh = builder.build_component_mesh(comp_col, cfg)
	_assert_mesh_valid(g_col.mesh, "E: Segmentos colineales a 180°")

	# 6. Caso F: Loop mínimo de 3x3 celdas con orden horario (CW)
	var comp_cw := WallComponent.new(6)
	comp_cw.add_loop([
		Vector2i(1, 1), Vector2i(4, 1), Vector2i(4, 4), Vector2i(1, 4)
	])
	var g_cw: GeneratedMesh = builder.build_component_mesh(comp_cw, cfg)
	_assert_mesh_valid(g_cw.mesh, "F: Loop orden horario CW")

	print("==================================================================")
	print("[PASS] test_wall_geometry_hardening completado con 100% éxito!")
	print("==================================================================")
	quit(0)

func _assert_mesh_valid(mesh: ArrayMesh, test_name: String) -> void:
	assert(mesh != null, "%s: Mesh is null" % test_name)
	assert(mesh.get_surface_count() >= 2, "%s: Must have at least 2 surfaces" % test_name)

	for s in range(mesh.get_surface_count()):
		var arr = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idxs: PackedInt32Array = arr[Mesh.ARRAY_INDEX]

		assert(verts.size() > 0, "%s: Surface %d has 0 vertices" % [test_name, s])
		assert(idxs.size() > 0, "%s: Surface %d has 0 indices" % [test_name, s])
		assert(idxs.size() % 3 == 0, "%s: Surface %d index count (%d) is not divisible by 3" % [test_name, s, idxs.size()])

		# Validar vértices: no NaNs, no INFs
		for v in verts:
			assert(not is_nan(v.x) and not is_nan(v.y) and not is_nan(v.z), "%s: Vertex contains NaN (%s)" % [test_name, str(v)])
			assert(not is_inf(v.x) and not is_inf(v.y) and not is_inf(v.z), "%s: Vertex contains INF (%s)" % [test_name, str(v)])

		# Validar normales: unitarias y no nulas
		for n in norms:
			assert(not is_nan(n.x) and not is_nan(n.y) and not is_nan(n.z), "%s: Normal contains NaN" % test_name)
			var len_sq: float = n.length_squared()
			assert(len_sq > 0.2 and len_sq < 2.0, "%s: Normal is degenerate or zero (len_sq=%.3f)" % [test_name, len_sq])

		# Validar que ningún triángulo tenga área cero (triángulos degenerados)
		for t in range(0, idxs.size(), 3):
			var i0: int = idxs[t]
			var i1: int = idxs[t + 1]
			var i2: int = idxs[t + 2]
			assert(i0 != i1 and i1 != i2 and i0 != i2, "%s: Triangle has duplicate vertex indices (%d, %d, %d)" % [test_name, i0, i1, i2])

			var v0: Vector3 = verts[i0]
			var v1: Vector3 = verts[i1]
			var v2: Vector3 = verts[i2]
			var cross_vec: Vector3 = (v1 - v0).cross(v2 - v0)
			assert(cross_vec.length_squared() > 0.0000001, "%s: Triangle has zero area / collinear vertices" % test_name)

	print("  [OK] %s verificado con geometría estricta y sin degeneraciones." % test_name)
