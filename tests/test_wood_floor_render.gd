extends SceneTree

func _init() -> void:
	print("--- Running test_wood_floor_render ---")
	var factory := PlaceholderFactory.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	assert(biome != null, "wood_dungeon_biome.tres must load")
	assert(biome.floor_scene != null, "floor_scene must be assigned")

	var lib: MeshLibrary = factory.create_placeholder_library(biome, 2.0)
	assert(lib != null, "MeshLibrary must be created")

	var floor_mesh: Mesh = lib.get_item_mesh(biome.floor_index)
	assert(floor_mesh != null, "Floor mesh in MeshLibrary must not be null")
	print("Floor mesh successfully extracted and assigned to MeshLibrary: ", floor_mesh)

	# Test instantiating the scene and running a full generation with the 3D wood floor
	var controller_scene = preload("res://scenes/dungeon/dungeon_level.tscn")
	var controller: DungeonLevelController = controller_scene.instantiate()
	root.add_child(controller)

	controller.config = preload("res://resources/configs/dungeon_128.tres").duplicate()
	controller.regenerate(true)

	assert(controller.grid_map_mapper.grid_map.get_used_cells().size() > 0, "GridMap must have generated cells with wood floor")
	print("GridMap generated with %d 3D cells using wood floor model" % controller.grid_map_mapper.grid_map.get_used_cells().size())

	print("[PASS] test_wood_floor_render succeeded.")
	quit(0)
