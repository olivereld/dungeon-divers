extends SceneTree

func _init() -> void:
	print("--- Running test_column_integration ---")
	var factory := PlaceholderFactory.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	assert(biome != null, "Biome must load")
	assert(biome.column_scene != null, "column_scene must be assigned in biome")

	var lib: MeshLibrary = factory.create_placeholder_library(biome, 2.0)
	assert(lib != null, "MeshLibrary must be created")

	var column_mesh: Mesh = lib.get_item_mesh(biome.column_index)
	assert(column_mesh != null, "Column mesh must exist in MeshLibrary at slot 14")
	print("Loaded Column Mesh with %d surfaces" % column_mesh.get_surface_count())

	var mapper := GridMapMapper.new()

	# Test 1: Isolated pillar wall surrounded by 4 walkable sides (mask == 15)
	var grid_isolated := CellGrid.new(5, 5, CellGrid.CellType.FLOOR)
	grid_isolated.set_cell(Vector2i(2, 2), CellGrid.CellType.WALL)
	var info_isolated: Dictionary = mapper._get_wall_tile_and_orientation(grid_isolated, Vector2i(2, 2), biome)
	print("Isolated pillar at (2,2): item=%d (expected column %d), orient=%d" % [
		info_isolated["index"], biome.column_index, info_isolated["orientation"]
	])
	assert(info_isolated["index"] == biome.column_index, "Isolated wall with 4 walkable neighbors must use Column item")

	# Test 2: Large room architectural columns
	var grid_room := CellGrid.new(12, 12, CellGrid.CellType.WALL)
	var large_room := RoomData.new(0, Rect2i(2, 2, 8, 8), &"combat")
	grid_room.fill_rect(large_room.rect, CellGrid.CellType.FLOOR)

	var floor_gmap := GridMap.new()
	var wall_gmap := GridMap.new()
	mapper.floor_grid_map = floor_gmap
	mapper.wall_grid_map = wall_gmap
	var cfg := DungeonConfig.new()
	cfg.biome_profile = biome
	var rooms_list: Array[RoomData] = [large_room]
	mapper.apply(grid_room, cfg, rooms_list)

	# Verify column placed at (4,4) -> (rect.position.x + 2, rect.position.y + 2)
	var col_item_1: int = wall_gmap.get_cell_item(Vector3i(4, 0, 4))
	print("Column placed at (4,4): item=%d (expected column %d)" % [col_item_1, biome.column_index])
	assert(col_item_1 == biome.column_index, "Large room must place column at offset (2,2)")

	# Verify column placed at (7,4) -> (rect.end.x - 3, rect.position.y + 2)
	var col_item_2: int = wall_gmap.get_cell_item(Vector3i(7, 0, 4))
	print("Column placed at (7,4): item=%d (expected column %d)" % [col_item_2, biome.column_index])
	assert(col_item_2 == biome.column_index, "Large room must place column at offset (end.x - 3, 2)")

	print("[PASS] test_column_integration succeeded.")
	quit(0)
