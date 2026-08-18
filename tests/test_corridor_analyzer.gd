extends SceneTree

## Test unitario para Task 3: Extracción de Métricas de Corredores (Fase Reforced).
## Valida CorridorInfo y CorridorAnalyzer para analizar longitudes, anchuras y clasificación de pasillos cortos.

func _init() -> void:
	print("--- Running test_corridor_analyzer ---")
	var AnalyzerScript = preload("res://src/dungeon_generator/core/algorithms/corridor_analyzer.gd")
	var PathScript = preload("res://src/dungeon_generator/core/data/corridor_path.gd")

	# Caso 1: Pasillo corto (length=2)
	var cl_short: Array[Vector2i] = [Vector2i(5, 5), Vector2i(5, 6)]
	var path_short = PathScript.new(1, 0, 1, cl_short)
	var grid := CellGrid.new(20, 20)
	grid.set_cell(Vector2i(5, 5), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(5, 6), CellGrid.CellType.CORRIDOR)

	var info_short = AnalyzerScript.analyze_corridor(grid, path_short, [])
	assert(info_short != null, "CorridorInfo must not be null")
	assert(info_short.length == 2, "Length must be 2, got %d" % info_short.length)
	assert(info_short.is_short == true, "is_short must be true for length <= 3")
	assert(info_short.connection_id == 1, "connection_id must match path")
	print("  [OK] Short corridor analysis verified")

	# Caso 2: Pasillo largo (length=8)
	var long_cells: Array[Vector2i] = []
	for x in range(10, 18):
		long_cells.append(Vector2i(x, 10))
		grid.set_cell(Vector2i(x, 10), CellGrid.CellType.CORRIDOR)

	var path_long = PathScript.new(2, 0, 2, long_cells)
	var info_long = AnalyzerScript.analyze_corridor(grid, path_long, [])
	assert(info_long.length == 8, "Length must be 8, got %d" % info_long.length)
	assert(info_long.is_short == false, "is_short must be false for length > 3")
	assert(info_long.endpoints.size() == 2, "Must identify two endpoints")
	assert(info_long.endpoints[0] == Vector2i(10, 10), "Start endpoint must be (10, 10)")
	assert(info_long.endpoints[1] == Vector2i(17, 10), "End endpoint must be (17, 10)")
	print("  [OK] Long corridor analysis verified")

	print("[PASS] test_corridor_analyzer completed successfully!")
	quit(0)
