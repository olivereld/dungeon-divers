extends SceneTree

func _init() -> void:
	print("--- Running test_corner_suppression ---")
	var mapper := GridMapMapper.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	# Scenario 1: L-turn corridor
	# Layout:
	# W W W W W
	# W F F F W  (horizontal segment y=1, x=1..3)
	# W W C F W  (corner wall at 2,2; corridor goes down at x=3, y=1..3)
	# W W W F W  (vertical segment y=3, x=3)
	# W W W W W
	var grid_l := CellGrid.new(5, 5, CellGrid.CellType.WALL)
	grid_l.set_cell(Vector2i(1, 1), CellGrid.CellType.FLOOR)
	grid_l.set_cell(Vector2i(2, 1), CellGrid.CellType.FLOOR)
	grid_l.set_cell(Vector2i(3, 1), CellGrid.CellType.FLOOR)
	grid_l.set_cell(Vector2i(3, 2), CellGrid.CellType.FLOOR)
	grid_l.set_cell(Vector2i(3, 3), CellGrid.CellType.FLOOR)

	var corner_target_idx: int = biome.wall_corner_small_index if biome.wall_corner_small_scene != null else biome.wall_corner_index

	# In grid_l at (2,2):
	# North (2,1) is FLOOR (n=true)
	# East (3,2) is FLOOR (e=true)
	# South (2,3) is WALL (s=false)
	# West (1,2) is WALL (w=false)
	# This is an inner corner with n=true and e=true -> must be corner with rot_0 (ortho 0)
	var info_l: Dictionary = mapper._get_wall_tile_and_orientation(grid_l, Vector2i(2, 2), biome)
	print("L-turn Inner Corner at (2,2): index=%d (expected corner %d), orientation=%d (expected rot_0 = 0)" % [
		info_l["index"], corner_target_idx, info_l["orientation"]
	])
	assert(info_l["index"] == corner_target_idx, "Must be classified as corner")
	assert(info_l["orientation"] == 0, "n and e walkable must have rot_0 (arms West and South)")

	# Scenario 2: Wall adjacent to Door
	# Layout: horizontal wall with door at (2,1)
	# W W D W W
	# F F F F F
	var grid_door := CellGrid.new(5, 3, CellGrid.CellType.WALL)
	grid_door.fill_rect(Rect2i(0, 2, 5, 1), CellGrid.CellType.FLOOR)
	grid_door.set_cell(Vector2i(2, 1), CellGrid.CellType.DOOR)

	# Cell at (1,1): South is FLOOR (s=true), East is DOOR (e=true), North is WALL, West is WALL
	var info_door: Dictionary = mapper._get_wall_tile_and_orientation(grid_door, Vector2i(1, 1), biome)
	print("Wall next to door at (1,1): index=%d (expected straight wall %d), orientation=%d" % [
		info_door["index"], biome.wall_index, info_door["orientation"]
	])
	assert(info_door["index"] == biome.wall_index, "Wall next to door in straight wall must remain straight wall")
	assert(info_door["orientation"] == 0, "Wall facing South must have orientation 0")

	# Scenario 3: Real GridMap application on complex layout
	var grid_map := GridMap.new()
	mapper.grid_map = grid_map
	var cfg := DungeonConfig.new()
	cfg.biome_profile = biome
	mapper.apply(grid_l, cfg)

	# Check that corner at (2,2) exists in grid_map
	var item_at_corner: int = grid_map.get_cell_item(Vector3i(2, 0, 2))
	var orient_at_corner: int = grid_map.get_cell_item_orientation(Vector3i(2, 0, 2))
	assert(item_at_corner == corner_target_idx, "Corner at (2,2) must be rendered")
	assert(orient_at_corner == 0, "Corner at (2,2) must have orientation 0")

	# Check that neighbor walls at (1,2) and (2,3) are rendered cleanly (no gaps)
	var item_at_arm_w: int = grid_map.get_cell_item(Vector3i(1, 0, 2))
	assert(item_at_arm_w == biome.wall_index, "Neighbor at West arm (1,2) must be rendered as straight wall")

	var item_at_arm_s: int = grid_map.get_cell_item(Vector3i(2, 0, 3))
	assert(item_at_arm_s == biome.wall_index, "Neighbor at South arm (2,3) must be rendered as straight wall")

	print("[PASS] test_corner_suppression succeeded.")
	quit(0)
