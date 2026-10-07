extends SceneTree

const _FoliageMeshFactoryScript = preload("res://src/world_generator/foliage/rendering/foliage_mesh_factory.gd")

func _init() -> void:
	print("==================================================")
	print(" Running Foliage Mesh Factory Test Suite (Tarea 2)")
	print("==================================================")

	# 1. Crear malla de 2 quads cruzados (X-cross 90°)
	var mesh_2 = _FoliageMeshFactoryScript.create_crossed_quad_mesh(2, 1.0, 1.0)
	assert(mesh_2 != null, "Mesh 2-quads must be created")
	assert(mesh_2 is ArrayMesh, "Mesh must be an ArrayMesh")
	assert(mesh_2.get_surface_count() == 1, "Mesh must have 1 surface")

	var arrays_2: Array = mesh_2.surface_get_arrays(0)
	var verts_2: PackedVector3Array = arrays_2[Mesh.ARRAY_VERTEX]
	var uvs_2: PackedVector2Array = arrays_2[Mesh.ARRAY_TEX_UV]
	var uv2s_2: PackedVector2Array = arrays_2[Mesh.ARRAY_TEX_UV2]
	var normals_2: PackedVector3Array = arrays_2[Mesh.ARRAY_NORMAL]
	var indices_2: PackedInt32Array = arrays_2[Mesh.ARRAY_INDEX]

	# 2 quads = 8 vértices, 12 índices (4 triángulos)
	assert(verts_2.size() == 8, "2 quads must have 8 vertices, got: %d" % verts_2.size())
	assert(indices_2.size() == 12, "2 quads must have 12 indices, got: %d" % indices_2.size())
	assert(uvs_2.size() == 8, "Must have 8 UVs")
	assert(uv2s_2.size() == 8, "Must have 8 UV2s for wind weights")
	assert(normals_2.size() == 8, "Must have 8 normals")

	# Comprobar que la base tiene Y = 0 y la punta Y = 1
	var min_y: float = INF
	var max_y: float = -INF
	for v in verts_2:
		if v.y < min_y: min_y = v.y
		if v.y > max_y: max_y = v.y

	assert(is_equal_approx(min_y, 0.0), "Base of mesh must be at Y = 0.0")
	assert(is_equal_approx(max_y, 1.0), "Top of mesh must be at Y = 1.0")

	# Comprobar pesos de viento en UV2.y: base = 0.0, punta = 1.0
	for i in range(verts_2.size()):
		var v = verts_2[i]
		var w = uv2s_2[i].y
		if is_equal_approx(v.y, 0.0):
			assert(is_equal_approx(w, 0.0), "Root vertex must have wind weight 0.0")
		elif is_equal_approx(v.y, 1.0):
			assert(is_equal_approx(w, 1.0), "Tip vertex must have wind weight 1.0")

	# Comprobar normales estilizadas: deben apuntar principalmente hacia arriba (Y > 0.8)
	for n in normals_2:
		assert(n.y >= 0.85, "Stylized foliage normals must point upwards (Y >= 0.85), got: %f" % n.y)

	print(" -> [PASS] 2-quad crossed mesh geometry & wind weights verified")

	# 2. Crear malla de 3 quads cruzados (Star 60°)
	var mesh_3 = _FoliageMeshFactoryScript.create_crossed_quad_mesh(3, 1.2, 1.5)
	var arrays_3: Array = mesh_3.surface_get_arrays(0)
	var verts_3: PackedVector3Array = arrays_3[Mesh.ARRAY_VERTEX]
	var indices_3: PackedInt32Array = arrays_3[Mesh.ARRAY_INDEX]
	# 3 quads = 12 vértices, 18 índices (6 triángulos)
	assert(verts_3.size() == 12, "3 quads must have 12 vertices, got: %d" % verts_3.size())
	assert(indices_3.size() == 18, "3 quads must have 18 indices, got: %d" % indices_3.size())
	print(" -> [PASS] 3-quad star mesh geometry verified")

	# 3. Comprobar caché de mallas
	var cached_mesh = _FoliageMeshFactoryScript.get_or_create_mesh(2, 1.0, 1.0)
	var cached_mesh_2 = _FoliageMeshFactoryScript.get_or_create_mesh(2, 1.0, 1.0)
	assert(cached_mesh == cached_mesh_2, "get_or_create_mesh must return cached instance")
	print(" -> [PASS] Mesh caching verified")

	print("==================================================")
	print(" ALL FOLIAGE MESH TESTS PASSED!")
	print("==================================================")
	quit(0)
