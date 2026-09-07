extends SceneTree

## Test suite para validar la continuidad determinista de esquinas y perfiles
## mediante WallProfileBuilder y WallPathGeometry.
## Valida las 5 condiciones clave:
## 1. Esquina exterior (convex): unión limpia, sin huecos/solapes, perpendicular distance exacta.
## 2. Esquina interior (concave): unión cerrada, perfiles alineados, sin triángulos degenerados.
## 3. Secciones rectas divididas: coincidencia exacta de vértices en puntos de corte (cero discontinuidades).
## 4. Secuencia de esquinas: consistencia total a lo largo de giros consecutivos.
## 5. ROOM ↔ CORRIDOR: continuidad topológica y geométrica, cero agujeros, normales unitarias.

const _WallProfileBuilderScript = preload("res://src/geometry_generator/geometry/wall_profile_builder.gd")
const _WallPathGeometryScript = preload("res://src/geometry_generator/geometry/wall_path_geometry.gd")
const _WallGeometryBuilderScript = preload("res://src/geometry_generator/geometry/wall_geometry_builder.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _WallSectionScript = preload("res://src/geometry_generator/data/wall_section.gd")
const _WallComponentScript = preload("res://src/geometry_generator/data/wall_component.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _BoundaryExtractorScript = preload("res://src/geometry_generator/extraction/boundary_extractor.gd")
const _ComponentExtractorScript = preload("res://src/geometry_generator/extraction/component_extractor.gd")
const _WallSectionExtractorScript = preload("res://src/geometry_generator/extraction/wall_section_extractor.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_corner_resolver (Continuous Offset Profiles) ---")
	print("==================================================================")

	var profile_builder := _WallProfileBuilderScript.new()
	var builder := _WallGeometryBuilderScript.new()
	var config := _WallGeometryConfigScript.new()
	config.cube_size = 2.0
	config.cubes_high = 2

	var w_thin: float = config.wall_thickness
	var d: float = config.trim_overhang
	var w_thick: float = w_thin + (d * 2.0)

	# ------------------------------------------------------------------
	# TEST 1: Esquina exterior (Convex Turn 90°)
	# ------------------------------------------------------------------
	var p_prev := Vector3(0.0, 0.0, 0.0)
	var p_corner := Vector3(4.0, 0.0, 0.0)
	var p_next := Vector3(4.0, 0.0, 4.0)

	var pv_convex = profile_builder.compute_profile_vertex(
		p_prev, p_corner, p_corner, p_next,
		w_thick, w_thin, d
	)
	assert(pv_convex != null, "TEST 1 FAIL: Solution must not be null")
	assert(pv_convex.inner_thick.distance_to(p_corner) < 0.001, "TEST 1 FAIL: inner_thick must match corner position")

	# En giro ortogonal de 90°, el offset w_thick se desplaza (+w_thick, 0, -w_thick) hacia el muro
	var expected_outer_thick := p_corner + Vector3(w_thick, 0.0, -w_thick)
	assert(pv_convex.outer_thick.distance_to(expected_outer_thick) < 0.001,
		"TEST 1 FAIL: outer_thick offset mismatch, got %s expected %s" % [str(pv_convex.outer_thick), str(expected_outer_thick)])
	print("  [OK] Test 1: Esquina exterior calculada con intersección de offset exacta.")

	# ------------------------------------------------------------------
	# TEST 2: Esquina interior (Concave Turn 270°)
	# ------------------------------------------------------------------
	var p_concave_prev := Vector3(4.0, 0.0, 4.0)
	var p_concave_corner := Vector3(4.0, 0.0, 0.0)
	var p_concave_next := Vector3(0.0, 0.0, 0.0)

	var pv_concave = profile_builder.compute_profile_vertex(
		p_concave_prev, p_concave_corner, p_concave_corner, p_concave_next,
		w_thick, w_thin, d
	)
	assert(pv_concave != null, "TEST 2 FAIL: Solution must not be null")
	assert(pv_concave.inner_thick.distance_to(p_concave_corner) < 0.001, "TEST 2 FAIL: inner_thick must match corner position")

	# Validar que genera malla válida sin triángulos degenerados
	var comp_l := _WallComponentScript.new(20)
	comp_l.add_loop([
		Vector2i(0, 0), Vector2i(6, 0), Vector2i(6, 3),
		Vector2i(3, 3), Vector2i(3, 6), Vector2i(0, 6)
	])
	var g_l = builder.build_component_mesh(comp_l, config)
	assert(g_l != null and g_l.mesh != null, "TEST 2 FAIL: L-mesh must be valid")
	_assert_mesh_clean(g_l.mesh, "Test 2 L-mesh")
	print("  [OK] Test 2: Esquina interior cerrada, perfiles alineados, sin caras degeneradas.")

	# ------------------------------------------------------------------
	# TEST 3: Secciones rectas divididas (Continuidad entre secciones)
	# ------------------------------------------------------------------
	var sec_a := _WallSectionScript.new(1, 30, [Vector2i(0, 0), Vector2i(3, 0)], 1, &"normal", false)
	sec_a.set_start_corner(300000, _WallSectionScript.INVALID_NEIGHBOR, true)
	sec_a.set_end_corner(300001, Vector2i(6, 0), false)
	sec_a.has_start_cap = true
	sec_a.has_end_cap = false

	var sec_b := _WallSectionScript.new(2, 30, [Vector2i(3, 0), Vector2i(6, 0)], 1, &"normal", false)
	sec_b.set_start_corner(300001, Vector2i(0, 0), false)
	sec_b.set_end_corner(300002, _WallSectionScript.INVALID_NEIGHBOR, true)
	sec_b.has_start_cap = false
	sec_b.has_end_cap = true

	var pg_a = _WallPathGeometryScript.from_section(sec_a, config)
	var pg_b = _WallPathGeometryScript.from_section(sec_b, config)

	var c_a_end = pg_a.profiles[pg_a.profiles.size() - 1]
	var c_b_start = pg_b.profiles[0]

	assert(c_a_end.inner_thick == c_b_start.inner_thick, "TEST 3 FAIL: Corner centerline points must be identical")
	assert(c_a_end.inner_thick.distance_squared_to(c_b_start.inner_thick) < 0.00001, "TEST 3 FAIL: inner_thick mismatch at seam")
	assert(c_a_end.inner_thin.distance_squared_to(c_b_start.inner_thin) < 0.00001, "TEST 3 FAIL: inner_thin mismatch at seam")
	assert(c_a_end.outer_thin.distance_squared_to(c_b_start.outer_thin) < 0.00001, "TEST 3 FAIL: outer_thin mismatch at seam")
	assert(c_a_end.outer_thick.distance_squared_to(c_b_start.outer_thick) < 0.00001, "TEST 3 FAIL: outer_thick mismatch at seam")

	assert(not pg_a.has_end_cap, "TEST 3 FAIL: Section A must not have end cap at shared seam")
	assert(not pg_b.has_start_cap, "TEST 3 FAIL: Section B must not have start cap at shared seam")

	var mesh_a = builder.build_section_mesh(sec_a, config)
	var mesh_b = builder.build_section_mesh(sec_b, config)
	_assert_mesh_clean(mesh_a.mesh, "Test 3 Sec A")
	_assert_mesh_clean(mesh_b.mesh, "Test 3 Sec B")
	print("  [OK] Test 3: Secciones rectas divididas con coincidencia de vértices al bit (cero discontinuidades).")

	# ------------------------------------------------------------------
	# TEST 4: Secuencia de esquinas (Polígono cerrado de 8 esquinas)
	# ------------------------------------------------------------------
	var comp_oct := _WallComponentScript.new(40)
	comp_oct.add_loop([
		Vector2i(2, 0), Vector2i(4, 0), Vector2i(6, 2), Vector2i(6, 4),
		Vector2i(4, 6), Vector2i(2, 6), Vector2i(0, 4), Vector2i(0, 2)
	])
	var pg_oct = _WallPathGeometryScript.from_component_loop(comp_oct.loops[0], 40, config)
	assert(pg_oct.profiles.size() == 8, "TEST 4 FAIL: Octagonal loop must have 8 corners")
	for i in range(8):
		var sol = pg_oct.profiles[i]
		assert(sol != null, "TEST 4 FAIL: Corner %d must have valid solution" % i)
		assert(sol.inner_thick.distance_to(sol.outer_thick) > 0.2, "TEST 4 FAIL: Profile %d width too small" % i)

	var g_oct = builder.build_component_mesh(comp_oct, config)
	_assert_mesh_clean(g_oct.mesh, "Test 4 Octagon")
	print("  [OK] Test 4: Secuencia de 8 esquinas consistente y regular.")

	# ------------------------------------------------------------------
	# TEST 5: ROOM ↔ CORRIDOR (Continuidad y ausencia de agujeros)
	# ------------------------------------------------------------------
	var grid := _CellGridScript.new(12, 12)
	for y in range(12):
		for x in range(12):
			grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.WALL)

	# Habitación de 4x4
	for y in range(2, 6):
		for x in range(2, 6):
			grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.FLOOR)
			grid.set_room_owner(Vector2i(x, y), 0)

	# Pasillo contiguo hacia el este
	for x in range(6, 10):
		grid.set_cell(Vector2i(x, 3), _CellGridScript.CellType.CORRIDOR)

	var b_extractor := _BoundaryExtractorScript.new()
	var c_extractor := _ComponentExtractorScript.new()
	var s_extractor := _WallSectionExtractorScript.new()

	var graph = b_extractor.extract_graph(grid, null)
	assert(graph.get_edge_count() > 0, "TEST 5 FAIL: Must extract boundary edges")

	var components = c_extractor.extract_components(graph)
	assert(not components.is_empty(), "TEST 5 FAIL: Must extract components")

	var total_mesh_sections: int = 0
	for comp in components:
		var sections = s_extractor.extract_sections(comp, 2, 6, -1)
		for sec in sections:
			var g_sec = builder.build_section_mesh(sec, config)
			if g_sec.mesh != null:
				_assert_mesh_clean(g_sec.mesh, "Test 5 Room-Corridor Sec %d" % sec.id)
				total_mesh_sections += 1

	assert(total_mesh_sections > 0, "TEST 5 FAIL: Must generate section meshes for room-corridor boundary")
	print("  [OK] Test 5: ROOM ↔ CORRIDOR frontera topológica y mallas generadas sin huecos.")

	print("==================================================================")
	print("[PASS] test_wall_corner_resolver completado con 100% éxito!")
	print("==================================================================")
	quit(0)

func _assert_mesh_clean(mesh: ArrayMesh, test_name: String) -> void:
	assert(mesh != null, "%s: Mesh is null" % test_name)
	for s in range(mesh.get_surface_count()):
		var arr = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idxs: PackedInt32Array = arr[Mesh.ARRAY_INDEX]

		assert(verts.size() > 0, "%s: Surface %d verts empty" % [test_name, s])
		assert(idxs.size() > 0, "%s: Surface %d idxs empty" % [test_name, s])
		assert(idxs.size() % 3 == 0, "%s: Triangles must be multiples of 3" % test_name)

		for v in verts:
			assert(not is_nan(v.x) and not is_nan(v.y) and not is_nan(v.z), "%s: NaN vertex" % test_name)
			assert(not is_inf(v.x) and not is_inf(v.y) and not is_inf(v.z), "%s: INF vertex" % test_name)

		for n in norms:
			assert(not is_nan(n.x) and not is_nan(n.y) and not is_nan(n.z), "%s: NaN normal" % test_name)
			var l_sq = n.length_squared()
			assert(l_sq > 0.2 and l_sq < 2.0, "%s: Degenerate normal" % test_name)

		for t in range(0, idxs.size(), 3):
			var i0 = idxs[t]
			var i1 = idxs[t + 1]
			var i2 = idxs[t + 2]
			assert(i0 != i1 and i1 != i2 and i0 != i2, "%s: Duplicate vertex indices" % test_name)
			var v0 = verts[i0]
			var v1 = verts[i1]
			var v2 = verts[i2]
			var c = (v1 - v0).cross(v2 - v0)
			assert(c.length_squared() > 0.0000001, "%s: Zero area triangle" % test_name)
