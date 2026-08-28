extends SceneTree

## Test de validación: Exclusión de losas de suelo en fosos de escalera descendente (STAIRS_DOWN).

func _init() -> void:
	print("--- Running test_stair_down_aperture_exclusion ---")

	var cell_grid_script = preload("res://src/dungeon_generator/core/data/cell_grid.gd")
	var room_data_script = preload("res://src/dungeon_generator/core/data/room_data.gd")
	var semantic_result_script = preload("res://src/dungeon_generator/core/semantic/data/dungeon_semantic_result.gd")
	var presentation_partition_script = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
	var context_builder_script = preload("res://src/presentation/architecture/presentation_context_builder.gd")
	var floor_gen_script = preload("res://src/floor_tile_generator/facade/dungeon_floor_generator.gd")

	# 1. Crear un CellGrid con una habitación 6x6 y una escalera descendente en (3, 3)
	var grid: CellGrid = cell_grid_script.new(10, 10)
	grid.clear(cell_grid_script.CellType.VOID)

	for y in range(1, 7):
		for x in range(1, 7):
			grid.set_cell(Vector2i(x, y), cell_grid_script.CellType.FLOOR)

	var stair_down_cell := Vector2i(3, 3)
	grid.set_cell(stair_down_cell, cell_grid_script.CellType.STAIRS_DOWN)

	var room = room_data_script.new(0, Rect2i(1, 1, 6, 6))
	var semantic = semantic_result_script.new()
	semantic.grid = grid
	semantic.rooms = [room]

	# 2. Construir Partición de Geometría
	var ctx_builder = context_builder_script.new()
	var room_contexts = ctx_builder.build_contexts(semantic)

	var partition = presentation_partition_script.new()
	partition.build_partition(grid, room_contexts, semantic)

	var r_geom = partition.get_room_geometry(0)
	assert(r_geom != null, "Room 0 geometry must exist")

	# Validar que la celda STAIRS_DOWN NO está en floor_cells
	assert(not r_geom.floor_cells.has(stair_down_cell), "r_geom.floor_cells MUST NOT contain STAIRS_DOWN cell")
	assert(r_geom.floor_cells.size() == 35, "Room must have exactly 35 floor cells (36 minus 1 stair down)")
	print("  [OK] PresentationGeometryPartition successfully excluded STAIRS_DOWN from floor_cells (35 cells vs 36).")

	# 3. Generar superficie con DungeonFloorGenerator
	var floor_gen = floor_gen_script.new()
	var floor_res = floor_gen.generate_floor_for_partition(partition)
	assert(floor_res != null and floor_res.clusters.size() > 0, "Floor cluster must be generated")

	var cluster = floor_res.clusters[0]
	assert(not cluster.cells.has(stair_down_cell), "Cluster cells MUST NOT contain STAIRS_DOWN cell")
	print("  [OK] DungeonFloorGenerator created floor surface cluster with open vertical aperture.")

	print("\n==================================================================")
	print("[PASS] test_stair_down_aperture_exclusion passed 100%!")
	print("==================================================================\n")
	quit(0)
