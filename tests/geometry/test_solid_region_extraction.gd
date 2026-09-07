extends SceneTree

const _SolidRegionExtractorScript = preload("res://src/geometry_generator/extraction/solid_region_extractor.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")
const _RoomEntranceScript = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

func _init() -> void:
	print("====================================================")
	print("   TEST: SOLID REGION EXTRACTION & FACE CULLING     ")
	print("====================================================")

	var extractor := _SolidRegionExtractorScript.new()

	# Caso 1: Región 1x1 WALL aislada rodeada de FLOOR
	# 3x3 grid: centro es WALL (1,1), resto FLOOR
	var grid1 := _CellGridScript.new(3, 3, _CellGridScript.CellType.FLOOR)
	grid1.set_cell(Vector2i(1, 1), _CellGridScript.CellType.WALL)

	var regions1 = extractor.extract_regions(grid1)
	assert(regions1.size() == 1, "Debe existir exactamente 1 región sólida")
	var r1 = regions1[0]
	assert(r1.get_cell_count() == 1, "La región debe tener 1 celda")
	assert(r1.exterior_faces.size() == 4, "Una celda aislada debe tener 4 caras exteriores")
	print("✔ Caso 1: Celda aislada 1x1 superado.")

	# Caso 2: Bloque contiguo 2x2 WALL
	# Las caras internas entre las 4 celdas deben ser descartadas (culling).
	# Cada celda tiene 2 caras exteriores y 2 caras interiores -> 4 * 2 = 8 caras exteriores en total.
	var grid2 := _CellGridScript.new(4, 4, _CellGridScript.CellType.FLOOR)
	grid2.set_cell(Vector2i(1, 1), _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(2, 1), _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(1, 2), _CellGridScript.CellType.WALL)
	grid2.set_cell(Vector2i(2, 2), _CellGridScript.CellType.WALL)

	var regions2 = extractor.extract_regions(grid2)
	assert(regions2.size() == 1, "Debe agrupar las 4 celdas contiguas en 1 sola región")
	var r2 = regions2[0]
	assert(r2.get_cell_count() == 4, "La región debe contener 4 celdas")
	assert(r2.exterior_faces.size() == 8, "Bloque 2x2 debe tener exactamente 8 caras exteriores (culling de caras internas)")
	print("✔ Caso 2: Bloque contiguo 2x2 con culling interno superado.")

	# Caso 3: Interfaz ROOM | WALL | CORRIDOR con Opening
	# (0, 0) = ROOM (owner 1), (1, 0) = WALL, (2, 0) = CORRIDOR
	var grid3 := _CellGridScript.new(3, 1, _CellGridScript.CellType.WALL)
	grid3.set_cell(Vector2i(0, 0), _CellGridScript.CellType.FLOOR)
	grid3.set_room_owner(Vector2i(0, 0), 1)
	grid3.set_cell(Vector2i(1, 0), _CellGridScript.CellType.WALL)
	grid3.set_cell(Vector2i(2, 0), _CellGridScript.CellType.CORRIDOR)

	var manifest := _WallOpeningManifestScript.new()
	# Registrar apertura entre el corredor (2, 0) hacia el oeste (lado WEST) hacia la pared
	manifest.add_opening(Vector2i(2, 0), _RoomEntranceScript.WEST, "conn_1")

	var regions3 = extractor.extract_regions(grid3, manifest)
	assert(regions3.size() == 1, "Debe haber 1 región WALL")
	var r3 = regions3[0]
	assert(r3.get_cell_count() == 1, "La región WALL tiene 1 celda")
	
	# Verificar que la cara este (hacia el corredor) tenga is_opening = true
	var found_east_opening := false
	for f in r3.exterior_faces:
		if f["side"] == _RoomEntranceScript.EAST:
			assert(f["neighbor"] == Vector2i(2, 0), "Vecino Este debe ser el corredor")
			if f["is_opening"]:
				found_east_opening = true
	assert(found_east_opening, "La cara hacia el corredor con apertura debe ser marcada como is_opening")
	print("✔ Caso 3: Interfaz ROOM | WALL | CORRIDOR con opening superado.")

	print("\nTODOS LOS TESTS DE SOLID REGION EXTRACTION PASARON EXITOSAMENTE.")
	quit(0)
