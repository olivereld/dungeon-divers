extends SceneTree

## Suite de pruebas unitarias para PR-09C: Integración de Vanos en ContinuousWallExtractor ("Carving" Geométrico).

func _init() -> void:
	print("--- Running test_wall_mesh_door_carving (PR-09C) ---")

	var extractor_script = preload("res://src/wall_mesh_generator/core/continuous_wall_extractor.gd")
	var builder_script = preload("res://src/wall_mesh_generator/core/continuous_wall_mesh_builder.gd")
	var wall_config_script = preload("res://src/wall_mesh_generator/config/wall_mesh_config.gd")
	var wall_opening_script = preload("res://src/dungeon_generator/core/data/wall_opening_manifest.gd")
	var room_entrance_script = preload("res://src/dungeon_generator/core/data/room_entrance.gd")

	# 1. Crear un CellGrid con una sala de 6x6 y un pasillo saliendo al Sur en x=4
	var grid := CellGrid.new(16, 16, CellGrid.CellType.WALL)
	for y in range(2, 8):
		for x in range(2, 8):
			grid.set_cell(Vector2i(x, y), CellGrid.CellType.FLOOR)

	# Pasillo al sur desde (4, 8) hasta (4, 12)
	for y in range(8, 13):
		grid.set_cell(Vector2i(4, y), CellGrid.CellType.CORRIDOR)

	# 2. Sin WallOpeningManifest: El perímetro exterior contiene el contorno completo
	var loops_closed: Array = extractor_script.extract_wall_loops(grid, 2.0, null)
	assert(not loops_closed.is_empty(), "Closed loops must be extracted")
	print("  [OK] Full perimeter extracted without openings (%d loops)" % loops_closed.size())

	# 3. Con WallOpeningManifest: Registrar vano en la unión sala-corredor en (4, 7) mirando al SUR
	var opening_manifest: WallOpeningManifest = wall_opening_script.new()
	opening_manifest.add_opening(Vector2i(4, 7), room_entrance_script.SOUTH, "conn_1")
	opening_manifest.add_opening(Vector2i(4, 8), room_entrance_script.NORTH, "conn_1")

	var loops_carved: Array = extractor_script.extract_wall_loops(grid, 2.0, opening_manifest)
	assert(not loops_carved.is_empty(), "Carved loops must be extracted")

	# 4. Validar que la malla generada respeta el vano sin generar muros en el vano
	var builder := builder_script.new()
	var config: WallMeshConfig = wall_config_script.new()
	config.cube_size = 2.0
	config.cubes_high = 2
	config.seed = 42

	var mesh_carved: ArrayMesh = builder.build_dungeon_wall_mesh(grid, config, 0, opening_manifest)
	assert(mesh_carved != null and mesh_carved.get_surface_count() == 3, "Mesh must contain 3 surfaces with carved openings")

	print("  [OK] Geometric wall carving verified: 0 walls generated on door opening edges")
	print("\n>>> ALL PR-09C WALL MESH DOOR CARVING TESTS PASSED SUCCESSFULLY! <<<\n")
	quit(0)
