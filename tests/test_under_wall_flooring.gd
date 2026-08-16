extends SceneTree

func _init() -> void:
	print("--- Running test_under_wall_flooring ---")
	var mapper := GridMapMapper.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	# Test 1: 6x6 Room in 10x10 Grid
	var grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	grid.fill_rect(Rect2i(2, 2, 6, 6), CellGrid.CellType.FLOOR)

	var floor_gmap := GridMap.new()
	var wall_gmap := GridMap.new()
	mapper.floor_grid_map = floor_gmap
	mapper.wall_grid_map = wall_gmap

	var cfg := DungeonConfig.new()
	cfg.biome_profile = biome
	mapper.apply(grid, cfg)

	# Verify FloorGridMap:
	# 36 room floors (wood), no redundant under-wall floors outside
	var floor_cells := floor_gmap.get_used_cells()
	var wood_floor_count: int = 0

	for cell in floor_cells:
		var item: int = floor_gmap.get_cell_item(cell)
		if item == biome.floor_index:
			wood_floor_count += 1

	print("FloorGridMap used cells: %d (Wood Room Floors: %d)" % [
		floor_cells.size(), wood_floor_count
	])
	assert(wood_floor_count == 36, "Must have exactly 36 wood floor tiles for 6x6 room")
	assert(floor_cells.size() == 36, "Total floor tiles in FloorGridMap must be 36 (Option A: only walkable area)")

	# Verify WallGridMap:
	# 4 corners + 24 straight walls = 28 wall tiles
	var wall_cells := wall_gmap.get_used_cells()
	var corner_count: int = 0
	var straight_count: int = 0

	for cell in wall_cells:
		var item: int = wall_gmap.get_cell_item(cell)
		if item == biome.wall_corner_small_index or item == biome.wall_corner_index:
			corner_count += 1
		elif item == biome.wall_index:
			straight_count += 1

	print("WallGridMap used cells: %d (Corners: %d, Straights: %d)" % [
		wall_cells.size(), corner_count, straight_count
	])
	assert(corner_count == 4, "Must have 4 corners in WallGridMap")
	assert(straight_count == 24, "Must have 24 straight walls in WallGridMap")

	# Test 2: Solid rock with isolated diagonal floor (must NOT place floating corner)
	var grid_rock := CellGrid.new(5, 5, CellGrid.CellType.WALL)
	grid_rock.set_cell(Vector2i(0, 0), CellGrid.CellType.FLOOR) # Floor at 0,0
	# Cell at (1,1): NW is floor, but N(1,0) and W(0,1) are walls that do NOT face room floor
	var info_blind: Dictionary = mapper._get_wall_tile_and_orientation(grid_rock, Vector2i(2, 2), biome)
	print("Blind rock wall info at (2,2): index=%d (expected -1 = no wall placed)" % info_blind["index"])
	assert(info_blind["index"] == -1, "Blind solid rock with diagonal floor must not place floating corner")

	print("[PASS] test_under_wall_flooring succeeded.")
	quit(0)
