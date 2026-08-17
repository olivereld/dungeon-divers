extends SceneTree

func _init() -> void:
	print("--- Running test_wall_and_corner_render ---")
	var factory := PlaceholderFactory.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	assert(biome != null, "wood_dungeon_biome.tres must load")
	assert(biome.floor_scene != null, "floor_scene must be assigned")
	assert(biome.wall_scene != null, "wall_scene must be assigned")
	assert(biome.dungeon_floor_scene != null, "dungeon_floor_scene must be assigned")
	assert(biome.wall_corner_small_scene != null, "wall_corner_small_scene must be assigned")
	assert(biome.wall_endcap_scene != null, "wall_endcap_scene must be assigned")
	assert(biome.wall_tsplit_scene != null, "wall_tsplit_scene must be assigned")
	assert(biome.column_scene != null, "column_scene must be assigned")
	assert(biome.door_scene != null, "door_scene must be assigned")

	var lib: MeshLibrary = factory.create_placeholder_library(biome, 2.0)
	assert(lib != null, "MeshLibrary must be created")

	var floor_mesh: Mesh = lib.get_item_mesh(biome.floor_index)
	var dungeon_floor_mesh: Mesh = lib.get_item_mesh(biome.dungeon_floor_index)
	var wall_mesh: Mesh = lib.get_item_mesh(biome.wall_index)
	var corner_small_mesh: Mesh = lib.get_item_mesh(biome.wall_corner_small_index)
	var endcap_mesh: Mesh = lib.get_item_mesh(biome.wall_endcap_index)
	var tsplit_mesh: Mesh = lib.get_item_mesh(biome.wall_tsplit_index)
	var column_mesh: Mesh = lib.get_item_mesh(biome.column_index)
	var door_mesh: Mesh = lib.get_item_mesh(biome.door_index)

	assert(floor_mesh != null, "Floor mesh must exist in MeshLibrary")
	assert(dungeon_floor_mesh != null, "Dungeon Floor mesh must exist in MeshLibrary")
	assert(wall_mesh != null, "Wall mesh must exist in MeshLibrary")
	assert(corner_small_mesh != null, "Corner small mesh must exist in MeshLibrary")
	assert(endcap_mesh != null, "Endcap mesh must exist in MeshLibrary")
	assert(tsplit_mesh != null, "TSplit mesh must exist in MeshLibrary")
	assert(column_mesh != null, "Column mesh must exist in MeshLibrary")
	assert(door_mesh != null, "Door mesh must exist in MeshLibrary")

	print("Successfully loaded 3D models into MeshLibrary:")
	print("  - Floor Mesh (Surfaces: %d)" % floor_mesh.get_surface_count())
	print("  - Dungeon Floor Mesh (Surfaces: %d)" % dungeon_floor_mesh.get_surface_count())
	print("  - Wall Mesh (Surfaces: %d)" % wall_mesh.get_surface_count())
	print("  - Wall Corner Small Mesh (Surfaces: %d)" % corner_small_mesh.get_surface_count())
	print("  - Wall Endcap Mesh (Surfaces: %d)" % endcap_mesh.get_surface_count())
	print("  - Wall TSplit Mesh (Surfaces: %d)" % tsplit_mesh.get_surface_count())
	print("  - Column Mesh (Surfaces: %d)" % column_mesh.get_surface_count())
	print("  - Wall Doorway Mesh (Surfaces: %d)" % door_mesh.get_surface_count())

	# Instanciar el nivel completo en 3D
	var controller_scene = preload("res://scenes/dungeon/dungeon_level.tscn")
	var controller: DungeonLevelController = controller_scene.instantiate()
	root.add_child(controller)

	controller.config = preload("res://resources/configs/hybrid_dungeon.tres").duplicate()
	controller.config.biome_profile = biome
	controller.regenerate(true)

	var floor_cells_cnt: int = controller.grid_map_mapper.floor_grid_map.get_used_cells().size()
	var wall_cells_cnt: int = controller.grid_map_mapper.wall_grid_map.get_used_cells().size()
	assert(floor_cells_cnt > 0, "FloorGridMap must have generated cells with 3D models")
	assert(wall_cells_cnt > 0, "WallGridMap must have generated cells with 3D models")
	print("3D Level generated with %d floor cells and %d wall cells" % [floor_cells_cnt, wall_cells_cnt])

	print("[PASS] test_wall_and_corner_render succeeded.")
	quit(0)
