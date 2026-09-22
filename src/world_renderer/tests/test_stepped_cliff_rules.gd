extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Testing Stepped Cliff Generation Rules (Paso 8)")
	print("==================================================")

	var profile := TaigaWorldProfile.new()

	# -------------------------------------------------------------------------
	# 1. Delta == 0 y Misma Elevación: No se genera pared en mesetas planas
	# -------------------------------------------------------------------------
	print("1. Validando que celdas a la misma altura no generan pared vertical...")
	var res_flat := WorldResult.new()
	res_flat.dimensions = Vector2i(2, 1)
	var c0 := WorldCell.new(Vector2i(0, 0))
	c0.elevation_level = 2
	c0.height = 6.0
	c0.raw_height = 6.05
	res_flat.cells[Vector2i(0, 0)] = c0

	var c1 := WorldCell.new(Vector2i(1, 0))
	c1.elevation_level = 2
	c1.height = 6.0
	c1.raw_height = 6.02
	res_flat.cells[Vector2i(1, 0)] = c1

	var mesh_flat: ArrayMesh = TerrainMeshBuilder.build_mesh(res_flat, 1.0, profile)
	var arrays_flat := mesh_flat.surface_get_arrays(0)
	var verts_flat: PackedVector3Array = arrays_flat[Mesh.ARRAY_VERTEX]
	# 2 celdas * 4 vértices (solo caras TOP) = 8 vértices
	assert(verts_flat.size() == 8, "En meseta plana solo deben existir las caras TOP (8 verts), pero hay %d" % verts_flat.size())
	print("   -> OK: Vértices exactos = 8 (0 paredes de acantilado en terreno plano).")

	# 1b. Desnivel por tallado / hidrología genera pared estanca (evita huecos al vacío)
	print("1b. Validando que desniveles locales generan pared para mantener malla estanca...")
	var res_carved := WorldResult.new()
	res_carved.dimensions = Vector2i(2, 1)
	var c_bank := WorldCell.new(Vector2i(0, 0))
	c_bank.elevation_level = 2
	c_bank.height = 6.0
	res_carved.cells[Vector2i(0, 0)] = c_bank

	var c_bed := WorldCell.new(Vector2i(1, 0))
	c_bed.elevation_level = 2
	c_bed.height = 5.8  # Tallado de lecho fluvial
	res_carved.cells[Vector2i(1, 0)] = c_bed

	var mesh_carved: ArrayMesh = TerrainMeshBuilder.build_mesh(res_carved, 1.0, profile)
	var arrays_carved := mesh_carved.surface_get_arrays(0)
	var verts_carved: PackedVector3Array = arrays_carved[Mesh.ARRAY_VERTEX]
	assert(verts_carved.size() == 12, "Debe generar 8 verts TOP + 4 verts de pared estanca = 12, pero hay %d" % verts_carved.size())
	print("   -> OK: Vértices exactos = 12 (pared estanca generada para evitar grietas negras).")

	# -------------------------------------------------------------------------
	# 2. Delta != 0: Diferencia de múltiples niveles (Level 5 vs Level 2)
	#    Pared única de min(height_a, height_b) a max(height_a, height_b)
	# -------------------------------------------------------------------------
	print("2. Validando salto multinivel (Level 5 -> Level 2, delta = -3)...")
	var res_multi := WorldResult.new()
	res_multi.dimensions = Vector2i(2, 1)
	var c_low := WorldCell.new(Vector2i(0, 0))
	c_low.elevation_level = 2
	c_low.height = 6.0
	res_multi.cells[Vector2i(0, 0)] = c_low

	var c_high := WorldCell.new(Vector2i(1, 0))
	c_high.elevation_level = 5
	c_high.height = 12.0
	res_multi.cells[Vector2i(1, 0)] = c_high

	var mesh_multi: ArrayMesh = TerrainMeshBuilder.build_mesh(res_multi, 1.0, profile)
	var arrays_multi := mesh_multi.surface_get_arrays(0)
	var verts_multi: PackedVector3Array = arrays_multi[Mesh.ARRAY_VERTEX]
	var normals_multi: PackedVector3Array = arrays_multi[Mesh.ARRAY_NORMAL]
	var colors_multi: PackedColorArray = arrays_multi[Mesh.ARRAY_COLOR]

	# 2 celdas TOP (8 verts) + 1 pared vertical (4 verts) = 12 vértices
	assert(verts_multi.size() == 12, "Debe generar exactamente 8 verts TOP + 4 verts CLIFF = 12, pero hay %d" % verts_multi.size())

	# Verificar vértices de la pared vertical (índices 8..11)
	var cliff_min_y := INF
	var cliff_max_y := -INF
	var cliff_normal := Vector3.ZERO
	for i in range(8, 12):
		cliff_min_y = minf(cliff_min_y, verts_multi[i].y)
		cliff_max_y = maxf(cliff_max_y, verts_multi[i].y)
		cliff_normal = normals_multi[i]
		var exp_rock: Color = profile.terrain_rock_color
		assert(is_equal_approx(colors_multi[i].r, exp_rock.r) and is_equal_approx(colors_multi[i].g, exp_rock.g) and is_equal_approx(colors_multi[i].b, exp_rock.b), "La pared del cliff debe tener color de roca")

	assert(is_equal_approx(cliff_min_y, 6.0), "La base del cliff debe cubrir min(height_a, height_b) = 6.0m, obtuve %.2f" % cliff_min_y)
	assert(is_equal_approx(cliff_max_y, 12.0), "La cima del cliff debe cubrir max(height_a, height_b) = 12.0m, obtuve %.2f" % cliff_max_y)
	assert(cliff_normal.dot(Vector3.LEFT) > 0.95, "La normal del cliff debe orientarse hacia el vecino inferior (-X / LEFT)")
	print("   -> OK: Cliff vertical único cubre de %.1fm a %.1fm con normal %s." % [cliff_min_y, cliff_max_y, str(cliff_normal)])

	# -------------------------------------------------------------------------
	# 3. Meseta aislada rodeada de 4 vecinos inferiores (4 acantilados)
	# -------------------------------------------------------------------------
	print("3. Validando meseta rodeada de 4 vecinos inferiores (3x3 grid)...")
	var res_3x3 := WorldResult.new()
	res_3x3.dimensions = Vector2i(3, 3)
	for y in range(3):
		for x in range(3):
			var cell := WorldCell.new(Vector2i(x, y))
			if x == 1 and y == 1:
				cell.elevation_level = 4
				cell.height = 10.0
			else:
				cell.elevation_level = 1
				cell.height = 4.0
			res_3x3.cells[Vector2i(x, y)] = cell

	var mesh_3x3: ArrayMesh = TerrainMeshBuilder.build_mesh(res_3x3, 1.0, profile)
	var arrays_3x3 := mesh_3x3.surface_get_arrays(0)
	var verts_3x3: PackedVector3Array = arrays_3x3[Mesh.ARRAY_VERTEX]
	var normals_3x3: PackedVector3Array = arrays_3x3[Mesh.ARRAY_NORMAL]

	# 9 celdas TOP (36 verts) + 4 paredes verticales (16 verts) = 52 vértices
	assert(verts_3x3.size() == 52, "Debe haber 36 verts TOP + 16 verts CLIFF = 52, pero hay %d" % verts_3x3.size())

	var has_left := false
	var has_right := false
	var has_forward := false
	var has_back := false
	for n in normals_3x3:
		if n.dot(Vector3.LEFT) > 0.95: has_left = true
		if n.dot(Vector3.RIGHT) > 0.95: has_right = true
		if n.dot(Vector3.FORWARD) > 0.95: has_forward = true
		if n.dot(Vector3.BACK) > 0.95: has_back = true

	assert(has_left and has_right and has_forward and has_back, "Deben generarse las 4 paredes cardinales para la meseta central")
	print("   -> OK: 4 paredes cardinales generadas exitosamente.")

	# -------------------------------------------------------------------------
	# 4. Anti-Duplicación Estricta (Paso 9): Tira alternada de N celdas
	#    Garantiza que una frontera A | B jamás genere wall(A) + wall(B)
	# -------------------------------------------------------------------------
	print("4. Validando regla anti-duplicación (10 celdas alternadas, 9 fronteras)...")
	var res_strip := WorldResult.new()
	res_strip.dimensions = Vector2i(10, 1)
	for x in range(10):
		var cell := WorldCell.new(Vector2i(x, 0))
		cell.elevation_level = 3 if (x % 2 == 0) else 1
		cell.height = 8.0 if (x % 2 == 0) else 4.0
		res_strip.cells[Vector2i(x, 0)] = cell

	var mesh_strip: ArrayMesh = TerrainMeshBuilder.build_mesh(res_strip, 1.0, profile)
	var arrays_strip := mesh_strip.surface_get_arrays(0)
	var verts_strip: PackedVector3Array = arrays_strip[Mesh.ARRAY_VERTEX]

	# 10 celdas TOP (40 verts) + 9 fronteras * 1 pared cada una (36 verts) = 76 vértices
	# Si hubiera duplicación wall(A) + wall(B), tendríamos 10*4 + 9*8 = 112 vértices
	assert(verts_strip.size() == 76, "Debe haber exactamente 1 pared por frontera (76 verts), pero hay %d" % verts_strip.size())
	print("   -> OK: Exactamente 76 vértices (9 paredes generadas para 9 fronteras, 0 duplicadas).")

	print("==================================================")
	print(" ALL STEPPED CLIFF RULE TESTS PASSED!")
	print("==================================================")
	quit()
