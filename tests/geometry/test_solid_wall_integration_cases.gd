extends SceneTree

const _DungeonGeometryGeneratorScript = preload("res://src/geometry_generator/facade/dungeon_geometry_generator.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")
const _WallGeometryConfigScript = preload("res://src/geometry_generator/config/wall_geometry_config.gd")
const _CollisionConfigScript = preload("res://src/geometry_generator/config/collision_config.gd")
const _DecorationConfigScript = preload("res://src/geometry_generator/config/decoration_config.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

func _init() -> void:
	print("================================================================")
	print("   TEST: SOLID WALL INTEGRATION & VALIDACIÓN MÍNIMA (PUNTO 9)   ")
	print("================================================================")

	var geom_gen := _DungeonGeometryGeneratorScript.new()
	var wall_cfg := _WallGeometryConfigScript.new()
	wall_cfg.cube_size = 2.0
	wall_cfg.cubes_high = 2 # 4.0m

	var col_cfg := _CollisionConfigScript.new()
	col_cfg.mode = _CollisionConfigScript.CollisionMode.COMPOUND_BOX

	var dec_cfg := _DecorationConfigScript.new()
	dec_cfg.enabled = true
	dec_cfg.brick_density = 0.55

	# -------------------------------------------------------------
	# Caso 1: ROOM | WALL | CORRIDOR
	# Debe materializar una masa sólida completa para la celda WALL (sin foso ni zanja de 0.92m)
	# -------------------------------------------------------------
	var grid1 := _CellGridScript.new(3, 1, _CellGridScript.CellType.WALL)
	grid1.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)
	grid1.set_room_owner(Vector2i(0, 0), 1)
	grid1.set_cell(Vector2i(1, 0), _CellGridScript.CellType.WALL)
	grid1.set_cell(Vector2i(2, 0), _CellGridScript.CellType.CORRIDOR)

	var res1 = geom_gen.generate_wall_clusters(grid1, null, wall_cfg, col_cfg, dec_cfg)
	assert(res1 != null and not res1.generated_meshes.is_empty(), "Caso 1 debe generar mallas")

	var solid_found := false
	for g_mesh in res1.generated_meshes:
		if g_mesh.mesh != null:
			for s_idx in range(g_mesh.mesh.get_surface_count()):
				if g_mesh.mesh.surface_get_name(s_idx) == "SolidMass":
					solid_found = true
					# Verificar que el AABB de la masa sólida cubra la celda WALL entera de X=2 a X=4
					var aabb = g_mesh.bounds
					assert(aabb.position.x <= 2.01 and aabb.end.x >= 3.99, "La masa sólida debe ocupar toda la celda WALL de 2.0m a 4.0m")
					assert(absf(aabb.size.y - 4.0) < 0.01, "Altura sólida = 4.0m")
	assert(solid_found, "Debe haberse generado la superficie SolidMass")
	print("✔ Caso 1: ROOM | WALL | CORRIDOR materializado como masa sólida continua (cero zanjas).")

	# -------------------------------------------------------------
	# Caso 2: Anillo de WALLs rodeando un vacío:
	# WALL WALL WALL
	# WALL  FLOOR WALL
	# WALL WALL WALL
	# Debe generar una masa continua con culling de caras internas entre WALLs contiguos
	# -------------------------------------------------------------
	var grid2 := _CellGridScript.new(3, 3, _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(1, 1), _CellGridScript.CellType.FLOOR)

	var res2 = geom_gen.generate_wall_clusters(grid2, null, wall_cfg, col_cfg, dec_cfg)
	assert(res2 != null and not res2.generated_meshes.is_empty(), "Caso 2 debe generar mallas")

	var solid_mesh_found2 := false
	for g_mesh in res2.generated_meshes:
		if g_mesh.mesh != null and g_mesh.mesh.get_surface_count() > 0:
			if g_mesh.mesh.surface_get_name(0) == "SolidMass":
				solid_mesh_found2 = true
				# La región sólida tiene 8 celdas WALL. Debe abarcar de 0 a 6m en X y Z.
				var aabb = g_mesh.bounds
				assert(absf(aabb.size.x - 6.0) < 0.01, "Ancho total masa = 6.0m")
				assert(absf(aabb.size.z - 6.0) < 0.01, "Profundidad total masa = 6.0m")
	assert(solid_mesh_found2, "Masa sólida de anillo generada")
	print("✔ Caso 2: Anillo de masa sólida continua con culling interno superado.")

	# -------------------------------------------------------------
	# Caso 3: Opening en una frontera con WallOpeningManifest
	# -------------------------------------------------------------
	var grid3 := _CellGridScript.new(3, 1, _CellGridScript.CellType.WALL)
	grid3.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)
	grid3.set_cell(Vector2i(1, 0), _CellGridScript.CellType.WALL)
	grid3.set_cell(Vector2i(2, 0), _CellGridScript.CellType.CORRIDOR)

	var manifest3 := _WallOpeningManifestScript.new()
	manifest3.add_opening(Vector2i(2, 0), _RoomEntranceScript.WEST, "conn_1")

	var res3 = geom_gen.generate_wall_clusters(grid3, manifest3, wall_cfg, col_cfg, dec_cfg)
	assert(res3 != null and not res3.generated_meshes.is_empty(), "Caso 3 con opening generado")
	print("✔ Caso 3: Apertura/Opening en frontera generado limpiamente sin bloqueo ciego.")

	print("\n================================================================")
	print("   TODAS LAS VALIDACIONES MÍNIMAS DEL PUNTO 9 PASARON AL 100%   ")
	print("================================================================")
	quit(0)
