extends SceneTree

func _init() -> void:
	print("--- Simulating wall and corner classification ---")
	var grid := CellGrid.new(12, 12, CellGrid.CellType.WALL)
	# Room 6x6 at (3,3)
	grid.fill_rect(Rect2i(3, 3, 6, 6), CellGrid.CellType.FLOOR)
	# Door at (5, 2) on the North wall
	grid.set_cell(Vector2i(5, 2), CellGrid.CellType.DOOR)
	# Corridor running North from (5,1) to (5,0)
	grid.set_cell(Vector2i(5, 1), CellGrid.CellType.CORRIDOR)
	grid.set_cell(Vector2i(5, 0), CellGrid.CellType.CORRIDOR)

	var mapper := GridMapMapper.new()
	var biome: BiomeProfile = preload("res://resources/biomes/wood_dungeon_biome.tres")

	print("\nGrid Layout around North Wall (y=2):")
	for y in range(1, 4):
		var row := ""
		for x in range(2, 9):
			var t := grid.get_cell(Vector2i(x, y))
			match t:
				CellGrid.CellType.WALL: row += "# "
				CellGrid.CellType.FLOOR: row += ". "
				CellGrid.CellType.DOOR: row += "D "
				CellGrid.CellType.CORRIDOR: row += "C "
		print("y=%d: %s" % [y, row])

	print("\nWall classifications on North wall (y=2):")
	for x in range(2, 9):
		var pos := Vector2i(x, 2)
		if grid.get_cell(pos) == CellGrid.CellType.WALL:
			var info = mapper._get_wall_tile_and_orientation(grid, pos, biome)
			var type_str := "CORNER" if info["index"] == biome.wall_corner_index else "WALL"
			print("x=%d: %s (orient=%d)" % [x, type_str, info["orientation"]])

	quit(0)
