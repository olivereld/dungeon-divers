extends SceneTree

func _init() -> void:
	print("--- Debugging 128x128 generation ---")
	var pipeline := DungeonPipeline.new()
	var config: DungeonConfig = preload("res://resources/configs/dungeon_128.tres")

	pipeline.phase_completed.connect(func(phase, time):
		print("Phase %s took %.2f ms" % [phase, time])
	)
	pipeline.generation_failed.connect(func(err):
		print("Generation failed with error: ", err)
	)

	for i in range(5):
		print("\n=== RUN %d ===" % (i + 1))
		var res = pipeline.generate(config, 5, true)
		if res != null:
			print("SUCCESS: seed=%d, rooms=%d, fitness=%.2f, time=%.2f ms" % [res.seed_used, res.rooms.size(), res.fitness_score, res.generation_time_ms])
		else:
			print("FAILED!")

	quit(0)
