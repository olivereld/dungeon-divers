extends SceneTree

func _init() -> void:
	print("--- Running test_dungeon_128 (128x128 Scalability & Performance) ---")
	var pipeline := DungeonPipeline.new()

	var config: DungeonConfig = preload("res://resources/configs/dungeon_128.tres")
	assert(config != null, "Config dungeon_128.tres must load properly")
	assert(config.grid_width == 128 and config.grid_height == 128, "Dimensions must be 128x128")

	for i in range(3):
		var start_time: int = Time.get_ticks_msec()
		var result: DungeonPipeline.DungeonResult = pipeline.generate(config, 5, true)
		var elapsed: int = Time.get_ticks_msec() - start_time

		assert(result != null, "128x128 generation must succeed")
		assert(result.grid.width == 128 and result.grid.height == 128, "Result grid must be 128x128")
		assert(result.validation.is_winnable == true, "128x128 dungeon must be 100% winnable")
		assert(result.rooms.size() >= 8, "128x128 dungeon must generate rich room topology")

		print("-> 128x128 Run #%d: %d ms | Rooms: %d | Fitness: %.2f | Seed: %d" % [
			i + 1, elapsed, result.rooms.size(), result.fitness_score, result.seed_used
		])

	print("[PASS] test_dungeon_128 succeeded.")
	quit(0)
