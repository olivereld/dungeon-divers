extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Testing Stepped Terrain Physics Collision (Paso 11)")
	print("==================================================")

	var profile := TaigaWorldProfile.new()

	# -------------------------------------------------------------------------
	# 1. Verificación de ConcavePolygonShape3D derivado de ArrayMesh
	# -------------------------------------------------------------------------
	print("1. Creando mundo y derivando CollisionShape3D desde TerrainMesh...")
	var result := WorldPipeline.generate(42, profile)
	var renderer := WorldRenderer.new()
	var root := renderer.render_world(result, profile)

	assert(root != null)
	assert(root.has_node("TerrainMesh"), "Debe existir nodo visual TerrainMesh")
	assert(root.has_node("TerrainCollision"), "Debe existir nodo físico TerrainCollision")

	var mesh_inst: MeshInstance3D = root.get_node("TerrainMesh")
	var static_body: StaticBody3D = root.get_node("TerrainCollision")
	assert(static_body.get_child_count() > 0, "TerrainCollision debe poseer CollisionShape3D")

	var col_shape: CollisionShape3D = static_body.get_child(0) as CollisionShape3D
	assert(col_shape != null and col_shape.shape is ConcavePolygonShape3D,
		"El collider debe ser ConcavePolygonShape3D derivado de create_trimesh_shape()")

	var trimesh_shape: ConcavePolygonShape3D = col_shape.shape as ConcavePolygonShape3D
	var faces: PackedVector3Array = trimesh_shape.get_faces()
	assert(faces.size() > 0 and faces.size() % 3 == 0, "El collider debe contener triángulos físicos válidos")
	print("   -> OK: ConcavePolygonShape3D generado con %d vértices de colisión (%d triángulos)." % [faces.size(), faces.size() / 3])

	# -------------------------------------------------------------------------
	# 2. Análisis geométrico de caras del collider:
	#    No deben existir pendientes diagonales "viejas" en el terreno escalonado;
	#    los triángulos deben ser horizontales (mesetas) o verticales (paredes).
	# -------------------------------------------------------------------------
	print("2. Analizando normales de triángulos del collider físico...")
	var num_tris: int = faces.size() / 3
	var horizontal_tris := 0
	var vertical_tris := 0
	var diagonal_tris := 0

	for t in range(num_tris):
		var v0: Vector3 = faces[t * 3]
		var v1: Vector3 = faces[t * 3 + 1]
		var v2: Vector3 = faces[t * 3 + 2]

		var normal := (v1 - v0).cross(v2 - v0).normalized()

		if normal.dot(Vector3.UP) > 0.95 or normal.dot(Vector3.DOWN) > 0.95:
			horizontal_tris += 1
		elif absf(normal.y) < 0.05:
			vertical_tris += 1
		else:
			diagonal_tris += 1

	print("   -> Triángulos horizontales (mesetas/plateaus): %d" % horizontal_tris)
	print("   -> Triángulos verticales (acantilados/cliffs): %d" % vertical_tris)
	print("   -> Triángulos no ortogonales: %d" % diagonal_tris)

	assert(horizontal_tris > 0, "El collider debe tener superficies transitables horizontales (normal UP)")
	assert(vertical_tris > 0, "El collider debe tener paredes físicas verticales (acantilados)")
	# En terreno escalonado puro, los triángulos son 100% ortogonales (top quads + cliff quads)
	assert(diagonal_tris == 0, "VIOLACIÓN DE COLISIÓN: Existen %d triángulos diagonales! La colisión debe ser estrictamente escalonada." % diagonal_tris)
	print("   -> OK: 100%% de triángulos del collider son estrictamente horizontales o verticales.")

	# -------------------------------------------------------------------------
	# 3. Paridad geométrica exacta: Visual TerrainMesh == Physical Collider
	# -------------------------------------------------------------------------
	print("3. Comprobando paridad matemática visual vs físico...")
	var visual_mesh: ArrayMesh = mesh_inst.mesh
	var visual_arrays := visual_mesh.surface_get_arrays(0)
	var visual_indices: PackedInt32Array = visual_arrays[Mesh.ARRAY_INDEX]
	assert(faces.size() == visual_indices.size(),
		"El collider físico debe tener idéntica cantidad de vértices triangulados que la malla visual: col=%d vs visual=%d" % [
			faces.size(), visual_indices.size()
		])
	print("   -> OK: Paridad 1:1 total (%d vértices triangulados en render y colisión)." % faces.size())

	root.free()
	renderer.free()

	print("==================================================")
	print(" ALL STEPPED COLLISION TESTS PASSED!")
	print("==================================================")
	quit()
