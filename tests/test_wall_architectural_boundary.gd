extends SceneTree

const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const _BoundaryExtractorScript = preload("res://src/geometry_generator/extraction/boundary_extractor.gd")
const _WallOpeningManifestScript = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_architectural_boundary (Contractual Test) ---")
	print("==================================================================")

	var extractor := _BoundaryExtractorScript.new()
	var grid := _CellGridScript.new(10, 10)

	# Inicializar todo a WALL
	for y in range(10):
		for x in range(10):
			grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.WALL)

	# 1. Configurar habitación en (2, 2) a (4, 4)
	for y in range(2, 5):
		for x in range(2, 5):
			grid.set_cell(Vector2i(x, y), _CellGridScript.CellType.FLOOR)
			grid.set_room_owner(Vector2i(x, y), 0)

	# 2. Configurar pasillo continuo en (5, 3) a (7, 3) (al este de la habitación)
	for x in range(5, 8):
		grid.set_cell(Vector2i(x, 3), _CellGridScript.CellType.CORRIDOR)

	# CONTRATO 1: ROOM <-> CORRIDOR produce frontera arquitectónica
	var cell_room := Vector2i(4, 3)
	var cell_corr := Vector2i(5, 3)
	var is_b_room_side = extractor._is_boundary(grid, cell_room, cell_corr, 1, null) # EAST
	assert(is_b_room_side == true, "ROOM -> CORRIDOR boundary must produce boundary edge")

	# CONTRATO 2: Regla de no duplicación (CORRIDOR -> ROOM no debe emitir arista opuesta)
	var is_b_corr_side = extractor._is_boundary(grid, cell_corr, cell_room, 3, null) # WEST
	assert(is_b_corr_side == false, "CORRIDOR -> ROOM must NOT duplicate the boundary edge")

	# CONTRATO 3: WALKABLE <-> WALKABLE dentro de la misma sala o pasillo NO produce frontera
	var cell_room_inner := Vector2i(3, 3)
	assert(extractor._is_boundary(grid, cell_room, cell_room_inner, 3, null) == false, "ROOM -> ROOM inside same room must NOT produce boundary")
	var cell_corr_2 := Vector2i(6, 3)
	assert(extractor._is_boundary(grid, cell_corr, cell_corr_2, 1, null) == false, "CORRIDOR -> CORRIDOR inside same corridor must NOT produce boundary")

	# CONTRATO 4: Aperturas en manifest se respetan y omiten la arista
	var manifest := _WallOpeningManifestScript.new()
	manifest.add_opening(cell_room, 1, "room_corr_door")
	assert(extractor._is_boundary(grid, cell_room, cell_corr, 1, manifest) == false, "Opening in manifest must suppress boundary wall")

	print("  [OK] Contrato 1: ROOM ↔ CORRIDOR genera frontera topológica.")
	print("  [OK] Contrato 2: Sin duplicación de aristas entre salón y pasillo.")
	print("  [OK] Contrato 3: Celdas transitables del mismo espacio no generan frontera interna.")
	print("  [OK] Contrato 4: Manifest de aperturas suprime la pared correctamente.")
	print("==================================================================")
	print("[PASS] test_wall_architectural_boundary completado exitosamente!")
	print("==================================================================")
	quit(0)
