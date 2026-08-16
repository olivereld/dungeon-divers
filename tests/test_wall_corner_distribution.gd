extends SceneTree

func _init() -> void:
	print("--- Running test_wall_corner_distribution ---")
	var mapper := GridMapMapper.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	# Crear un cuarto de 6x6 en un grid de 10x10
	var grid := CellGrid.new(10, 10, CellGrid.CellType.WALL)
	grid.fill_rect(Rect2i(2, 2, 6, 6), CellGrid.CellType.FLOOR)

	var straight_count: int = 0
	var corner_count: int = 0

	var corner_target_idx: int = biome.wall_corner_small_index if biome.wall_corner_small_scene != null else biome.wall_corner_index

	for y in range(10):
		for x in range(10):
			var pos := Vector2i(x, y)
			if grid.get_cell(pos) == CellGrid.CellType.WALL and grid.count_walkable_neighbors(pos, true) > 0:
				var info: Dictionary = mapper._get_wall_tile_and_orientation(grid, pos, biome)
				if info["index"] == biome.wall_index:
					straight_count += 1
				elif info["index"] == corner_target_idx:
					corner_count += 1

	print("6x6 Room Wall Tiles Classification: Straight Walls = %d, Corner Tiles = %d" % [straight_count, corner_count])
	assert(corner_count == 4, "Must classify exactly 4 corner tiles for a rectangular room (got %d)" % corner_count)
	assert(straight_count == 24, "Must classify exactly 24 straight wall tiles for a 6x6 room (got %d)" % straight_count)

	# Test real GridMap output
	var grid_map := GridMap.new()
	mapper.grid_map = grid_map
	var cfg := DungeonConfig.new()
	cfg.biome_profile = biome
	mapper.apply(grid, cfg)

	var rendered_corners: int = 0
	var rendered_straights: int = 0
	var rendered_floors: int = 0

	for cell in grid_map.get_used_cells():
		var item: int = grid_map.get_cell_item(cell)
		if item == corner_target_idx:
			rendered_corners += 1
		elif item == biome.wall_index:
			rendered_straights += 1
		elif item == biome.floor_index:
			rendered_floors += 1

	print("6x6 Room GridMap Rendered Tiles: Corners = %d, Straights = %d, Floors = %d (Total = %d)" % [
		rendered_corners, rendered_straights, rendered_floors, grid_map.get_used_cells().size()
	])

	assert(rendered_corners == 4, "Must render exactly 4 corner tiles (got %d)" % rendered_corners)
	assert(rendered_straights == 24, "Must render exactly 24 straight walls with small corner tiles (got %d)" % rendered_straights)
	assert(rendered_floors == 36, "Must render exactly 36 floor tiles for 6x6 room (got %d)" % rendered_floors)

	print("[PASS] test_wall_corner_distribution succeeded.")
	quit(0)
