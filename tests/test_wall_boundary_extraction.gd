extends SceneTree

## Test suite para validar Extracción Topológica Formal (Fase M1).
## Valida casos ortogonales: salas aisladas, múltiples componentes conexas, huecos y vanos.

const CellGrid = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
const WallOpeningManifest = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")
const RoomEntrance = preload("res://src/dungeon_generator/core/data/room_entrance.gd")
const BoundaryExtractor = preload("res://src/geometry_generator/extraction/boundary_extractor.gd")
const ComponentExtractor = preload("res://src/geometry_generator/extraction/component_extractor.gd")
const WallBoundaryGraph = preload("res://src/geometry_generator/data/wall_boundary_graph.gd")
const WallComponent = preload("res://src/geometry_generator/data/wall_component.gd")

func _init() -> void:
	print("==================================================================")
	print("--- Running test_wall_boundary_extraction (Fase M1: Topology) ---")
	print("==================================================================")

	var extractor := BoundaryExtractor.new()
	var comp_extractor := ComponentExtractor.new()

	# Caso 1: Sala rectangular simple de 3x3 (celdas transitables de (2,2) a (4,4))
	var grid1 := CellGrid.new(10, 10)
	for y in range(2, 5):
		for x in range(2, 5):
			grid1.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var graph1 = extractor.extract_graph(grid1)
	assert(graph1 != null, "Graph 1 must not be null")
	assert(graph1.get_edge_count() == 12, "A 3x3 room has 3 edges per side * 4 sides = 12 edges, got %d" % graph1.get_edge_count())

	var comps1: Array = comp_extractor.extract_components(graph1)
	assert(comps1.size() == 1, "Expected exactly 1 component for a single room, got %d" % comps1.size())
	assert(comps1[0].loops.size() == 1, "Expected 1 closed loop, got %d" % comps1[0].loops.size())
	assert(comps1[0].loops[0].size() == 4, "Simplified loop for rectangle must have 4 corners, got %d" % comps1[0].loops[0].size())
	print("  [OK] Caso 1: Sala rectangular 3x3 validada (1 componente, 4 esquinas).")

	# Caso 2: Dos salas desconectadas (dos clusters independientes)
	var grid2 := CellGrid.new(20, 20)
	# Sala A: (2,2) a (4,4)
	for y in range(2, 5):
		for x in range(2, 5):
			grid2.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)
	# Sala B: (10,10) a (12,12)
	for y in range(10, 13):
		for x in range(10, 13):
			grid2.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var graph2 = extractor.extract_graph(grid2)
	assert(graph2.get_edge_count() == 24, "Expected 24 edges for two 3x3 rooms, got %d" % graph2.get_edge_count())

	var comps2: Array = comp_extractor.extract_components(graph2)
	assert(comps2.size() == 2, "Expected 2 independent components, got %d" % comps2.size())
	assert(comps2[0].loops.size() == 1 and comps2[1].loops.size() == 1, "Each component should have 1 loop")
	print("  [OK] Caso 2: Dos salas desconectadas validadas (2 clusters independientes).")

	# Caso 3: Sala en L (6 esquinas)
	var grid3 := CellGrid.new(10, 10)
	# Rama horizontal: (2,2) a (5,3)
	for y in range(2, 4):
		for x in range(2, 6):
			grid3.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)
	# Rama vertical: (2,4) a (3,6)
	for y in range(4, 7):
		for x in range(2, 4):
			grid3.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var graph3 = extractor.extract_graph(grid3)
	var comps3: Array = comp_extractor.extract_components(graph3)
	assert(comps3.size() == 1, "Expected 1 component for L-shaped room, got %d" % comps3.size())
	assert(comps3[0].loops.size() == 1, "Expected 1 loop")
	assert(comps3[0].loops[0].size() == 6, "L-shaped room simplified loop must have 6 corners, got %d" % comps3[0].loops[0].size())
	print("  [OK] Caso 3: Sala en forma de L validada (6 esquinas ortogonales).")

	# Caso 4: Vano de apertura con WallOpeningManifest
	var grid4 := CellGrid.new(10, 10)
	for y in range(2, 5):
		for x in range(2, 5):
			grid4.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	var opening_manifest := WallOpeningManifest.new()
	# Añadir apertura en el borde norte de (3,2)
	opening_manifest.register_opening(Vector2i(3, 2), RoomEntrance.NORTH, 1.0, 2.0, 1)

	var graph4 = extractor.extract_graph(grid4, opening_manifest)
	# Normalmente 12 aristas - 1 arista omitida por apertura = 11 aristas
	assert(graph4.get_edge_count() == 11, "Expected 11 edges when 1 edge is carved out for doorway, got %d" % graph4.get_edge_count())
	print("  [OK] Caso 4: Apertura de puerta omitida correctamente del grafo de aristas.")

	print("==================================================================")
	print("[PASS] test_wall_boundary_extraction completado exitosamente!")
	print("==================================================================")
	quit(0)
