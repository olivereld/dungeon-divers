extends SceneTree

func _init() -> void:
	print("--- Running test_tsplit_wall & perimeter classification ---")
	var factory := PlaceholderFactory.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	assert(biome != null, "Biome must load")
	assert(biome.wall_tsplit_scene != null, "wall_tsplit_scene must be assigned in biome")

	var lib: MeshLibrary = factory.create_placeholder_library(biome, 2.0)
	assert(lib != null, "MeshLibrary must be created")

	var mapper := GridMapMapper.new()

	# Test 1: Simple room perimeter wall (Top wall: N is VOID/WALL, S is FLOOR, W and E are WALL)
	# This should be a STRAIGHT WALL (wall_index), NOT a T-split!
	var grid_room := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	grid_room.fill_rect(Rect2i(2, 2, 6, 6), CellGrid.CellType.FLOOR)
	var info_top: Dictionary = mapper._get_wall_tile_and_orientation(grid_room, Vector2i(4, 1), biome)
	print("Top perimeter wall at (4,1): item=%d (expected straight wall %d), orient=%d" % [
		info_top["index"], biome.wall_index, info_top["orientation"]
	])
	assert(info_top["index"] == biome.wall_index, "Perimeter wall MUST be straight wall_index, NOT T-split")
	assert(info_top["orientation"] == 0, "Top perimeter wall facing South must have orientation 0")

	# Test 2: True T-split wall: A wall pillar connecting 3 walkable branches
	# Mask 11: N, W, E walkable, South is WALL
	var grid_t_south := CellGrid.new(5, 5, CellGrid.CellType.FLOOR)
	grid_t_south.set_cell(Vector2i(2, 2), CellGrid.CellType.WALL)
	grid_t_south.set_cell(Vector2i(2, 3), CellGrid.CellType.WALL) # Solid wall south
	var info_ts: Dictionary = mapper._get_wall_tile_and_orientation(grid_t_south, Vector2i(2, 2), biome)
	print("T-Split branching South (mask 11): item=%d (expected %d), orient=%d (expected 0)" % [
		info_ts["index"], biome.wall_tsplit_index, info_ts["orientation"]
	])
	assert(info_ts["index"] == biome.wall_tsplit_index, "Must be classified as T-Split")
	assert(info_ts["orientation"] == 0, "Branch South must have rot_0 (0)")

	# Mask 7: S, W, E walkable, North is WALL
	var grid_t_north := CellGrid.new(5, 5, CellGrid.CellType.FLOOR)
	grid_t_north.set_cell(Vector2i(2, 2), CellGrid.CellType.WALL)
	grid_t_north.set_cell(Vector2i(2, 1), CellGrid.CellType.WALL) # Solid wall north
	var info_tn: Dictionary = mapper._get_wall_tile_and_orientation(grid_t_north, Vector2i(2, 2), biome)
	print("T-Split branching North (mask 7): item=%d (expected %d), orient=%d (expected 10)" % [
		info_tn["index"], biome.wall_tsplit_index, info_tn["orientation"]
	])
	assert(info_tn["index"] == biome.wall_tsplit_index, "Must be classified as T-Split")
	assert(info_tn["orientation"] == 10, "Branch North must have rot_180 (10)")

	# Mask 14: N, S, W walkable, East is WALL
	var grid_t_east := CellGrid.new(5, 5, CellGrid.CellType.FLOOR)
	grid_t_east.set_cell(Vector2i(2, 2), CellGrid.CellType.WALL)
	grid_t_east.set_cell(Vector2i(3, 2), CellGrid.CellType.WALL) # Solid wall east
	var info_te: Dictionary = mapper._get_wall_tile_and_orientation(grid_t_east, Vector2i(2, 2), biome)
	print("T-Split branching East (mask 14): item=%d (expected %d), orient=%d (expected 16)" % [
		info_te["index"], biome.wall_tsplit_index, info_te["orientation"]
	])
	assert(info_te["index"] == biome.wall_tsplit_index, "Must be classified as T-Split")
	assert(info_te["orientation"] == 16, "Branch East must have rot_90 (16)")

	# Mask 13: N, S, E walkable, West is WALL
	var grid_t_west := CellGrid.new(5, 5, CellGrid.CellType.FLOOR)
	grid_t_west.set_cell(Vector2i(2, 2), CellGrid.CellType.WALL)
	grid_t_west.set_cell(Vector2i(1, 2), CellGrid.CellType.WALL) # Solid wall west
	var info_tw: Dictionary = mapper._get_wall_tile_and_orientation(grid_t_west, Vector2i(2, 2), biome)
	print("T-Split branching West (mask 13): item=%d (expected %d), orient=%d (expected 22)" % [
		info_tw["index"], biome.wall_tsplit_index, info_tw["orientation"]
	])
	assert(info_tw["index"] == biome.wall_tsplit_index, "Must be classified as T-Split")
	assert(info_tw["orientation"] == 22, "Branch West must have rot_270 (22)")

	# Test 3: Floor under perimeter walls verification
	var floor_gmap := GridMap.new()
	var wall_gmap := GridMap.new()
	mapper.floor_grid_map = floor_gmap
	mapper.wall_grid_map = wall_gmap
	var cfg := DungeonConfig.new()
	cfg.biome_profile = biome
	mapper.apply(grid_room, cfg)

	# Verify floor under wall at (4,1)
	var floor_under_wall: int = floor_gmap.get_cell_item(Vector3i(4, 0, 1))
	print("Floor under wall at (4,1): item=%d (expected dungeon floor %d)" % [
		floor_under_wall, biome.dungeon_floor_index
	])
	assert(floor_under_wall == biome.dungeon_floor_index, "FloorGridMap must place floor tile under visible perimeter wall")

	# Verify NO floor in deep solid rock at (0,0)
	var deep_rock_floor: int = floor_gmap.get_cell_item(Vector3i(0, 0, 0))
	assert(deep_rock_floor == -1, "Deep rock void cell must NOT have floor tile")

	print("[PASS] test_tsplit_wall succeeded.")
	quit(0)
