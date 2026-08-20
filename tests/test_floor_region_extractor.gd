extends SceneTree

## Test suite para validar FloorRegionExtractor en src/floor_tile_generator/extraction.

const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const FloorRegionExtractor = preload("res://src/floor_tile_generator/extraction/floor_region_extractor.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_floor_region_extractor (Floor Connected Regions) ---")
	print("==================================================================")

	var extractor := FloorRegionExtractor.new()

	# 1. Grid nulo o completamente sólido
	var null_res = extractor.extract_regions(null)
	assert(null_res.is_empty(), "Null grid must return empty regions")

	var solid_grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	var solid_res = extractor.extract_regions(solid_grid)
	assert(solid_res.is_empty(), "Completely solid grid must return 0 regions")
	print("  [OK] Empty/solid grid edge cases handled.")

	# 2. Sala rectangular única 4x3
	var single_room_grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	for y in range(2, 5):
		for x in range(2, 6):
			single_room_grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var single_res = extractor.extract_regions(single_room_grid)
	assert(single_res.size() == 1, "Single room must extract exactly 1 region")
	assert(single_res[0].size() == 12, "4x3 room must contain 12 walkable cells")
	print("  [OK] Single rectangular room extracted: 1 region with 12 cells.")

	# 3. Dos salas aisladas desconectadas
	var multi_room_grid := CellGrid.new(20, 10, CellGrid.CellType.WALL)
	# Sala 1: (2,2) a (4,4) -> 3x3 = 9 celdas
	for y in range(2, 5):
		for x in range(2, 5):
			multi_room_grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	# Sala 2: (12,2) a (15,5) -> 4x4 = 16 celdas
	for y in range(2, 6):
		for x in range(12, 16):
			multi_room_grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var multi_res = extractor.extract_regions(multi_room_grid)
	assert(multi_res.size() == 2, "Must extract 2 disconnected regions")
	var cell_counts = [multi_res[0].size(), multi_res[1].size()]
	assert(cell_counts.has(9) and cell_counts.has(16), "Region cell counts must be 9 and 16")
	print("  [OK] Multiple disconnected rooms extracted: 2 regions (9 and 16 cells).")

	# 4. Sala en forma de L
	var l_grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	# Brazo vertical: x=2, y=2..6 (5 celdas)
	for y in range(2, 7):
		l_grid.set_cell(Vector2i(2, y), CellGrid.CellType.FLOOR)
	# Brazo horizontal: y=6, x=3..6 (4 celdas)
	for x in range(3, 7):
		l_grid.set_cell(Vector2i(x, 6), CellGrid.CellType.FLOOR)

	var l_res = extractor.extract_regions(l_grid)
	assert(l_res.size() == 1, "L-shaped room must extract as 1 single continuous region")
	assert(l_res[0].size() == 9, "L-shaped room must contain 9 cells")
	print("  [OK] L-shaped room extracted: 1 region with 9 cells.")

	# 5. Dos salas conectadas por un corredor
	for x in range(5, 12):
		multi_room_grid.set_cell(Vector2i(x, 3), CellGrid.CellType.CORRIDOR)
	var connected_res = extractor.extract_regions(multi_room_grid)
	assert(connected_res.size() == 1, "Connected rooms via corridor must merge into 1 single region")
	assert(connected_res[0].size() == 9 + 16 + 7, "Total cells must include rooms + corridor")
	print("  [OK] Rooms joined by corridor merged into 1 continuous region.")

	print("==================================================================")
	print("[PASS] test_floor_region_extractor completado con 100% éxito!")
	print("==================================================================")
	quit(0)
