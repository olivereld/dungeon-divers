extends SceneTree

func _init() -> void:
	print("--- Inspecting seed 649654445 (48x48) ---")
	var pipeline := DungeonPipeline.new()
	var config := DungeonConfig.new()
	config.seed = 649654445
	config.use_fixed_seed = true
	config.grid_width = 48
	config.grid_height = 48

	var res: DungeonResult = pipeline.generate(config, 5, false)
	assert(res != null, "Generation must succeed")

	print("Rooms:")
	for r in res.rooms:
		print("  Room ID %d: %s, rect=%s" % [r.id, r.room_type, str(r.rect)])

	print("Doors:")
	for dp in res.door_pairs:
		print("  DoorPair conn=%d:" % dp.connection_id)
		if dp.door_a != null:
			print("    door_a: pos=%s, side=%d, corridor_cell=%s, type=%d" % [str(dp.door_a.position), dp.door_a.side, str(dp.door_a.corridor_cell), dp.door_a.door_type])
		if dp.door_b != null:
			print("    door_b: pos=%s, side=%d, corridor_cell=%s, type=%d" % [str(dp.door_b.position), dp.door_b.side, str(dp.door_b.corridor_cell), dp.door_b.door_type])

	quit(0)
