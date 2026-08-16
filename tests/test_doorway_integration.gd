extends SceneTree

func _init() -> void:
	print("--- Running test_doorway_integration ---")
	var factory := PlaceholderFactory.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	assert(biome != null, "Biome must load")
	assert(biome.door_scene != null, "door_scene must be assigned to wall_doorway.gltf")

	var lib: MeshLibrary = factory.create_placeholder_library(biome, 2.0)
	assert(lib != null, "MeshLibrary must be created")

	var door_mesh: Mesh = lib.get_item_mesh(biome.door_index)
	assert(door_mesh != null, "Door mesh must exist in MeshLibrary")
	print("Loaded Door Mesh with %d surfaces" % door_mesh.get_surface_count())
	assert(door_mesh.get_surface_count() >= 2, "Door mesh must combine frame and wooden door surfaces")

	# Test Door Orientations in GridMapMapper
	var mapper := GridMapMapper.new()
	var grid := CellGrid.new(7, 7, CellGrid.CellType.WALL)

	# Room 1 at top: y in [1..2], x in [1..5]
	# Room 2 at bottom: y in [4..5], x in [1..5]
	# Horizontal wall at y=3 with Door at (3,3)
	grid.fill_rect(Rect2i(1, 1, 5, 2), CellGrid.CellType.FLOOR)
	grid.fill_rect(Rect2i(1, 4, 5, 2), CellGrid.CellType.FLOOR)
	grid.set_cell(Vector2i(3, 3), CellGrid.CellType.DOOR)

	var floor_gmap := GridMap.new()
	var wall_gmap := GridMap.new()
	mapper.floor_grid_map = floor_gmap
	mapper.wall_grid_map = wall_gmap

	var cfg := DungeonConfig.new()
	cfg.biome_profile = biome
	mapper.apply(grid, cfg)

	# Door at (3,3) in horizontal wall: orientation must be 0 (spanning along X)
	var door_orient_h: int = wall_gmap.get_cell_item_orientation(Vector3i(3, 0, 3))
	var door_item_h: int = wall_gmap.get_cell_item(Vector3i(3, 0, 3))
	print("Horizontal wall door at (3,3): item=%d, orientation=%d (expected 0)" % [door_item_h, door_orient_h])
	assert(door_item_h == biome.door_index, "Item at (3,3) must be door")
	assert(door_orient_h == 0, "Horizontal wall door must have orientation 0")

	# Test Vertical wall door
	var grid_v := CellGrid.new(7, 7, CellGrid.CellType.WALL)
	# Room 1 on Left: x in [1..2], y in [1..5]
	# Room 2 on Right: x in [4..5], y in [1..5]
	# Vertical wall at x=3 with Door at (3,3)
	grid_v.fill_rect(Rect2i(1, 1, 2, 5), CellGrid.CellType.FLOOR)
	grid_v.fill_rect(Rect2i(4, 1, 2, 5), CellGrid.CellType.FLOOR)
	grid_v.set_cell(Vector2i(3, 3), CellGrid.CellType.DOOR)

	var floor_gmap_v := GridMap.new()
	var wall_gmap_v := GridMap.new()
	mapper.floor_grid_map = floor_gmap_v
	mapper.wall_grid_map = wall_gmap_v
	mapper.apply(grid_v, cfg)

	# Door at (3,3) in vertical wall: orientation must be 16 (rot_90, spanning along Z)
	var door_orient_v: int = wall_gmap_v.get_cell_item_orientation(Vector3i(3, 0, 3))
	var door_item_v: int = wall_gmap_v.get_cell_item(Vector3i(3, 0, 3))
	print("Vertical wall door at (3,3): item=%d, orientation=%d (expected 16)" % [door_item_v, door_orient_v])
	assert(door_item_v == biome.door_index, "Item at (3,3) must be door")
	assert(door_orient_v == 16, "Vertical wall door must have orientation 16")

	# Verify Floor exists under the door
	var floor_under_door: int = floor_gmap_v.get_cell_item(Vector3i(3, 0, 3))
	assert(floor_under_door != GridMap.INVALID_CELL_ITEM, "Floor must be generated under the doorway")

	print("[PASS] test_doorway_integration succeeded.")
	quit(0)
