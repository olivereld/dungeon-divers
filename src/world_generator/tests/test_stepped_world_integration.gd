extends SceneTree

func _init() -> void:
	print("==================================================")
	print(" Test de Integración: Pipeline de Terreno Escalonado")
	print("==================================================")

	var pipeline := WorldPipeline.new()
	var profile := TaigaWorldProfile.new()
	var seed_val: int = 12345

	# 1. Generación termina correctamente
	print("1. Ejecutando generación completa de mundo...")
	var result: WorldResult = pipeline.generate(seed_val, profile)
	assert(result != null, "WorldResult no debe ser nulo")
	var total_cells: int = profile.width * profile.height
	assert(result.cells.size() == total_cells, "Debe generar exactamente %d celdas" % total_cells)
	print("   -> [PASS] Generación completada con éxito (%d celdas)." % result.cells.size())

	# 2. Todas las celdas tienen elevation_level válido
	print("2. Validando rango de elevation_level en todas las celdas...")
	var min_lvl: int = profile.elevation_min_level
	var max_lvl: int = profile.elevation_max_level
	var step_h: float = profile.elevation_step_height
	var base_h: float = profile.base_height

	for pos in result.cells:
		var c: WorldCell = result.cells[pos]
		assert(c.elevation_level >= min_lvl and c.elevation_level <= max_lvl,
			"Nivel de elevación %d fuera de rango [%d, %d] en %s" % [c.elevation_level, min_lvl, max_lvl, str(pos)])
	print("   -> [PASS] Todas las celdas tienen elevation_level en [%d, %d]." % [min_lvl, max_lvl])

	# 3 y 4. height corresponde a base_height + level * step_height y es discreta (en celdas no talladas)
	print("3 y 4. Validando relación height vs elevation_level y discretización...")
	var hydro = result.hydrology
	var dry_plateau_checked: int = 0
	var water_or_bank_checked: int = 0
	for pos in result.cells:
		var c: WorldCell = result.cells[pos]
		var is_water: bool = hydro != null and hydro.has_method("is_water") and hydro.is_water(pos)
		var is_carved: bool = is_water or c.hydraulic_influence > 0.0
		var expected_stepped_h: float = base_h + float(c.elevation_level) * step_h

		if not is_carved:
			# Celda en meseta seca sin influencia fluvial: estrictamente discreta base_height + level * step_height
			assert(is_equal_approx(c.height, expected_stepped_h),
				"Cota en %s no coincide con escalón discreto: got %.2f, expected %.2f" % [str(pos), c.height, expected_stepped_h])
			var remainder := fposmod(c.height - base_h, step_h)
			assert(is_zero_approx(remainder) or is_equal_approx(remainder, step_h),
				"Cota física en meseta seca debe ser un múltiplo entero del escalón")
			dry_plateau_checked += 1
		else:
			# Celda en cauce o ribera tallada por hidrología
			water_or_bank_checked += 1

	print("   -> [PASS] %d celdas de meseta seca son múltiplos discretos exactos (%d en ribera/agua)." % [dry_plateau_checked, water_or_bank_checked])

	# 5. Determinismo estricto con la misma seed
	print("5. Validando determinismo estricto de elevation_level...")
	var result_repeat: WorldResult = pipeline.generate(seed_val, profile)
	for pos in result.cells:
		var c1: WorldCell = result.cells[pos]
		var c2: WorldCell = result_repeat.cells[pos]
		assert(c1.elevation_level == c2.elevation_level, "Discrepancia de nivel en %s" % str(pos))
		assert(is_equal_approx(c1.height, c2.height), "Discrepancia de altura en %s" % str(pos))
	print("   -> [PASS] 100%% de paridad determinista con misma semilla.")

	# 6. Hydrology sigue ejecutándose
	print("6. Comprobando ejecución de Hydrology...")
	assert(result.hydrology != null, "HydrologyResult debe existir")
	assert(result.hydrology.water_cells.size() > 0, "Debe contener celdas de agua generadas por Hydrology")
	print("   -> [PASS] Hydrology ejecutado correctamente (%d celdas de agua)." % result.hydrology.water_cells.size())

	# 7. Navigation sigue ejecutándose
	print("7. Comprobando ejecución de Navigation...")
	assert(result.metadata.has("walkable_ratio"), "Metadata de navegación debe incluir walkable_ratio")
	assert(result.spawn_position != Vector3.ZERO, "Spawn position debe estar calculado")
	var spawn_pos_2d := Vector2i(int(floor(result.spawn_position.x)), int(floor(result.spawn_position.z)))
	var spawn_cell := result.get_cell(spawn_pos_2d)
	assert(spawn_cell != null and spawn_cell.is_walkable, "Punto de spawn debe ser transitable")
	print("   -> [PASS] Navigation ejecutado correctamente (walkable_ratio: %.1f%%, spawn: %s)." % [
		result.metadata["walkable_ratio"] * 100.0, str(result.spawn_position)
	])

	# 8. TerrainMeshBuilder genera correctamente superficies + transiciones (malla estanca sin huecos)
	print("8. Validando generación de TerrainMeshBuilder (superficies + cliffs)...")
	var mesh := TerrainMeshBuilder.build_mesh(result, profile.cell_size, profile)
	assert(mesh != null and mesh.get_surface_count() > 0, "TerrainMesh debe generarse con al menos una superficie")
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	# Todas las celdas deben tener al menos su cara superior (4 vértices * total_cells) + paredes de cliff
	assert(verts.size() > total_cells * 4, "La malla debe contener caras TOP más paredes de acantilado")

	var top_count := 0
	var cliff_count := 0
	for n in normals:
		if n.y > 0.9:
			top_count += 1
		elif absf(n.y) < 0.1:
			cliff_count += 1

	assert(top_count == total_cells * 4, "Debe haber exactamente %d caras horizontales TOP" % [total_cells * 4])
	assert(cliff_count > 0, "Debe haber caras verticales generadas para cliffs")
	print("   -> [PASS] TerrainMeshBuilder generó %d vértices TOP y %d vértices CLIFF." % [top_count, cliff_count])

	print("==================================================")
	print(" INTEGRATION TEST SUCCESS: ALL 8 CONTRACTS PASSED!")
	print("==================================================")
	quit()
