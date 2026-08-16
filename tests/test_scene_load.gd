extends SceneTree

func _init() -> void:
	print("--- Running test_scene_load ---")
	var scene_res = load("res://scenes/dungeon/dungeon_level.tscn")
	assert(scene_res != null, "Scene dungeon_level.tscn must load successfully")

	var instance = scene_res.instantiate()
	assert(instance != null, "Scene dungeon_level.tscn must instantiate")

	root.add_child(instance)
	instance.regenerate()
	print("Instantiated scene, controller is ready.")

	# Verificar que FloorGridMap y WallGridMap contienen celdas
	var floor_gmap: GridMap = instance.get_node("FloorGridMap")
	var wall_gmap: GridMap = instance.get_node("WallGridMap")
	assert(floor_gmap != null, "FloorGridMap node must exist")
	assert(wall_gmap != null, "WallGridMap node must exist")

	var floor_cells := floor_gmap.get_used_cells()
	var wall_cells := wall_gmap.get_used_cells()
	assert(not floor_cells.is_empty(), "FloorGridMap must have generated floor cells")
	assert(not wall_cells.is_empty(), "WallGridMap must have generated wall cells")
	print("FloorGridMap cells: %d, WallGridMap cells: %d" % [floor_cells.size(), wall_cells.size()])

	# Verificar que el visualizador recibió los datos
	var vis = instance.get_node("UI/DungeonVisualizer")
	assert(vis != null, "Visualizer must exist")
	assert(vis._last_result != null, "Visualizer must have received DungeonResult")
	print("Visualizer successfully received result: %s" % str(vis._last_result.validation.is_winnable))

	# Probar regeneración con Preset 1 (Cave 32x32)
	instance.config = load("res://resources/configs/cave_dungeon.tres")
	instance.regenerate()
	var cave_floors := floor_gmap.get_used_cells()
	var cave_walls := wall_gmap.get_used_cells()
	assert(not cave_floors.is_empty(), "Cave preset should regenerate floor cells")
	assert(not cave_walls.is_empty(), "Cave preset should regenerate wall cells")
	print("Cave preset: %d floors, %d walls" % [cave_floors.size(), cave_walls.size()])

	# Probar regeneración con Preset 2 (Castle 64x64)
	instance.config = load("res://resources/configs/castle_dungeon.tres")
	instance.regenerate()
	var castle_floors := floor_gmap.get_used_cells()
	var castle_walls := wall_gmap.get_used_cells()
	assert(not castle_floors.is_empty(), "Castle preset should regenerate floor cells")
	assert(not castle_walls.is_empty(), "Castle preset should regenerate wall cells")
	print("Castle preset: %d floors, %d walls" % [castle_floors.size(), castle_walls.size()])

	instance.queue_free()
	print("[PASS] test_scene_load succeeded with all presets.")
	quit(0)
