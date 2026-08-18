extends SceneTree

func _init() -> void:
	print("--- Inspecting seed 812297351 ---")
	var pipeline := DungeonPipeline.new()
	var config := preload("res://resources/configs/hybrid_dungeon.tres") as DungeonConfig
	if config == null:
		config = DungeonConfig.new()
	config.seed = 812297351
	config.use_fixed_seed = true

	var res: DungeonResult = pipeline.generate(config, 5, false)
	assert(res != null, "Generation must return result")

	print("Rooms generated: %d" % res.rooms.size())
	for r in res.rooms:
		print("  Room ID %d: type=%s, rect=%s" % [r.id, r.room_type, str(r.rect)])

	print("\nCorridor Paths: %d" % res.corridor_paths.size())
	for p in res.corridor_paths:
		print("  Path conn_id=%d: length=%d, cells=%s" % [p.connection_id, p.centerline_cells.size(), str(p.centerline_cells)])

	print("\nDoor Pairs: %d" % res.door_pairs.size())
	for dp in res.door_pairs:
		print("  DoorPair conn_id=%d: door_a[pos=%s, type=%d, reason=%s], door_b[pos=%s, type=%d, reason=%s]" % [
			dp.connection_id, str(dp.door_a.position), dp.door_a.door_type, dp.door_a.reason,
			str(dp.door_b.position), dp.door_b.door_type, dp.door_b.reason
		])

	# Guardar representación ASCII del grid
	var grid_str := ""
	for y in range(res.grid.height):
		var line := ""
		for x in range(res.grid.width):
			var cell = res.grid.get_cell(Vector2i(x, y))
			match cell:
				CellGrid.CellType.WALL: line += "#"
				CellGrid.CellType.FLOOR: line += "."
				CellGrid.CellType.CORRIDOR: line += "="
				CellGrid.CellType.DOOR: line += "D"
				_: line += " "
		if "." in line or "=" in line:
			grid_str += "%2d: %s\n" % [y, line]
	print("\nGrid Floorplan:\n" + grid_str)

	quit(0)
